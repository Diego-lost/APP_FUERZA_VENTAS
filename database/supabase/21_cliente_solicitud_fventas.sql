-- ============================================================
-- Caso 1: Cliente solicita crédito → FVentas evalúa y aprueba
-- Ejecutar después de 20_fix_verificar_bloqueo_volatile.sql
-- ============================================================

ALTER TABLE public.solicitudes_prestamo
  ADD COLUMN IF NOT EXISTS numero_expediente TEXT;

ALTER TABLE public.solicitudes_prestamo
  ADD COLUMN IF NOT EXISTS origen TEXT DEFAULT 'asesor';

ALTER TABLE public.solicitudes_prestamo
  DROP CONSTRAINT IF EXISTS solicitudes_prestamo_origen_check;

ALTER TABLE public.solicitudes_prestamo
  ADD CONSTRAINT solicitudes_prestamo_origen_check
  CHECK (origen IN ('cliente', 'asesor'));

ALTER TABLE public.solicitudes_prestamo
  DROP CONSTRAINT IF EXISTS solicitudes_prestamo_estado_check;

ALTER TABLE public.solicitudes_prestamo
  ADD CONSTRAINT solicitudes_prestamo_estado_check
  CHECK (estado IN (
    'enviado', 'pendiente', 'en_comite', 'aprobado',
    'desembolsado', 'rechazado', 'completado'
  ));

