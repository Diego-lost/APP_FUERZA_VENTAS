-- ============================================================
-- Ecosistema integrado Supabase — FVentas ↔ Core ↔ App Clientes
-- Ejecutar DESPUÉS de 11_fuerza_ventas_modulos.sql
-- Si falla "prestamos no existe", ejecutar antes 01b_tablas_app_clientes.sql
-- ============================================================

-- ── Perfil RBAC en asesores ──────────────────────────────────
ALTER TABLE public.asesores_negocio
  ADD COLUMN IF NOT EXISTS perfil TEXT DEFAULT 'operador'
    CHECK (perfil IN ('operador','super_operador','supervisor','administrador'));

UPDATE public.asesores_negocio
SET perfil = CASE
  WHEN nivel IN ('Senior I', 'Senior II') THEN 'supervisor'
  WHEN nivel = 'Junior II' THEN 'super_operador'
  ELSE 'operador'
END
WHERE perfil IS NULL OR perfil = 'operador';

-- ── Bloqueo login clientes (RF-04) ───────────────────────────
ALTER TABLE public.perfiles_clientes
  ADD COLUMN IF NOT EXISTS intentos_fallidos INT NOT NULL DEFAULT 0;

ALTER TABLE public.perfiles_clientes
  ADD COLUMN IF NOT EXISTS bloqueado_hasta TIMESTAMPTZ;

