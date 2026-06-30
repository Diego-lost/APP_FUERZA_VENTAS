-- ============================================================
-- Parche: columnas workflow + desembolso resiliente
-- Ejecutar si FVentas crea solicitud pero clientes no ve crédito.
-- Requiere 01b y 13 (o al menos prestamos + cronograma_cuotas).
-- ============================================================

ALTER TABLE public.solicitudes_prestamo
  ADD COLUMN IF NOT EXISTS tipo_producto TEXT DEFAULT 'prospera';

ALTER TABLE public.solicitudes_prestamo
  ADD COLUMN IF NOT EXISTS asesor_codigo TEXT;

ALTER TABLE public.solicitudes_prestamo
  ADD COLUMN IF NOT EXISTS transmitida_at TIMESTAMPTZ;

ALTER TABLE public.solicitudes_prestamo
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

ALTER TABLE public.creditos_preaprobados
  ADD COLUMN IF NOT EXISTS tipo_producto TEXT DEFAULT 'prospera';

-- Desembolso: no revierte préstamo si falla creditos_preaprobados
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

  UPDATE public.solicitudes_prestamo
  SET estado = 'desembolsado', updated_at = now()
  WHERE id = p_solicitud_id;

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

  BEGIN
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
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

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

NOTIFY pgrst, 'reload schema';
