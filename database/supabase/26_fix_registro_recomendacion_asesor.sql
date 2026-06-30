-- ============================================================
-- Fix registro app: recomendacion_asesor solo admite valores del CHECK
-- ('aprobar','aprobar_monto_reducido','elevar_comite','rechazar')
-- La nota de registro va en obs_finales.
-- Ejecutar si el registro falla con fichas_campo_recomendacion_asesor_check
-- ============================================================

CREATE OR REPLACE FUNCTION public.cliente_registrarse(
  p_dni                 TEXT,
  p_nombres             TEXT,
  p_apellidos           TEXT,
  p_password            TEXT,
  p_telefono            TEXT DEFAULT NULL,
  p_nombre_negocio      TEXT DEFAULT NULL,
  p_tipo_negocio        TEXT DEFAULT 'Bodega',
  p_distrito            TEXT DEFAULT NULL,
  p_direccion_negocio   TEXT DEFAULT NULL,
  p_antiguedad_meses    INT DEFAULT NULL,
  p_ingresos_mensuales  NUMERIC DEFAULT NULL,
  p_gastos_mensuales    NUMERIC DEFAULT NULL,
  p_asesor_codigo       TEXT DEFAULT 'AG-001-01'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_dni           TEXT;
  v_uid           UUID := gen_random_uuid();
  v_email         TEXT;
  v_asesor_nombre TEXT;
  v_agencia       TEXT;
  v_score_id      UUID := gen_random_uuid();
  v_ficha_id      UUID := gen_random_uuid();
  v_cuenta_id     UUID := gen_random_uuid();
BEGIN
  v_dni := public.cliente_normalizar_dni(p_dni);

  IF v_dni IS NULL OR length(v_dni) <> 8 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'dni_invalido');
  END IF;

  IF p_password IS NULL OR length(trim(p_password)) < 4 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'password_corta');
  END IF;

  IF trim(COALESCE(p_nombres, '')) = '' OR trim(COALESCE(p_apellidos, '')) = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'nombre_requerido');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.perfiles_clientes
    WHERE public.cliente_normalizar_dni(dni) = v_dni
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'dni_ya_registrado');
  END IF;

  SELECT an.nombres || ' ' || an.apellidos, ag.nombre
  INTO v_asesor_nombre, v_agencia
  FROM public.asesores_negocio an
  JOIN public.agencias ag ON ag.id = an.id_agencia
  WHERE an.codigo = upper(trim(p_asesor_codigo))
    AND an.activo = TRUE;

  IF v_asesor_nombre IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'asesor_no_encontrado');
  END IF;

  v_email := lower(regexp_replace(trim(p_nombres), '[^a-zA-ZáéíóúÁÉÍÓÚñÑ]', '', 'g'))
    || '.'
    || lower(split_part(trim(p_apellidos), ' ', 1))
    || v_dni
    || '@cliente.pe';

  PERFORM public.seed_auth_user_password(v_uid, v_email, trim(p_password));

  INSERT INTO public.auth_mock (id, email)
  VALUES (v_uid, v_email)
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;

  INSERT INTO public.perfiles_clientes (
    user_id, dni, nombres, apellidos,
    fecha_nacimiento, telefono,
    distrito, provincia, departamento,
    nombre_negocio, tipo_negocio, direccion_negocio,
    lat_negocio, lng_negocio,
    antiguedad_negocio_meses, tenencia_local,
    num_entidades_sbs, calificacion_sbs, deuda_total_sbs,
    estado_cliente
  ) VALUES (
    v_uid, v_dni, trim(p_nombres), trim(p_apellidos),
    '1990-01-01', NULLIF(trim(p_telefono), ''),
    NULLIF(trim(p_distrito), ''), 'Huancayo', 'Junín',
    NULLIF(trim(p_nombre_negocio), ''), NULLIF(trim(p_tipo_negocio), 'Bodega'),
    NULLIF(trim(p_direccion_negocio), ''),
    -12.0581, -75.2027,
    COALESCE(p_antiguedad_meses, 12), 'propio',
    CASE WHEN (RIGHT(v_dni, 1)::INT % 2) = 0 THEN 1 ELSE 0 END,
    'Normal',
    CASE WHEN (RIGHT(v_dni, 1)::INT % 2) = 0 THEN 4500 ELSE 0 END,
    'activo'
  );

  INSERT INTO public.cuentas (id, user_id, tipo, numero_cuenta, saldo, moneda)
  VALUES (
    v_cuenta_id, v_uid, 'ahorro',
    '019-' || RIGHT(v_dni, 7),
    GREATEST(0, COALESCE(p_ingresos_mensuales, 1500) - COALESCE(p_gastos_mensuales, 600)),
    'PEN'
  );

  INSERT INTO public.scores_transaccionales (
    id, user_id,
    pts_saldo, pts_regularidad, pts_disciplina, pts_vinculo, pts_riesgo,
    monto_hipotesis, ingreso_promedio_ref
  ) VALUES (
    v_score_id, v_uid,
    30, 20, 15, 10, 10,
    1000, COALESCE(p_ingresos_mensuales, 2000)
  );

  INSERT INTO public.fichas_campo (
    id, user_id, score_id,
    asesor_nombre, agencia, fecha_visita,
    negocio_verificado,
    antiguedad_negocio, tenencia_local,
    ventas_mensuales_est, gastos_fijos_mes,
    score_transaccional_ref,
    recomendacion_asesor, obs_finales, estado_ficha
  ) VALUES (
    v_ficha_id, v_uid, v_score_id,
    v_asesor_nombre, v_agencia, CURRENT_DATE,
    FALSE,
    CASE WHEN COALESCE(p_antiguedad_meses, 0) >= 36 THEN 'mas_3_anios'
         WHEN COALESCE(p_antiguedad_meses, 0) >= 12 THEN '1_a_3_anios'
         ELSE 'menos_1_anio' END,
    'propio',
    COALESCE(p_ingresos_mensuales, 2000),
    COALESCE(p_gastos_mensuales, 900),
    85,
    NULL,
    'Cliente registrado desde app — pendiente visita de campo.',
    'en_proceso'
  );

  RETURN jsonb_build_object(
    'ok', true,
    'user_id', v_uid,
    'email', v_email,
    'dni', v_dni,
    'asesor_codigo', upper(trim(p_asesor_codigo))
  );
END;
$$;

NOTIFY pgrst, 'reload schema';