-- ── Puente sync (equivalente bd_core_mobile) ─────────────────
CREATE TABLE IF NOT EXISTS public.sync_outbox (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entidad      TEXT NOT NULL,
  entidad_id   UUID NOT NULL,
  operacion    TEXT NOT NULL CHECK (operacion IN ('create','update','delete')),
  payload      JSONB NOT NULL DEFAULT '{}',
  estado       TEXT NOT NULL DEFAULT 'pendiente'
                 CHECK (estado IN ('pendiente','procesando','aplicado','error')),
  intentos     INT NOT NULL DEFAULT 0,
  core_ref     TEXT,
  ultimo_error TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  procesado_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.sync_log (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  direccion  TEXT NOT NULL CHECK (direccion IN ('mobile_a_core','core_a_mobile')),
  entidad    TEXT NOT NULL,
  referencia TEXT,
  resultado  TEXT NOT NULL CHECK (resultado IN ('ok','error')),
  detalle    TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Cronograma de cuotas (espejo cr_cronograma_pagos) ─────────
CREATE TABLE IF NOT EXISTS public.cronograma_cuotas (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prestamo_id       UUID NOT NULL REFERENCES public.prestamos(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  nro_cuota         INT NOT NULL,
  fecha_vencimiento DATE NOT NULL,
  monto_cuota       NUMERIC(12,2) NOT NULL,
  monto_capital     NUMERIC(12,2) NOT NULL DEFAULT 0,
  monto_interes     NUMERIC(12,2) NOT NULL DEFAULT 0,
  saldo_restante    NUMERIC(12,2) NOT NULL DEFAULT 0,
  estado_cuota      TEXT NOT NULL DEFAULT 'pendiente'
                      CHECK (estado_cuota IN ('pendiente','pagada','vencida')),
  fecha_pago        DATE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (prestamo_id, nro_cuota)
);

CREATE INDEX IF NOT EXISTS idx_cronograma_user
  ON public.cronograma_cuotas(user_id);

-- ── Notificaciones (app clientes + asesores) ─────────────────
CREATE TABLE IF NOT EXISTS public.notificaciones (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  destinatario_tipo TEXT NOT NULL CHECK (destinatario_tipo IN ('asesor','cliente')),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  titulo            TEXT NOT NULL,
  cuerpo            TEXT,
  tipo              TEXT,
  leida             BOOLEAN NOT NULL DEFAULT FALSE,
  data_json         JSONB,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_user
  ON public.notificaciones(user_id, leida, created_at DESC);

-- ── Consultas buró con consentimiento (RF-57) ──────────────────
CREATE TABLE IF NOT EXISTS public.consultas_buro (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asesor_user_id              UUID NOT NULL REFERENCES auth.users(id),
  cliente_user_id             UUID NOT NULL REFERENCES auth.users(id),
  dni_consultado              TEXT NOT NULL,
  calificacion_sbs            TEXT,
  en_lista_negra              BOOLEAN NOT NULL DEFAULT FALSE,
  firma_consentimiento_base64 TEXT,
  consentimiento_aceptado     BOOLEAN NOT NULL DEFAULT FALSE,
  resultado_json              JSONB,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── RLS nuevas tablas ────────────────────────────────────────
ALTER TABLE public.cronograma_cuotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Cliente ve su cronograma" ON public.cronograma_cuotas;
CREATE POLICY "Cliente ve su cronograma"
  ON public.cronograma_cuotas FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Cliente ve sus notificaciones" ON public.notificaciones;
CREATE POLICY "Cliente ve sus notificaciones"
  ON public.notificaciones FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Cliente actualiza sus notificaciones" ON public.notificaciones;
CREATE POLICY "Cliente actualiza sus notificaciones"
  ON public.notificaciones FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Asesor ve notificaciones de su cartera" ON public.notificaciones;
CREATE POLICY "Asesor ve notificaciones de su cartera"
  ON public.notificaciones FOR SELECT
  USING (
    destinatario_tipo = 'asesor' AND user_id = auth.uid()
    OR public.asesor_atiende_cliente(user_id)
  );

-- ── Helper: perfil del asesor autenticado ────────────────────
CREATE OR REPLACE FUNCTION public.current_asesor_perfil()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(perfil, 'operador')
  FROM public.asesores_negocio
  WHERE user_id = auth.uid() AND activo = TRUE
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.current_asesor_perfil() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_asesor_perfil() TO authenticated;

CREATE OR REPLACE FUNCTION public.asesor_es_supervisor()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.current_asesor_perfil() IN ('supervisor', 'administrador');
$$;

REVOKE ALL ON FUNCTION public.asesor_es_supervisor() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_es_supervisor() TO authenticated;

-- ── Generar cronograma francés ───────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_generar_cronograma(
  p_prestamo_id UUID,
  p_user_id UUID,
  p_monto NUMERIC,
  p_plazo INT,
  p_tasa_anual NUMERIC,
  p_cuota_mensual NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_saldo NUMERIC := p_monto;
  v_tm NUMERIC;
  v_capital NUMERIC;
  v_interes NUMERIC;
  i INT;
BEGIN
  v_tm := POWER(1 + p_tasa_anual / 100, 1.0 / 12) - 1;

  FOR i IN 1..p_plazo LOOP
    v_interes := ROUND(v_saldo * v_tm, 2);
    v_capital := ROUND(p_cuota_mensual - v_interes, 2);
    IF i = p_plazo THEN
      v_capital := v_saldo;
      v_interes := p_cuota_mensual - v_capital;
    END IF;
    v_saldo := GREATEST(0, v_saldo - v_capital);

    INSERT INTO public.cronograma_cuotas (
      prestamo_id, user_id, nro_cuota, fecha_vencimiento,
      monto_cuota, monto_capital, monto_interes, saldo_restante, estado_cuota
    ) VALUES (
      p_prestamo_id, p_user_id, i,
      (CURRENT_DATE + (i || ' months')::INTERVAL)::DATE,
      p_cuota_mensual, v_capital, v_interes, v_saldo, 'pendiente'
    );
  END LOOP;
END;
$$;

-- ── Desembolsar solicitud → préstamo + cronograma + notificación ─
CREATE OR REPLACE FUNCTION public.fn_desembolsar_solicitud(p_solicitud_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sol RECORD;
  v_prestamo_id UUID;
  v_cod_credito TEXT;
  v_outbox_id UUID;
BEGIN
  SELECT * INTO v_sol
  FROM public.solicitudes_prestamo
  WHERE id = p_solicitud_id AND estado = 'en_comite'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'solicitud_no_en_comite');
  END IF;

  v_cod_credito := 'CRED-' || UPPER(SUBSTRING(REPLACE(p_solicitud_id::TEXT, '-', ''), 1, 8));

  -- Actualizar solicitud
  UPDATE public.solicitudes_prestamo
  SET estado = 'desembolsado', updated_at = now()
  WHERE id = p_solicitud_id;

  -- Crear préstamo activo
  INSERT INTO public.prestamos (
    user_id, tipo, numero_enmascarado,
    capital_total, capital_pendiente,
    cuota_numero, cuotas_total, fecha_limite,
    capital_cuota, intereses_cuota
  ) VALUES (
    v_sol.user_id,
    COALESCE(v_sol.tipo_producto, 'prospera'),
    v_cod_credito,
    v_sol.monto, v_sol.monto,
    1, v_sol.plazo_meses,
    (CURRENT_DATE + INTERVAL '1 month')::DATE,
    ROUND(v_sol.cuota_mensual * 0.65, 2),
    ROUND(v_sol.cuota_mensual * 0.35, 2)
  )
  RETURNING id INTO v_prestamo_id;

  PERFORM public.fn_generar_cronograma(
    v_prestamo_id, v_sol.user_id,
    v_sol.monto, v_sol.plazo_meses,
    v_sol.tasa_anual, v_sol.cuota_mensual
  );

  -- Actualizar crédito preaprobado existente o crear uno mínimo
  UPDATE public.creditos_preaprobados
  SET monto_aprobado = v_sol.monto,
      cuota_mensual = v_sol.cuota_mensual,
      plazo_meses = v_sol.plazo_meses,
      estado = 'desembolsado',
      estado_pago = 'al_dia',
      dias_mora = 0,
      fecha_desembolso = CURRENT_DATE
  WHERE user_id = v_sol.user_id
    AND tipo_producto = COALESCE(v_sol.tipo_producto, 'prospera');

  IF NOT FOUND THEN
    INSERT INTO public.creditos_preaprobados (
      user_id, segmento, tipo_producto, score_transaccional,
      score_campo, score_final, monto_aprobado,
      cuota_mensual, plazo_meses, estado, estado_pago, dias_mora,
      fecha_desembolso
    ) VALUES (
      v_sol.user_id, 'ESTANDAR',
      COALESCE(v_sol.tipo_producto, 'prospera'),
      400, 400, 400,
      v_sol.monto, v_sol.cuota_mensual, v_sol.plazo_meses,
      'desembolsado', 'al_dia', 0, CURRENT_DATE
    );
  END IF;

  -- Notificación al cliente
  INSERT INTO public.notificaciones (
    destinatario_tipo, user_id, titulo, cuerpo, tipo, data_json
  ) VALUES (
    'cliente', v_sol.user_id,
    'Crédito desembolsado',
    'Tu crédito de S/ ' || v_sol.monto::TEXT || ' fue desembolsado. '
      || 'Cuota mensual: S/ ' || v_sol.cuota_mensual::TEXT,
    'desembolsado',
    jsonb_build_object('solicitud_id', p_solicitud_id, 'cod_credito', v_cod_credito)
  );

  -- sync_outbox: mobile → core (simulado)
  INSERT INTO public.sync_outbox (entidad, entidad_id, operacion, payload, estado, core_ref, procesado_at)
  VALUES (
    'solicitudes_prestamo', p_solicitud_id, 'create',
    jsonb_build_object(
      'user_id', v_sol.user_id,
      'monto', v_sol.monto,
      'plazo_meses', v_sol.plazo_meses,
      'cod_credito', v_cod_credito
    ),
    'aplicado', v_cod_credito, now()
  )
  RETURNING id INTO v_outbox_id;

  -- sync_log: core → mobile (retroalimentación cr_*)
  INSERT INTO public.sync_log (direccion, entidad, referencia, resultado, detalle)
  VALUES (
    'core_a_mobile', 'prestamos', v_cod_credito, 'ok',
    'Crédito reflejado en prestamos + cronograma_cuotas para app clientes'
  );

  RETURN jsonb_build_object(
    'ok', true,
    'prestamo_id', v_prestamo_id,
    'cod_credito', v_cod_credito,
    'outbox_id', v_outbox_id
  );
END;
$$;

-- ── Actualizar transmisión: auto-desembolsar tras comité ───────
CREATE OR REPLACE FUNCTION public.asesor_transmitir_pendientes()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_solicitudes INT := 0;
  v_documentos  INT := 0;
  v_desembolsos INT := 0;
  r RECORD;
  v_res JSONB;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  UPDATE public.solicitudes_prestamo sp
  SET estado = 'en_comite',
      transmitida_at = now(),
      updated_at = now()
  WHERE sp.estado = 'pendiente'
    AND public.asesor_atiende_cliente(sp.user_id);

  GET DIAGNOSTICS v_solicitudes = ROW_COUNT;

  UPDATE public.documentos_captura dc
  SET estado = 'transmitido'
  WHERE dc.estado = 'capturado'
    AND dc.asesor_user_id = auth.uid()
    AND public.asesor_atiende_cliente(dc.user_id);

  GET DIAGNOSTICS v_documentos = ROW_COUNT;

  -- Auto-promover: comité → desembolso → reflejo en app clientes
  FOR r IN
    SELECT id FROM public.solicitudes_prestamo
    WHERE estado = 'en_comite'
      AND public.asesor_atiende_cliente(user_id)
  LOOP
    v_res := public.fn_desembolsar_solicitud(r.id);
    IF (v_res->>'ok')::BOOLEAN THEN
      v_desembolsos := v_desembolsos + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'solicitudes_transmitidas', v_solicitudes,
    'documentos_transmitidos', v_documentos,
    'desembolsos_reflejados', v_desembolsos
  );
END;
$$;

-- ── Buró con consentimiento firmado (RF-57) ────────────────────
CREATE OR REPLACE FUNCTION public.asesor_consulta_buro_con_consentimiento(
  p_user_id UUID,
  p_consentimiento BOOLEAN DEFAULT FALSE,
  p_firma_base64 TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil  RECORD;
  v_score   RECORD;
  v_ficha   RECORD;
  v_dni     TEXT;
  v_lista_negra BOOLEAN := FALSE;
  v_result JSONB;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  IF NOT p_consentimiento THEN
    RETURN jsonb_build_object('ok', false, 'error', 'consentimiento_requerido');
  END IF;

  IF NOT public.asesor_atiende_cliente(p_user_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cliente_no_cartera');
  END IF;

  SELECT dni, nombres, apellidos,
         calificacion_sbs, num_entidades_sbs, deuda_total_sbs
  INTO v_perfil
  FROM public.perfiles_clientes
  WHERE user_id = p_user_id;

  v_dni := v_perfil.dni;
  v_lista_negra := COALESCE(v_perfil.calificacion_sbs, 'Normal') = 'Perdida';

  SELECT score_transaccional, segmento_preliminar, monto_hipotesis
  INTO v_score
  FROM public.scores_transaccionales
  WHERE user_id = p_user_id
  ORDER BY fecha_calculo DESC
  LIMIT 1;

  SELECT score_campo, score_final, segmento_resultante,
         recomendacion_asesor, estado_ficha
  INTO v_ficha
  FROM public.fichas_campo
  WHERE user_id = p_user_id
  ORDER BY fecha_visita DESC
  LIMIT 1;

  v_result := jsonb_build_object(
    'ok', true,
    'cliente', jsonb_build_object(
      'dni', v_perfil.dni,
      'nombres', v_perfil.nombres,
      'apellidos', v_perfil.apellidos
    ),
    'sbs', jsonb_build_object(
      'calificacion', COALESCE(v_perfil.calificacion_sbs, 'Normal'),
      'entidades', COALESCE(v_perfil.num_entidades_sbs, 0),
      'deuda_total', COALESCE(v_perfil.deuda_total_sbs, 0),
      'en_lista_negra', v_lista_negra
    ),
    'scoring', jsonb_build_object(
      'transaccional', v_score.score_transaccional,
      'segmento_preliminar', v_score.segmento_preliminar,
      'monto_hipotesis', v_score.monto_hipotesis,
      'campo', v_ficha.score_campo,
      'final', v_ficha.score_final,
      'segmento_resultante', v_ficha.segmento_resultante,
      'recomendacion_asesor', v_ficha.recomendacion_asesor,
      'estado_ficha', v_ficha.estado_ficha
    )
  );

  INSERT INTO public.consultas_buro (
    asesor_user_id, cliente_user_id, dni_consultado,
    calificacion_sbs, en_lista_negra,
    firma_consentimiento_base64, consentimiento_aceptado, resultado_json
  ) VALUES (
    auth.uid(), p_user_id, COALESCE(v_dni, ''),
    COALESCE(v_perfil.calificacion_sbs, 'Normal'),
    v_lista_negra,
    p_firma_base64, TRUE, v_result
  );

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_consulta_buro_con_consentimiento(UUID, BOOLEAN, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_consulta_buro_con_consentimiento(UUID, BOOLEAN, TEXT) TO authenticated;

-- ── Reporte productividad (solo supervisor/admin — RF-80) ──────
CREATE OR REPLACE FUNCTION public.asesor_reporte_productividad()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  IF NOT public.asesor_es_supervisor() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'sin_permiso', 'codigo', 403);
  END IF;

  SELECT COALESCE(jsonb_agg(row ORDER BY (row->>'enviadas')::INT DESC), '[]'::JSONB)
  INTO v_result
  FROM (
    SELECT jsonb_build_object(
      'asesor_codigo', sp.asesor_codigo,
      'enviadas', COUNT(*),
      'aprobadas', COUNT(*) FILTER (WHERE sp.estado IN ('aprobado','desembolsado')),
      'desembolsadas', COUNT(*) FILTER (WHERE sp.estado = 'desembolsado'),
      'monto_total', COALESCE(SUM(sp.monto), 0)
    ) AS row
    FROM public.solicitudes_prestamo sp
    WHERE date_trunc('month', sp.created_at) = date_trunc('month', now())
    GROUP BY sp.asesor_codigo
  ) sub;

  RETURN jsonb_build_object('ok', true, 'reporte', v_result);
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_reporte_productividad() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_reporte_productividad() TO authenticated;

-- ── Login cliente: verificar bloqueo ───────────────────────────
CREATE OR REPLACE FUNCTION public.cliente_verificar_bloqueo(p_dni TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pc RECORD;
BEGIN
  SELECT intentos_fallidos, bloqueado_hasta
  INTO v_pc
  FROM public.perfiles_clientes
  WHERE dni = trim(p_dni);

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'bloqueado', false);
  END IF;

  IF v_pc.bloqueado_hasta IS NOT NULL AND v_pc.bloqueado_hasta > now() THEN
    RETURN jsonb_build_object(
      'ok', true, 'bloqueado', true,
      'hasta', v_pc.bloqueado_hasta
    );
  END IF;

  RETURN jsonb_build_object('ok', true, 'bloqueado', false);
END;
$$;

REVOKE ALL ON FUNCTION public.cliente_verificar_bloqueo(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_verificar_bloqueo(TEXT) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.cliente_registrar_intento_fallido(p_dni TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.perfiles_clientes
  SET intentos_fallidos = intentos_fallidos + 1,
      bloqueado_hasta = CASE
        WHEN intentos_fallidos + 1 >= 5 THEN now() + INTERVAL '30 minutes'
        ELSE bloqueado_hasta
      END
  WHERE dni = trim(p_dni);
END;
$$;

REVOKE ALL ON FUNCTION public.cliente_registrar_intento_fallido(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_registrar_intento_fallido(TEXT) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.cliente_reset_intentos(p_dni TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.perfiles_clientes
  SET intentos_fallidos = 0, bloqueado_hasta = NULL
  WHERE dni = trim(p_dni);
END;
$$;

REVOKE ALL ON FUNCTION public.cliente_reset_intentos(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_reset_intentos(TEXT) TO authenticated;

-- ── Operaciones cliente: transferencia ─────────────────────────
CREATE OR REPLACE FUNCTION public.cliente_realizar_transferencia(
  p_cuenta_origen_id UUID,
  p_cuenta_destino_numero TEXT,
  p_monto NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_origen RECORD;
  v_destino RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  IF p_monto IS NULL OR p_monto <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'monto_invalido');
  END IF;

  SELECT * INTO v_origen
  FROM public.cuentas
  WHERE id = p_cuenta_origen_id AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cuenta_origen_invalida');
  END IF;

  IF v_origen.saldo < p_monto THEN
    RETURN jsonb_build_object('ok', false, 'error', 'saldo_insuficiente');
  END IF;

  SELECT * INTO v_destino
  FROM public.cuentas
  WHERE numero_cuenta = trim(p_cuenta_destino_numero)
    AND user_id != v_user_id
  FOR UPDATE;

  UPDATE public.cuentas SET saldo = saldo - p_monto WHERE id = v_origen.id;

  IF FOUND AND v_destino.id IS NOT NULL THEN
    UPDATE public.cuentas SET saldo = saldo + p_monto WHERE id = v_destino.id;
  END IF;

  INSERT INTO public.transacciones (user_id, cuenta_id, tipo, descripcion, monto)
  VALUES (v_user_id, v_origen.id, 'debito',
    'Transferencia a ' || p_cuenta_destino_numero, p_monto);

  IF v_destino.id IS NOT NULL THEN
    INSERT INTO public.transacciones (user_id, cuenta_id, tipo, descripcion, monto)
    VALUES (v_destino.user_id, v_destino.id, 'credito',
      'Transferencia recibida de ' || v_origen.numero_cuenta, p_monto);
  END IF;

  INSERT INTO public.notificaciones (destinatario_tipo, user_id, titulo, cuerpo, tipo)
  VALUES ('cliente', v_user_id, 'Transferencia realizada',
    'Enviaste S/ ' || p_monto::TEXT || ' a cuenta ' || p_cuenta_destino_numero,
    'transferencia');

  RETURN jsonb_build_object('ok', true, 'nuevo_saldo', v_origen.saldo - p_monto);
END;
$$;

REVOKE ALL ON FUNCTION public.cliente_realizar_transferencia(UUID, TEXT, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_realizar_transferencia(UUID, TEXT, NUMERIC) TO authenticated;

-- ── Operaciones cliente: pago de cuota ─────────────────────────
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
    AND estado_cuota = 'pendiente'
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

-- ── Marcar notificación leída ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.cliente_marcar_notificacion_leida(p_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.notificaciones
  SET leida = TRUE
  WHERE id = p_id AND user_id = auth.uid();

  RETURN jsonb_build_object('ok', FOUND);
END;
$$;

REVOKE ALL ON FUNCTION public.cliente_marcar_notificacion_leida(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_marcar_notificacion_leida(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
