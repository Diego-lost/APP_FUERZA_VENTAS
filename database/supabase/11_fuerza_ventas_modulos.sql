-- ============================================================
-- App Fuerza de Ventas: módulos de gestión de clientes
-- Ejecutar DESPUÉS de 10_fuerza_ventas_auth.sql
-- ============================================================

-- ── Ampliar solicitudes_prestamo (workflow asesor → comité) ──
ALTER TABLE public.solicitudes_prestamo
  ADD COLUMN IF NOT EXISTS tipo_producto TEXT DEFAULT 'prospera';

ALTER TABLE public.solicitudes_prestamo
  ADD COLUMN IF NOT EXISTS asesor_codigo TEXT;

ALTER TABLE public.solicitudes_prestamo
  ADD COLUMN IF NOT EXISTS transmitida_at TIMESTAMPTZ;

ALTER TABLE public.solicitudes_prestamo
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

ALTER TABLE public.solicitudes_prestamo
  DROP CONSTRAINT IF EXISTS solicitudes_prestamo_estado_check;

ALTER TABLE public.solicitudes_prestamo
  ADD CONSTRAINT solicitudes_prestamo_estado_check
  CHECK (estado IN (
    'pendiente', 'en_comite', 'aprobado', 'desembolsado', 'rechazado', 'completado'
  ));