-- ── Código del asesor asignado al cliente (ficha de campo) ─────
CREATE OR REPLACE FUNCTION public.cliente_asesor_codigo(p_user_id UUID)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT an.codigo
  FROM public.fichas_campo fc
  JOIN public.asesores_negocio an
    ON fc.asesor_nombre = (an.nombres || ' ' || an.apellidos)
  WHERE fc.user_id = p_user_id
    AND an.activo = TRUE
  ORDER BY fc.fecha_visita DESC NULLS LAST, fc.created_at DESC NULLS LAST
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.cliente_asesor_codigo(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_asesor_codigo(UUID) TO authenticated;

-- ── Cuota mensual (amortización francesa) ─────────────────────
CREATE OR REPLACE FUNCTION public.calcular_cuota_mensual(
  p_monto NUMERIC,
  p_plazo_meses INT,
  p_tea NUMERIC DEFAULT 60
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_tea NUMERIC := p_tea / 100.0;
  v_tm  NUMERIC;
  v_den NUMERIC;
BEGIN
  IF p_monto IS NULL OR p_monto <= 0 OR p_plazo_meses IS NULL OR p_plazo_meses <= 0 THEN
    RETURN 0;
  END IF;

  v_tm := POWER(1 + v_tea, 1.0 / 12) - 1;
  v_den := POWER(1 + v_tm, p_plazo_meses) - 1;

  IF ABS(v_den) < 0.000001 THEN
    RETURN ROUND(p_monto / p_plazo_meses, 2);
  END IF;

  RETURN ROUND(p_monto * v_tm * POWER(1 + v_tm, p_plazo_meses) / v_den, 2);
END;
$$;

-- ── RPC: solicitud desde App Clientes (estado enviado) ────────
CREATE OR REPLACE FUNCTION public.cliente_solicitar_credito(
  p_monto         NUMERIC,
  p_plazo_meses   INT,
  p_tipo_producto TEXT DEFAULT 'empresarial',
  p_proposito     TEXT DEFAULT NULL,
  p_tea           NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id       UUID := auth.uid();
  v_asesor_codigo TEXT;
  v_tea           NUMERIC;
  v_cuota         NUMERIC;
  v_id            UUID;
  v_expediente    TEXT;
  v_asesor_uid    UUID;
  v_cliente       RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  IF p_monto IS NULL OR p_monto <= 0 OR p_plazo_meses IS NULL OR p_plazo_meses <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'datos_invalidos');
  END IF;

  IF p_tipo_producto NOT IN ('empresarial', 'prospera', 'mujeres_unidas', 'construyendo_suenos') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'producto_invalido');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.solicitudes_prestamo sp
    WHERE sp.user_id = v_user_id
      AND sp.tipo_producto = p_tipo_producto
      AND sp.estado IN ('enviado', 'pendiente', 'en_comite', 'aprobado')
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'solicitud_activa');
  END IF;

  v_asesor_codigo := public.cliente_asesor_codigo(v_user_id);
  IF v_asesor_codigo IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'sin_asesor');
  END IF;

  v_tea := COALESCE(
    p_tea,
    CASE p_tipo_producto
      WHEN 'empresarial' THEN 43.92
      ELSE 60.00
    END
  );

  v_cuota := public.calcular_cuota_mensual(p_monto, p_plazo_meses, v_tea);

  INSERT INTO public.solicitudes_prestamo (
    user_id, monto, plazo_meses, tasa_anual, cuota_mensual,
    proposito, estado, tipo_producto, asesor_codigo, origen
  ) VALUES (
    v_user_id, p_monto, p_plazo_meses, v_tea, v_cuota,
    COALESCE(
      NULLIF(TRIM(p_proposito), ''),
      'Solicitud registrada desde App Clientes'
    ),
    'enviado', p_tipo_producto, v_asesor_codigo, 'cliente'
  )
  RETURNING id INTO v_id;

  v_expediente := 'EXP-' || UPPER(REPLACE(v_id::TEXT, '-', ''))::TEXT;
  v_expediente := LEFT(v_expediente, 12);

  UPDATE public.solicitudes_prestamo
  SET numero_expediente = v_expediente
  WHERE id = v_id;

  SELECT nombres, apellidos, dni
  INTO v_cliente
  FROM public.perfiles_clientes
  WHERE user_id = v_user_id;

  SELECT user_id INTO v_asesor_uid
  FROM public.asesores_negocio
  WHERE codigo = v_asesor_codigo AND activo = TRUE
  LIMIT 1;

  IF v_asesor_uid IS NOT NULL THEN
    INSERT INTO public.notificaciones (
      destinatario_tipo, user_id, titulo, cuerpo, tipo, data_json
    ) VALUES (
      'asesor', v_asesor_uid,
      'Nueva solicitud de crédito',
      COALESCE(v_cliente.nombres, 'Cliente') || ' ' || COALESCE(v_cliente.apellidos, '')
        || ' (DNI ' || COALESCE(v_cliente.dni, '—') || ') solicitó S/ '
        || p_monto::TEXT || ' a ' || p_plazo_meses::TEXT || ' meses.',
      'nueva_solicitud',
      jsonb_build_object(
        'solicitud_id', v_id,
        'numero_expediente', v_expediente,
        'cliente_user_id', v_user_id,
        'monto', p_monto,
        'plazo_meses', p_plazo_meses
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'solicitud_id', v_id,
    'numero_expediente', v_expediente,
    'cuota_mensual', v_cuota,
    'tasa_anual', v_tea,
    'estado', 'enviado',
    'asesor_codigo', v_asesor_codigo
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cliente_solicitar_credito(NUMERIC, INT, TEXT, TEXT, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_solicitar_credito(NUMERIC, INT, TEXT, TEXT, NUMERIC) TO authenticated;

-- ── Ruta del día: priorizar NUEVA_SOLICITUD del cliente ───────
CREATE OR REPLACE FUNCTION public.asesor_get_ruta_dia()
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
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
      'tipo_gestion', CASE
        WHEN sp.id IS NOT NULL THEN 'NUEVA_SOLICITUD'
        ELSE NULL
      END,
      'solicitud_id', sp.id,
      'numero_expediente', sp.numero_expediente,
      'solicitud_monto', sp.monto,
      'solicitud_plazo', sp.plazo_meses,
      'solicitud_cuota', sp.cuota_mensual,
      'solicitud_estado', sp.estado,
      'solicitud_producto', sp.tipo_producto,
      'prioridad', CASE
        WHEN sp.id IS NOT NULL THEN 150
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
    LEFT JOIN LATERAL (
      SELECT sp2.id, sp2.monto, sp2.plazo_meses, sp2.cuota_mensual,
             sp2.estado, sp2.numero_expediente, sp2.tipo_producto
      FROM public.solicitudes_prestamo sp2
      WHERE sp2.user_id = pc.user_id
        AND sp2.estado IN ('enviado', 'pendiente', 'en_comite')
        AND COALESCE(sp2.origen, 'asesor') = 'cliente'
      ORDER BY sp2.created_at DESC
      LIMIT 1
    ) sp ON TRUE
    WHERE public.asesor_atiende_cliente(pc.user_id)
  ) sub;

  RETURN jsonb_build_object('ok', true, 'paradas', v_result);
END;
$$;

-- Asesor marca solicitud del cliente como en revisión (visita iniciada)
CREATE OR REPLACE FUNCTION public.asesor_atender_solicitud_cliente(p_solicitud_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sp RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  SELECT * INTO v_sp
  FROM public.solicitudes_prestamo
  WHERE id = p_solicitud_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_encontrada');
  END IF;

  IF NOT public.asesor_atiende_cliente(v_sp.user_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cliente_no_cartera');
  END IF;

  IF v_sp.estado <> 'enviado' THEN
    RETURN jsonb_build_object('ok', true, 'estado', v_sp.estado);
  END IF;

  UPDATE public.solicitudes_prestamo
  SET estado = 'pendiente',
      asesor_codigo = COALESCE(asesor_codigo, public.current_asesor_codigo()),
      updated_at = now()
  WHERE id = p_solicitud_id;

  RETURN jsonb_build_object('ok', true, 'estado', 'pendiente');
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_atender_solicitud_cliente(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_atender_solicitud_cliente(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
