-- ============================================================
-- Cartera del día: visita tras aprobar solicitud
-- Ejecutar DESPUÉS de 33_cartera_visitas_dia.sql
-- ============================================================
-- Al aprobar, el cliente debe aparecer en cartera para visitarlo
-- (entrega / desembolso en campo). Antes solo figuraban solicitudes
-- en trámite; al pasar a "aprobado" desaparecían de la ruta.

-- ── Al aprobar: reingresa a cartera del día (quita visita de hoy) ──
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

  -- Reingresa a cartera del día para visita de desembolso
  IF p_decision IN ('aprobar', 'aprobar_monto_reducido') THEN
    DELETE FROM public.visitas_cartera_dia
    WHERE asesor_user_id = auth.uid()
      AND cliente_user_id = v_sp.user_id
      AND fecha = CURRENT_DATE;
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
    'desembolsado', false,
    'en_cartera_dia', p_decision IN ('aprobar', 'aprobar_monto_reducido')
  );
END;
$$;

-- ── Ruta del día: incluye créditos aprobados pendientes de visita ──
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
      'saldo_cuenta', COALESCE(cta.saldo_total, 0),
      'tipo_gestion', CASE
        WHEN sp.estado = 'aprobado' THEN 'CREDITO_APROBADO'
        WHEN sp.id IS NOT NULL THEN 'NUEVA_SOLICITUD'
        WHEN COALESCE(cp.dias_mora, 0) > 30 THEN 'RECUPERACION_MORA'
        WHEN COALESCE(cp.dias_mora, 0) > 0 THEN 'SEGUIMIENTO'
        ELSE 'RENOVACION'
      END,
      'solicitud_id', sp.id,
      'numero_expediente', sp.numero_expediente,
      'solicitud_monto', sp.monto,
      'solicitud_plazo', sp.plazo_meses,
      'solicitud_cuota', sp.cuota_mensual,
      'solicitud_estado', sp.estado,
      'solicitud_producto', sp.tipo_producto,
      'prioridad', CASE
        WHEN sp.estado = 'aprobado' THEN 170
        WHEN sp.id IS NOT NULL THEN 150
        WHEN COALESCE(cp.dias_mora, 0) > 30 THEN 100
        WHEN COALESCE(cp.dias_mora, 0) > 0  THEN 80
        WHEN cp.estado_pago IS DISTINCT FROM 'al_dia' THEN 60
        ELSE 40
      END,
      'estado_visita', 'pendiente'
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
      SELECT COALESCE(SUM(c.saldo), 0) AS saldo_total
      FROM public.cuentas c
      WHERE c.user_id = pc.user_id
    ) cta ON TRUE
    LEFT JOIN LATERAL (
      SELECT sp2.id, sp2.monto, sp2.plazo_meses, sp2.cuota_mensual,
             sp2.estado, sp2.numero_expediente, sp2.tipo_producto
      FROM public.solicitudes_prestamo sp2
      WHERE sp2.user_id = pc.user_id
        AND sp2.estado IN (
          'aprobado', 'enviado', 'pendiente', 'en_comite'
        )
      ORDER BY
        CASE sp2.estado
          WHEN 'aprobado' THEN 0
          WHEN 'en_comite' THEN 1
          WHEN 'pendiente' THEN 2
          WHEN 'enviado' THEN 3
          ELSE 9
        END,
        sp2.created_at DESC
      LIMIT 1
    ) sp ON TRUE
    WHERE public.asesor_atiende_cliente(pc.user_id)
      AND NOT EXISTS (
        SELECT 1
        FROM public.visitas_cartera_dia v
        WHERE v.asesor_user_id = auth.uid()
          AND v.cliente_user_id = pc.user_id
          AND v.fecha = CURRENT_DATE
      )
  ) sub;

  RETURN jsonb_build_object('ok', true, 'paradas', v_result);
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_responder_solicitud(UUID, TEXT, TEXT, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_responder_solicitud(UUID, TEXT, TEXT, NUMERIC) TO authenticated;

REVOKE ALL ON FUNCTION public.asesor_get_ruta_dia() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_get_ruta_dia() TO authenticated;

NOTIFY pgrst, 'reload schema';
