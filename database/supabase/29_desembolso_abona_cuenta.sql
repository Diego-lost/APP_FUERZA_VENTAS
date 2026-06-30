-- ============================================================
-- Al aprobar: desembolso automático + abono a cuenta del cliente
-- Ejecutar después de 28_asesor_responder_solicitud.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_desembolsar_solicitud(p_solicitud_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sol            RECORD;
  v_prestamo_id    UUID;
  v_cod_credito    TEXT;
  v_outbox_id      UUID;
  v_cuenta_id      UUID;
  v_nuevo_saldo    NUMERIC;
  v_saldo_anterior NUMERIC := 0;
  v_monto_abonado  NUMERIC;
  v_dni            TEXT;
BEGIN
  SELECT * INTO v_sol
  FROM public.solicitudes_prestamo
  WHERE id = p_solicitud_id AND estado = 'en_comite'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'solicitud_no_en_comite');
  END IF;

  v_monto_abonado := v_sol.monto;
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

  -- Abonar cuenta corriente (crear si el cliente no tiene)
  SELECT id, saldo INTO v_cuenta_id, v_saldo_anterior
  FROM public.cuentas
  WHERE user_id = v_sol.user_id
  ORDER BY CASE tipo WHEN 'corriente' THEN 0 ELSE 1 END, created_at
  LIMIT 1
  FOR UPDATE;

  IF v_cuenta_id IS NULL THEN
    SELECT dni INTO v_dni
    FROM public.perfiles_clientes
    WHERE user_id = v_sol.user_id;

    INSERT INTO public.cuentas (user_id, tipo, numero_cuenta, saldo, moneda)
    VALUES (
      v_sol.user_id,
      'corriente',
      '019-' || LPAD(RIGHT(COALESCE(v_dni, '0000001'), 7), 7, '0'),
      0,
      'PEN'
    )
    RETURNING id, saldo INTO v_cuenta_id, v_saldo_anterior;
  END IF;

  IF v_cuenta_id IS NOT NULL THEN
    UPDATE public.cuentas
    SET saldo = saldo + v_monto_abonado
    WHERE id = v_cuenta_id
    RETURNING saldo INTO v_nuevo_saldo;

    INSERT INTO public.transacciones (
      user_id, cuenta_id, tipo, descripcion, monto
    ) VALUES (
      v_sol.user_id, v_cuenta_id, 'credito',
      'Desembolso solicitud S/ ' || v_monto_abonado::TEXT
        || ' · saldo S/ ' || v_saldo_anterior::TEXT
        || ' → S/ ' || v_nuevo_saldo::TEXT,
      v_monto_abonado
    );
  END IF;

  INSERT INTO public.notificaciones (
    destinatario_tipo, user_id, titulo, cuerpo, tipo, data_json
  ) VALUES (
    'cliente', v_sol.user_id,
    'Crédito desembolsado',
    'Tu solicitud de S/ ' || v_monto_abonado::TEXT
      || ' fue aprobada. Tu saldo pasó de S/ ' || v_saldo_anterior::TEXT
      || ' a S/ ' || COALESCE(v_nuevo_saldo, v_saldo_anterior + v_monto_abonado)::TEXT
      || ' (+' || v_monto_abonado::TEXT || '). Revisa Mis créditos y Mis cuentas.',
    'desembolsado',
    jsonb_build_object(
      'solicitud_id', p_solicitud_id,
      'prestamo_id', v_prestamo_id,
      'cod_credito', v_cod_credito,
      'monto', v_monto_abonado,
      'saldo_anterior', v_saldo_anterior,
      'nuevo_saldo_cuenta', v_nuevo_saldo
    )
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
    'Crédito + abono cuenta + cronograma para app clientes'
  );

  RETURN jsonb_build_object(
    'ok', true,
    'prestamo_id', v_prestamo_id,
    'cod_credito', v_cod_credito,
    'outbox_id', v_outbox_id,
    'monto_desembolsado', v_monto_abonado,
    'cuenta_acreditada', v_cuenta_id IS NOT NULL,
    'saldo_anterior', v_saldo_anterior,
    'nuevo_saldo_cuenta', v_nuevo_saldo
  );
END;
$$;

-- Aprobar = desembolso inmediato (saldo + crédito activo en app clientes)
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
  v_sp            RECORD;
  v_nuevo_estado  TEXT;
  v_cuota         NUMERIC;
  v_ficha_id      UUID;
  v_titulo        TEXT;
  v_cuerpo        TEXT;
  v_desembolso    JSONB;
  v_monto_final   NUMERIC;
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

  v_monto_final := CASE
    WHEN p_decision = 'aprobar_monto_reducido' THEN p_monto_ajustado
    ELSE v_sp.monto
  END;

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
        asesor_codigo = COALESCE(asesor_codigo, public.current_asesor_codigo()),
        updated_at = now()
    WHERE id = p_solicitud_id;
  ELSIF p_decision IN ('aprobar', 'elevar_comite', 'rechazar') THEN
    UPDATE public.solicitudes_prestamo
    SET asesor_codigo = COALESCE(asesor_codigo, public.current_asesor_codigo()),
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
          WHEN p_decision IN ('aprobar', 'aprobar_monto_reducido') THEN v_monto_final
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

  IF p_decision IN ('aprobar', 'aprobar_monto_reducido') THEN
    UPDATE public.solicitudes_prestamo
    SET estado = 'en_comite', transmitida_at = now(), updated_at = now()
    WHERE id = p_solicitud_id;

    v_desembolso := public.fn_desembolsar_solicitud(p_solicitud_id);

    IF NOT COALESCE((v_desembolso->>'ok')::BOOLEAN, FALSE) THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'desembolso_fallido',
        'detalle', v_desembolso->>'error'
      );
    END IF;

    v_nuevo_estado := 'desembolsado';

    RETURN jsonb_build_object(
      'ok', true,
      'estado', v_nuevo_estado,
      'decision', p_decision,
      'monto', v_monto_final,
      'cuota_mensual', CASE
        WHEN p_decision = 'aprobar_monto_reducido' THEN v_cuota
        ELSE v_sp.cuota_mensual
      END,
      'desembolsado', true,
      'prestamo_id', v_desembolso->>'prestamo_id',
      'cod_credito', v_desembolso->>'cod_credito',
      'nuevo_saldo_cuenta', v_desembolso->'nuevo_saldo_cuenta'
    );
  END IF;

  UPDATE public.solicitudes_prestamo
  SET estado = v_nuevo_estado, updated_at = now()
  WHERE id = p_solicitud_id;

  CASE p_decision
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
    ELSE
      v_titulo := NULL;
  END CASE;

  IF v_titulo IS NOT NULL THEN
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
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'estado', v_nuevo_estado,
    'decision', p_decision,
    'monto', v_monto_final,
    'cuota_mensual', COALESCE(v_cuota, v_sp.cuota_mensual),
    'desembolsado', false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_desembolsar_solicitud(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_desembolsar_solicitud(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.asesor_responder_solicitud(UUID, TEXT, TEXT, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_responder_solicitud(UUID, TEXT, TEXT, NUMERIC) TO authenticated;

NOTIFY pgrst, 'reload schema';
