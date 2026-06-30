-- ============================================================
-- Aprobar ≠ desembolsar: el asesor elige en Transmisión
-- Ejecutar DESPUÉS de 29_desembolso_abona_cuenta.sql
-- ============================================================

-- ── Evaluar: solo cambia estado (sin desembolso) ─────────────
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
        || v_sp.monto::TEXT || ' a ' || v_sp.plazo_meses::TEXT
        || ' meses. El desembolso se realizará en los próximos días.';
    WHEN 'aprobar_monto_reducido' THEN
      v_titulo := 'Solicitud aprobada con ajuste';
      v_cuerpo := 'Tu asesor aprobó tu solicitud con monto reducido: S/ '
        || p_monto_ajustado::TEXT || ' (solicitaste S/ ' || v_sp.monto::TEXT
        || '). El desembolso se realizará en los próximos días.';
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
    END,
    'desembolsado', false
  );
END;
$$;

-- ── Desembolsar solo las solicitudes seleccionadas (estado aprobado) ──
CREATE OR REPLACE FUNCTION public.asesor_desembolsar_solicitudes(
  p_solicitud_ids UUID[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id            UUID;
  v_res           JSONB;
  v_ok            INT := 0;
  v_fail          INT := 0;
  v_errores       JSONB := '[]'::JSONB;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  IF p_solicitud_ids IS NULL OR cardinality(p_solicitud_ids) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'sin_seleccion');
  END IF;

  FOREACH v_id IN ARRAY p_solicitud_ids
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM public.solicitudes_prestamo sp
      WHERE sp.id = v_id
        AND sp.estado = 'aprobado'
        AND public.asesor_atiende_cliente(sp.user_id)
    ) THEN
      v_fail := v_fail + 1;
      v_errores := v_errores || jsonb_build_array(
        jsonb_build_object('solicitud_id', v_id, 'error', 'no_aprobada_o_sin_permiso')
      );
      CONTINUE;
    END IF;

    UPDATE public.solicitudes_prestamo
    SET estado = 'en_comite',
        transmitida_at = now(),
        updated_at = now()
    WHERE id = v_id;

    v_res := public.fn_desembolsar_solicitud(v_id);

    IF COALESCE((v_res->>'ok')::BOOLEAN, FALSE) THEN
      v_ok := v_ok + 1;

      INSERT INTO public.notificaciones (
        destinatario_tipo, user_id, titulo, cuerpo, tipo, data_json
      )
      SELECT
        'cliente',
        sp.user_id,
        'Crédito desembolsado',
        'Se abonó S/ ' || sp.monto::TEXT || ' a tu cuenta. Ya puedes ver tu crédito activo.',
        'desembolso',
        jsonb_build_object(
          'solicitud_id', v_id,
          'prestamo_id', v_res->>'prestamo_id',
          'cod_credito', v_res->>'cod_credito'
        )
      FROM public.solicitudes_prestamo sp
      WHERE sp.id = v_id;
    ELSE
      UPDATE public.solicitudes_prestamo
      SET estado = 'aprobado', updated_at = now()
      WHERE id = v_id AND estado = 'en_comite';

      v_fail := v_fail + 1;
      v_errores := v_errores || jsonb_build_array(
        jsonb_build_object(
          'solicitud_id', v_id,
          'error', COALESCE(v_res->>'error', 'desembolso_fallido')
        )
      );
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'desembolsos_ok', v_ok,
    'desembolsos_fallidos', v_fail,
    'desembolsos_reflejados', v_ok,
    'errores', v_errores
  );
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_desembolsar_solicitudes(UUID[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_desembolsar_solicitudes(UUID[]) TO authenticated;

-- ── Transmisión: solo documentos (sin desembolso automático) ──
CREATE OR REPLACE FUNCTION public.asesor_transmitir_pendientes()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_documentos INT := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  UPDATE public.documentos_captura dc
  SET estado = 'transmitido'
  WHERE dc.estado = 'capturado'
    AND dc.asesor_user_id = auth.uid()
    AND public.asesor_atiende_cliente(dc.user_id);

  GET DIAGNOSTICS v_documentos = ROW_COUNT;

  RETURN jsonb_build_object(
    'ok', true,
    'solicitudes_transmitidas', 0,
    'documentos_transmitidos', v_documentos,
    'desembolsos_reflejados', 0
  );
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_responder_solicitud(UUID, TEXT, TEXT, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_responder_solicitud(UUID, TEXT, TEXT, NUMERIC) TO authenticated;

REVOKE ALL ON FUNCTION public.asesor_transmitir_pendientes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_transmitir_pendientes() TO authenticated;

NOTIFY pgrst, 'reload schema';
