-- ============================================================
-- Cobranza completa: mora desde cronograma + gestiones persistidas
-- Ejecutar DESPUÉS de 13_ecosistema_integrado.sql (y 29 si aplica)
-- ============================================================

-- ── Tabla de gestiones de cobranza ───────────────────────────
CREATE TABLE IF NOT EXISTS public.acciones_cobranza (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asesor_user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  cliente_user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  credito_id         UUID REFERENCES public.creditos_preaprobados(id) ON DELETE SET NULL,
  cod_cuenta_credito TEXT,
  tipo_gestion       TEXT NOT NULL
                       CHECK (tipo_gestion IN ('visita', 'llamada', 'mensaje')),
  resultado          TEXT NOT NULL
                       CHECK (resultado IN (
                         'compromiso_pago', 'pago_parcial', 'sin_contacto', 'se_niega'
                       )),
  monto_pagado       NUMERIC(12,2),
  fecha_compromiso   DATE,
  monto_compromiso   NUMERIC(12,2),
  observaciones      TEXT NOT NULL DEFAULT '',
  lat                NUMERIC(10,7),
  lng                NUMERIC(10,7),
  timestamp_gestion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_acciones_cobranza_cliente
  ON public.acciones_cobranza(cliente_user_id, timestamp_gestion DESC);

CREATE INDEX IF NOT EXISTS idx_acciones_cobranza_asesor
  ON public.acciones_cobranza(asesor_user_id, timestamp_gestion DESC);

ALTER TABLE public.acciones_cobranza ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Asesor ve gestiones de su cartera" ON public.acciones_cobranza;
CREATE POLICY "Asesor ve gestiones de su cartera"
  ON public.acciones_cobranza FOR SELECT
  USING (public.asesor_atiende_cliente(cliente_user_id));

DROP POLICY IF EXISTS "Asesor registra gestiones de su cartera" ON public.acciones_cobranza;
CREATE POLICY "Asesor registra gestiones de su cartera"
  ON public.acciones_cobranza FOR INSERT
  WITH CHECK (
    asesor_user_id = auth.uid()
    AND public.asesor_atiende_cliente(cliente_user_id)
  );

-- ── Sincronizar mora desde cronograma de cuotas ──────────────
CREATE OR REPLACE FUNCTION public.sync_mora_cliente(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tiene_cronograma BOOLEAN;
  v_primera_vencida  DATE;
  v_monto_vencido    NUMERIC(12,2);
  v_dias             INT;
  v_estado           TEXT;
BEGIN
  UPDATE public.cronograma_cuotas
  SET estado_cuota = 'vencida'
  WHERE user_id = p_user_id
    AND estado_cuota = 'pendiente'
    AND fecha_vencimiento < CURRENT_DATE;

  SELECT EXISTS (
    SELECT 1 FROM public.cronograma_cuotas WHERE user_id = p_user_id
  ) INTO v_tiene_cronograma;

  IF NOT v_tiene_cronograma THEN
    RETURN;
  END IF;

  SELECT
    MIN(cc.fecha_vencimiento),
    COALESCE(SUM(cc.monto_cuota), 0)
  INTO v_primera_vencida, v_monto_vencido
  FROM public.cronograma_cuotas cc
  WHERE cc.user_id = p_user_id
    AND cc.estado_cuota IN ('pendiente', 'vencida')
    AND cc.fecha_vencimiento < CURRENT_DATE;

  IF v_primera_vencida IS NULL THEN
    v_dias := 0;
    v_estado := 'al_dia';
  ELSE
    v_dias := GREATEST(0, CURRENT_DATE - v_primera_vencida);
    v_estado := CASE
      WHEN v_dias >= 90 THEN 'atraso_90'
      WHEN v_dias >= 30 THEN 'atraso_30'
      WHEN v_dias > 0  THEN 'atraso_leve'
      ELSE 'al_dia'
    END;
  END IF;

  UPDATE public.creditos_preaprobados
  SET dias_mora = v_dias,
      estado_pago = v_estado
  WHERE user_id = p_user_id
    AND estado = 'desembolsado';
END;
$$;

REVOKE ALL ON FUNCTION public.sync_mora_cliente(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_mora_cliente(UUID) TO authenticated;

-- ── RPC: listar mora del día (sincroniza y devuelve cartera) ───
CREATE OR REPLACE FUNCTION public.asesor_listar_mora_dia()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_items JSONB;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  PERFORM public.sync_mora_cliente(pc.user_id)
  FROM public.perfiles_clientes pc
  WHERE public.asesor_atiende_cliente(pc.user_id);

  SELECT COALESCE(jsonb_agg(row ORDER BY (row->>'dias_mora')::INT DESC), '[]'::JSONB)
  INTO v_items
  FROM (
    SELECT jsonb_build_object(
      'id', cp.id,
      'cliente_id', cp.user_id,
      'cliente_nombre', trim(COALESCE(pc.nombres, '') || ' ' || COALESCE(pc.apellidos, '')),
      'documento', pc.dni,
      'telefono', pc.telefono,
      'cod_cuenta_credito', COALESCE(
        (
          SELECT p.numero_enmascarado
          FROM public.prestamos p
          WHERE p.user_id = cp.user_id
          ORDER BY p.created_at DESC
          LIMIT 1
        ),
        'CRED-' || UPPER(SUBSTRING(REPLACE(cp.id::TEXT, '-', ''), 1, 8))
      ),
      'dias_mora', COALESCE(cp.dias_mora, 0),
      'monto_vencido', COALESCE(
        (
          SELECT SUM(cc.monto_cuota)
          FROM public.cronograma_cuotas cc
          WHERE cc.user_id = cp.user_id
            AND cc.estado_cuota IN ('pendiente', 'vencida')
            AND cc.fecha_vencimiento < CURRENT_DATE
        ),
        cp.cuota_mensual,
        cp.monto_aprobado,
        0
      ),
      'estado_pago', cp.estado_pago,
      'credito_id', cp.id
    ) AS row
    FROM public.creditos_preaprobados cp
    JOIN public.perfiles_clientes pc ON pc.user_id = cp.user_id
    WHERE public.asesor_atiende_cliente(cp.user_id)
      AND COALESCE(cp.dias_mora, 0) > 0
  ) sub;

  RETURN jsonb_build_object('ok', true, 'items', v_items);
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_listar_mora_dia() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_listar_mora_dia() TO authenticated;

-- ── RPC: registrar gestión de cobranza (RF-77) ──────────────
CREATE OR REPLACE FUNCTION public.asesor_registrar_accion_cobranza(
  p_cliente_user_id   UUID,
  p_tipo_gestion      TEXT,
  p_resultado         TEXT,
  p_credito_id        UUID DEFAULT NULL,
  p_cod_cuenta_credito TEXT DEFAULT NULL,
  p_monto_pagado      NUMERIC DEFAULT NULL,
  p_fecha_compromiso  DATE DEFAULT NULL,
  p_monto_compromiso  NUMERIC DEFAULT NULL,
  p_observaciones     TEXT DEFAULT '',
  p_lat               NUMERIC DEFAULT NULL,
  p_lng               NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_credito_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  IF NOT public.asesor_atiende_cliente(p_cliente_user_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cliente_fuera_cartera');
  END IF;

  IF p_tipo_gestion NOT IN ('visita', 'llamada', 'mensaje') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'tipo_gestion_invalido');
  END IF;

  IF p_resultado NOT IN ('compromiso_pago', 'pago_parcial', 'sin_contacto', 'se_niega') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'resultado_invalido');
  END IF;

  v_credito_id := p_credito_id;
  IF v_credito_id IS NULL THEN
    SELECT cp.id INTO v_credito_id
    FROM public.creditos_preaprobados cp
    WHERE cp.user_id = p_cliente_user_id
      AND cp.estado = 'desembolsado'
    ORDER BY cp.created_at DESC
    LIMIT 1;
  END IF;

  INSERT INTO public.acciones_cobranza (
    asesor_user_id, cliente_user_id, credito_id, cod_cuenta_credito,
    tipo_gestion, resultado, monto_pagado, fecha_compromiso,
    monto_compromiso, observaciones, lat, lng
  ) VALUES (
    auth.uid(), p_cliente_user_id, v_credito_id, p_cod_cuenta_credito,
    p_tipo_gestion, p_resultado, p_monto_pagado, p_fecha_compromiso,
    p_monto_compromiso, COALESCE(p_observaciones, ''), p_lat, p_lng
  )
  RETURNING id INTO v_id;

  IF p_resultado = 'compromiso_pago' AND p_fecha_compromiso IS NOT NULL THEN
    INSERT INTO public.notificaciones (
      destinatario_tipo, user_id, titulo, cuerpo, tipo, data_json
    ) VALUES (
      'asesor',
      auth.uid(),
      'Compromiso de pago',
      'Seguimiento de compromiso para el '
        || to_char(p_fecha_compromiso, 'DD/MM/YYYY')
        || COALESCE(' · S/ ' || p_monto_compromiso::TEXT, ''),
      'compromiso_cobranza',
      jsonb_build_object(
        'accion_id', v_id,
        'cliente_user_id', p_cliente_user_id,
        'fecha_compromiso', p_fecha_compromiso,
        'monto_compromiso', p_monto_compromiso
      )
    );
  END IF;

  IF p_resultado = 'pago_parcial' AND COALESCE(p_monto_pagado, 0) > 0 THEN
    INSERT INTO public.notificaciones (
      destinatario_tipo, user_id, titulo, cuerpo, tipo, data_json
    ) VALUES (
      'asesor',
      auth.uid(),
      'Pago parcial registrado',
      'Gestión de cobranza con pago parcial de S/ ' || p_monto_pagado::TEXT,
      'pago_parcial_cobranza',
      jsonb_build_object('accion_id', v_id, 'cliente_user_id', p_cliente_user_id)
    );
  END IF;

  RETURN jsonb_build_object('ok', true, 'accion_id', v_id);
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_registrar_accion_cobranza(
  UUID, TEXT, TEXT, UUID, TEXT, NUMERIC, DATE, NUMERIC, TEXT, NUMERIC, NUMERIC
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_registrar_accion_cobranza(
  UUID, TEXT, TEXT, UUID, TEXT, NUMERIC, DATE, NUMERIC, TEXT, NUMERIC, NUMERIC
) TO authenticated;

-- ── RPC: historial de gestiones por cliente ──────────────────
CREATE OR REPLACE FUNCTION public.asesor_historial_cobranza(p_cliente_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_items JSONB;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  IF NOT public.asesor_atiende_cliente(p_cliente_user_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cliente_fuera_cartera');
  END IF;

  SELECT COALESCE(jsonb_agg(row ORDER BY (row->>'timestamp_gestion') DESC), '[]'::JSONB)
  INTO v_items
  FROM (
    SELECT jsonb_build_object(
      'id', ac.id,
      'tipo_gestion', ac.tipo_gestion,
      'resultado', ac.resultado,
      'monto_pagado', ac.monto_pagado,
      'fecha_compromiso', ac.fecha_compromiso,
      'monto_compromiso', ac.monto_compromiso,
      'observaciones', ac.observaciones,
      'timestamp_gestion', ac.timestamp_gestion
    ) AS row
    FROM public.acciones_cobranza ac
    WHERE ac.cliente_user_id = p_cliente_user_id
    LIMIT 20
  ) sub;

  RETURN jsonb_build_object('ok', true, 'items', v_items);
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_historial_cobranza(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_historial_cobranza(UUID) TO authenticated;

-- ── Actualizar pago de cuota: recalcular mora tras el pago ─────
CREATE OR REPLACE FUNCTION public.cliente_pagar_cuota(
  p_prestamo_id UUID,
  p_cuenta_id UUID,
  p_nro_cuota INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_prestamo RECORD;
  v_cuenta RECORD;
  v_cuota RECORD;
  v_nro INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  SELECT * INTO v_prestamo
  FROM public.prestamos
  WHERE id = p_prestamo_id AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'prestamo_no_encontrado');
  END IF;

  SELECT * INTO v_cuenta
  FROM public.cuentas
  WHERE id = p_cuenta_id AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cuenta_invalida');
  END IF;

  v_nro := COALESCE(p_nro_cuota, v_prestamo.cuota_numero);

  SELECT * INTO v_cuota
  FROM public.cronograma_cuotas
  WHERE prestamo_id = p_prestamo_id AND nro_cuota = v_nro
    AND estado_cuota IN ('pendiente', 'vencida')
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cuota_no_pendiente');
  END IF;

  IF v_cuenta.saldo < v_cuota.monto_cuota THEN
    RETURN jsonb_build_object('ok', false, 'error', 'saldo_insuficiente');
  END IF;

  UPDATE public.cuentas SET saldo = saldo - v_cuota.monto_cuota WHERE id = p_cuenta_id;
  UPDATE public.cronograma_cuotas
  SET estado_cuota = 'pagada', fecha_pago = CURRENT_DATE
  WHERE id = v_cuota.id;
  UPDATE public.prestamos
  SET capital_pendiente = GREATEST(0, capital_pendiente - v_cuota.monto_capital),
      cuota_numero = LEAST(cuotas_total, cuota_numero + 1),
      fecha_limite = (CURRENT_DATE + INTERVAL '1 month')::DATE
  WHERE id = p_prestamo_id;

  INSERT INTO public.transacciones (user_id, cuenta_id, tipo, descripcion, monto)
  VALUES (v_user_id, p_cuenta_id, 'debito',
    'Pago cuota ' || v_nro::TEXT || ' crédito ' || v_prestamo.numero_enmascarado,
    v_cuota.monto_cuota);

  INSERT INTO public.pagos (user_id, servicio, numero_contrato, monto, estado)
  VALUES (v_user_id, 'telefono', v_prestamo.numero_enmascarado, v_cuota.monto_cuota, 'completado');

  INSERT INTO public.notificaciones (destinatario_tipo, user_id, titulo, cuerpo, tipo)
  VALUES ('cliente', v_user_id, 'Pago registrado',
    'Cuota ' || v_nro::TEXT || ' pagada por S/ ' || v_cuota.monto_cuota::TEXT,
    'pago_cuota');

  PERFORM public.sync_mora_cliente(v_user_id);

  RETURN jsonb_build_object(
    'ok', true,
    'cuota_pagada', v_nro,
    'monto', v_cuota.monto_cuota,
    'nuevo_saldo', v_cuenta.saldo - v_cuota.monto_cuota
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cliente_pagar_cuota(UUID, UUID, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_pagar_cuota(UUID, UUID, INT) TO authenticated;

-- RLS: asesor ve notificaciones propias
DROP POLICY IF EXISTS "Asesor ve sus notificaciones" ON public.notificaciones;
CREATE POLICY "Asesor ve sus notificaciones"
  ON public.notificaciones FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Asesor actualiza sus notificaciones" ON public.notificaciones;
CREATE POLICY "Asesor actualiza sus notificaciones"
  ON public.notificaciones FOR UPDATE
  USING (auth.uid() = user_id);
