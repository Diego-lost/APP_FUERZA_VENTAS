-- ============================================================
-- FVentas: asesor aprueba / rechaza / eleva solicitud de crédito
-- Ejecutar después de 27_fix_transferencia_destino.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.asesor_responder_solicitud(
  p_solicitud_id    UUID,
  p_decision        TEXT,
  p_observaciones   TEXT DEFAULT NULL,
  p_monto_ajustado  NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sp           RECORD;
  v_nuevo_estado TEXT;
  v_cuota        NUMERIC;
  v_ficha_id     UUID;
  v_titulo       TEXT;
  v_cuerpo       TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  IF p_decision NOT IN (
    'aprobar', 'aprobar_monto_reducido', 'elevar_comite', 'rechazar'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'decision_invalida');
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

  IF v_sp.estado NOT IN ('enviado', 'pendiente') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'estado_invalido', 'estado', v_sp.estado);
  END IF;

  IF p_decision = 'aprobar_monto_reducido' THEN
    IF p_monto_ajustado IS NULL OR p_monto_ajustado <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'error', 'monto_requerido');
    END IF;
    IF p_monto_ajustado >= v_sp.monto THEN
      RETURN jsonb_build_object('ok', false, 'error', 'monto_debe_ser_menor');
    END IF;
  END IF;

  CASE p_decision
    WHEN 'aprobar' THEN v_nuevo_estado := 'aprobado';
    WHEN 'aprobar_monto_reducido' THEN v_nuevo_estado := 'aprobado';
    WHEN 'elevar_comite' THEN v_nuevo_estado := 'en_comite';
    WHEN 'rechazar' THEN v_nuevo_estado := 'rechazado';
  END CASE;

  IF p_decision = 'aprobar_monto_reducido' THEN
    v_cuota := public.calcular_cuota_mensual(
      p_monto_ajustado, v_sp.plazo_meses, COALESCE(v_sp.tasa_anual, 60.00)
    );
    UPDATE public.solicitudes_prestamo
    SET monto = p_monto_ajustado,
        cuota_mensual = v_cuota,
        estado = v_nuevo_estado,
        asesor_codigo = COALESCE(asesor_codigo, public.current_asesor_codigo()),
        updated_at = now()
    WHERE id = p_solicitud_id;
  ELSE
    UPDATE public.solicitudes_prestamo
    SET estado = v_nuevo_estado,
        asesor_codigo = COALESCE(asesor_codigo, public.current_asesor_codigo()),
        updated_at = now()
    WHERE id = p_solicitud_id;
  END IF;

  SELECT id INTO v_ficha_id
  FROM public.fichas_campo
  WHERE user_id = v_sp.user_id
  ORDER BY fecha_visita DESC NULLS LAST, created_at DESC
  LIMIT 1;

  IF v_ficha_id IS NOT NULL THEN
    UPDATE public.fichas_campo
    SET recomendacion_asesor = p_decision,
        obs_finales = COALESCE(NULLIF(TRIM(p_observaciones), ''), obs_finales),
        monto_aprobado_propuesto = CASE
          WHEN p_decision = 'aprobar_monto_reducido' THEN p_monto_ajustado
          WHEN p_decision = 'aprobar' THEN v_sp.monto
          ELSE monto_aprobado_propuesto
        END,
        plazo_propuesto_meses = v_sp.plazo_meses,
        cuota_estimada = CASE
          WHEN p_decision = 'aprobar_monto_reducido' THEN v_cuota
          ELSE cuota_estimada
        END,
        estado_ficha = CASE
          WHEN p_decision = 'rechazar' THEN 'cancelada'
          WHEN p_decision IN ('aprobar', 'aprobar_monto_reducido') THEN 'completada'
          ELSE 'en_proceso'
        END,
        updated_at = now()
    WHERE id = v_ficha_id;
  END IF;

  CASE p_decision
    WHEN 'aprobar' THEN
      v_titulo := 'Solicitud aprobada';
      v_cuerpo := 'Tu asesor aprobó tu solicitud de S/ '
        || v_sp.monto::TEXT || ' a ' || v_sp.plazo_meses::TEXT || ' meses.';
    WHEN 'aprobar_monto_reducido' THEN
      v_titulo := 'Solicitud aprobada con ajuste';
      v_cuerpo := 'Tu asesor aprobó tu solicitud con monto reducido: S/ '
        || p_monto_ajustado::TEXT || ' (solicitaste S/ ' || v_sp.monto::TEXT || ').';
    WHEN 'elevar_comite' THEN
      v_titulo := 'Solicitud en comité';
      v_cuerpo := 'Tu solicitud de S/ ' || v_sp.monto::TEXT
        || ' fue elevada al comité de crédito para revisión.';
    WHEN 'rechazar' THEN
      v_titulo := 'Solicitud rechazada';
      v_cuerpo := 'Tu solicitud de S/ ' || v_sp.monto::TEXT
        || ' no fue aprobada.'
        || CASE
             WHEN p_observaciones IS NOT NULL AND TRIM(p_observaciones) <> ''
             THEN ' Motivo: ' || TRIM(p_observaciones)
             ELSE ''
           END;
  END CASE;

  INSERT INTO public.notificaciones (
    destinatario_tipo, user_id, titulo, cuerpo, tipo, data_json
  ) VALUES (
    'cliente', v_sp.user_id, v_titulo, v_cuerpo,
    'resolucion_solicitud',
    jsonb_build_object(
      'solicitud_id', p_solicitud_id,
      'decision', p_decision,
      'estado', v_nuevo_estado
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'estado', v_nuevo_estado,
    'decision', p_decision,
    'monto', CASE
      WHEN p_decision = 'aprobar_monto_reducido' THEN p_monto_ajustado
      ELSE v_sp.monto
    END,
    'cuota_mensual', CASE
      WHEN p_decision = 'aprobar_monto_reducido' THEN v_cuota
      ELSE v_sp.cuota_mensual
    END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_responder_solicitud(UUID, TEXT, TEXT, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_responder_solicitud(UUID, TEXT, TEXT, NUMERIC) TO authenticated;

-- Transmisión: solo solicitudes aprobadas (o creadas por asesor en pendiente)
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
  v_recomendacion TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  UPDATE public.solicitudes_prestamo sp
  SET estado = 'en_comite',
      transmitida_at = now(),
      updated_at = now()
  WHERE public.asesor_atiende_cliente(sp.user_id)
    AND (
      sp.estado = 'aprobado'
      OR (sp.estado = 'pendiente' AND COALESCE(sp.origen, 'asesor') = 'asesor')
    );

  GET DIAGNOSTICS v_solicitudes = ROW_COUNT;

  UPDATE public.documentos_captura dc
  SET estado = 'transmitido'
  WHERE dc.estado = 'capturado'
    AND dc.asesor_user_id = auth.uid()
    AND public.asesor_atiende_cliente(dc.user_id);

  GET DIAGNOSTICS v_documentos = ROW_COUNT;

  FOR r IN
    SELECT sp.id, sp.user_id
    FROM public.solicitudes_prestamo sp
    WHERE sp.estado = 'en_comite'
      AND public.asesor_atiende_cliente(sp.user_id)
  LOOP
    SELECT fc.recomendacion_asesor INTO v_recomendacion
    FROM public.fichas_campo fc
    WHERE fc.user_id = r.user_id
    ORDER BY fc.fecha_visita DESC NULLS LAST, fc.created_at DESC
    LIMIT 1;

    IF COALESCE(v_recomendacion, 'aprobar') IN ('aprobar', 'aprobar_monto_reducido') THEN
      v_res := public.fn_desembolsar_solicitud(r.id);
      IF (v_res->>'ok')::BOOLEAN THEN
        v_desembolsos := v_desembolsos + 1;
      END IF;
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

REVOKE ALL ON FUNCTION public.asesor_transmitir_pendientes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_transmitir_pendientes() TO authenticated;

NOTIFY pgrst, 'reload schema';