-- ── Documentos capturados en campo ───────────────────────────
CREATE TABLE IF NOT EXISTS public.documentos_captura (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  asesor_user_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tipo            TEXT NOT NULL CHECK (tipo IN (
    'dni_frontal', 'dni_posterior', 'foto_negocio',
    'recibo_servicio', 'contrato_alquiler', 'otro'
  )),
  referencia      TEXT,
  observaciones   TEXT,
  estado          TEXT NOT NULL DEFAULT 'capturado'
                    CHECK (estado IN ('capturado', 'transmitido')),
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_documentos_captura_user
  ON public.documentos_captura(user_id);

CREATE INDEX IF NOT EXISTS idx_documentos_captura_asesor
  ON public.documentos_captura(asesor_user_id);

ALTER TABLE public.documentos_captura ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Asesor ve documentos de su cartera" ON public.documentos_captura;
CREATE POLICY "Asesor ve documentos de su cartera"
  ON public.documentos_captura FOR SELECT
  USING (public.asesor_atiende_cliente(user_id));

DROP POLICY IF EXISTS "Asesor registra documentos de su cartera" ON public.documentos_captura;
CREATE POLICY "Asesor registra documentos de su cartera"
  ON public.documentos_captura FOR INSERT
  WITH CHECK (
    asesor_user_id = auth.uid()
    AND public.asesor_atiende_cliente(user_id)
  );

DROP POLICY IF EXISTS "Asesor actualiza documentos de su cartera" ON public.documentos_captura;
CREATE POLICY "Asesor actualiza documentos de su cartera"
  ON public.documentos_captura FOR UPDATE
  USING (public.asesor_atiende_cliente(user_id));

-- ── RLS solicitudes para asesores ────────────────────────────
DROP POLICY IF EXISTS "Asesor ve solicitudes de su cartera" ON public.solicitudes_prestamo;
CREATE POLICY "Asesor ve solicitudes de su cartera"
  ON public.solicitudes_prestamo FOR SELECT
  USING (public.asesor_atiende_cliente(user_id));

DROP POLICY IF EXISTS "Asesor crea solicitudes de su cartera" ON public.solicitudes_prestamo;
CREATE POLICY "Asesor crea solicitudes de su cartera"
  ON public.solicitudes_prestamo FOR INSERT
  WITH CHECK (public.asesor_atiende_cliente(user_id));

DROP POLICY IF EXISTS "Asesor actualiza solicitudes de su cartera" ON public.solicitudes_prestamo;
CREATE POLICY "Asesor actualiza solicitudes de su cartera"
  ON public.solicitudes_prestamo FOR UPDATE
  USING (public.asesor_atiende_cliente(user_id));

-- ── Helper: código del asesor autenticado ────────────────────
CREATE OR REPLACE FUNCTION public.current_asesor_codigo()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT codigo
  FROM public.asesores_negocio
  WHERE user_id = auth.uid() AND activo = TRUE
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.current_asesor_codigo() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_asesor_codigo() TO authenticated;

-- ── RPC: crear solicitud de crédito (asesor → cliente) ───────
CREATE OR REPLACE FUNCTION public.asesor_crear_solicitud_credito(
  p_user_id       UUID,
  p_monto         NUMERIC,
  p_plazo_meses   INT,
  p_proposito     TEXT DEFAULT NULL,
  p_tipo_producto TEXT DEFAULT 'prospera'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_asesor_codigo TEXT;
  v_tem           NUMERIC;
  v_factor        NUMERIC;
  v_cuota         NUMERIC;
  v_id            UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  IF NOT public.asesor_atiende_cliente(p_user_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cliente_no_cartera');
  END IF;

  IF p_monto IS NULL OR p_monto <= 0 OR p_plazo_meses IS NULL OR p_plazo_meses <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'datos_invalidos');
  END IF;

  IF p_tipo_producto NOT IN ('prospera', 'mujeres_unidas', 'construyendo_suenos') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'producto_invalido');
  END IF;

  v_asesor_codigo := public.current_asesor_codigo();

  v_tem := POWER(1.60, 1.0 / 12) - 1;
  IF ABS(POWER(1 + v_tem, p_plazo_meses) - 1) > 0.000001 THEN
    v_factor := v_tem * POWER(1 + v_tem, p_plazo_meses)
              / (POWER(1 + v_tem, p_plazo_meses) - 1);
  ELSE
    v_factor := 0;
  END IF;
  v_cuota := ROUND(p_monto * v_factor, 2);

  INSERT INTO public.solicitudes_prestamo (
    user_id, monto, plazo_meses, tasa_anual, cuota_mensual,
    proposito, estado, tipo_producto, asesor_codigo
  ) VALUES (
    p_user_id, p_monto, p_plazo_meses, 60.00, v_cuota,
    COALESCE(p_proposito, 'Solicitud registrada por asesor en campo'),
    'pendiente', p_tipo_producto, v_asesor_codigo
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'ok', true,
    'solicitud_id', v_id,
    'cuota_mensual', v_cuota,
    'estado', 'pendiente'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_crear_solicitud_credito(UUID, NUMERIC, INT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_crear_solicitud_credito(UUID, NUMERIC, INT, TEXT, TEXT) TO authenticated;

-- ── RPC: registrar documento capturado ─────────────────────────
CREATE OR REPLACE FUNCTION public.asesor_registrar_documento(
  p_user_id       UUID,
  p_tipo          TEXT,
  p_referencia    TEXT DEFAULT NULL,
  p_observaciones TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  IF NOT public.asesor_atiende_cliente(p_user_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cliente_no_cartera');
  END IF;

  IF p_tipo NOT IN (
    'dni_frontal', 'dni_posterior', 'foto_negocio',
    'recibo_servicio', 'contrato_alquiler', 'otro'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'tipo_invalido');
  END IF;

  INSERT INTO public.documentos_captura (
    user_id, asesor_user_id, tipo, referencia, observaciones
  ) VALUES (
    p_user_id, auth.uid(), p_tipo, p_referencia, p_observaciones
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('ok', true, 'documento_id', v_id);
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_registrar_documento(UUID, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_registrar_documento(UUID, TEXT, TEXT, TEXT) TO authenticated;

-- ── RPC: consulta buró / scoring del cliente ───────────────────
CREATE OR REPLACE FUNCTION public.asesor_consulta_buro(p_user_id UUID)
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
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  IF NOT public.asesor_atiende_cliente(p_user_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cliente_no_cartera');
  END IF;

  SELECT dni, nombres, apellidos,
         calificacion_sbs, num_entidades_sbs, deuda_total_sbs
  INTO v_perfil
  FROM public.perfiles_clientes
  WHERE user_id = p_user_id;

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

  RETURN jsonb_build_object(
    'ok', true,
    'cliente', jsonb_build_object(
      'dni', v_perfil.dni,
      'nombres', v_perfil.nombres,
      'apellidos', v_perfil.apellidos
    ),
    'sbs', jsonb_build_object(
      'calificacion', COALESCE(v_perfil.calificacion_sbs, 'Normal'),
      'entidades', COALESCE(v_perfil.num_entidades_sbs, 0),
      'deuda_total', COALESCE(v_perfil.deuda_total_sbs, 0)
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
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_consulta_buro(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_consulta_buro(UUID) TO authenticated;

-- ── RPC: transmitir pendientes al sistema central ────────────
CREATE OR REPLACE FUNCTION public.asesor_transmitir_pendientes()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_solicitudes INT := 0;
  v_documentos  INT := 0;
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

  RETURN jsonb_build_object(
    'ok', true,
    'solicitudes_transmitidas', v_solicitudes,
    'documentos_transmitidos', v_documentos
  );
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_transmitir_pendientes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_transmitir_pendientes() TO authenticated;

-- ── RPC: ruta del día (clientes priorizados) ─────────────────
CREATE OR REPLACE FUNCTION public.asesor_get_ruta_dia()
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

  SELECT COALESCE(jsonb_agg(row ORDER BY
    (row->>'prioridad')::INT DESC,
    row->>'distrito',
    row->>'apellidos'
  ), '[]'::JSONB)
  INTO v_result
  FROM (
    SELECT jsonb_build_object(
      'user_id', pc.user_id,
      'dni', pc.dni,
      'nombres', pc.nombres,
      'apellidos', pc.apellidos,
      'distrito', pc.distrito,
      'direccion_negocio', pc.direccion_negocio,
      'lat_negocio', pc.lat_negocio,
      'lng_negocio', pc.lng_negocio,
      'telefono', pc.telefono,
      'dias_mora', COALESCE(cp.dias_mora, 0),
      'estado_pago', cp.estado_pago,
      'prioridad', CASE
        WHEN COALESCE(cp.dias_mora, 0) > 30 THEN 100
        WHEN COALESCE(cp.dias_mora, 0) > 0  THEN 80
        WHEN cp.estado_pago IS DISTINCT FROM 'al_dia' THEN 60
        ELSE 40
      END
    ) AS row
    FROM public.perfiles_clientes pc
    LEFT JOIN LATERAL (
      SELECT dias_mora, estado_pago
      FROM public.creditos_preaprobados
      WHERE user_id = pc.user_id
      ORDER BY created_at DESC
      LIMIT 1
    ) cp ON TRUE
    WHERE public.asesor_atiende_cliente(pc.user_id)
  ) sub;

  RETURN jsonb_build_object('ok', true, 'paradas', v_result);
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_get_ruta_dia() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_get_ruta_dia() TO authenticated;

NOTIFY pgrst, 'reload schema';
