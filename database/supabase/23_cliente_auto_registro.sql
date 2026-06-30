-- ============================================================
-- Registro de cliente nuevo desde la App (tú ingresas los datos)
-- Ejecutar después de 21_cliente_solicitud_fventas.sql
-- No requiere 22_seed_caso1_anaximandro.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.cliente_normalizar_dni(p_dni TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT LPAD(
    NULLIF(regexp_replace(trim(COALESCE(p_dni, '')), '[^0-9]', '', 'g'), ''),
    8,
    '0'
  );
$$;

CREATE OR REPLACE FUNCTION public.seed_auth_user_password(
  p_id UUID,
  p_email TEXT,
  p_password TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_instance_id UUID;
BEGIN
  SELECT id INTO v_instance_id FROM auth.instances LIMIT 1;
  IF v_instance_id IS NULL THEN
    v_instance_id := '00000000-0000-0000-0000-000000000000'::UUID;
  END IF;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    is_super_admin, confirmation_token, recovery_token,
    email_change_token_new, email_change
  ) VALUES (
    v_instance_id, p_id, 'authenticated', 'authenticated', p_email,
    extensions.crypt(p_password, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"registro_app":true}'::jsonb,
    now(), now(),
    false, '', '', '', ''
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    encrypted_password = EXCLUDED.encrypted_password,
    email_confirmed_at = COALESCE(auth.users.email_confirmed_at, EXCLUDED.email_confirmed_at),
    updated_at = now();

  DELETE FROM auth.identities
  WHERE user_id = p_id AND provider = 'email';

  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) VALUES (
    p_id, p_id,
    jsonb_build_object(
      'sub', p_id::text, 'email', p_email,
      'email_verified', true, 'phone_verified', false
    ),
    'email', p_id::text, now(), now(), now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.seed_auth_user_password(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.seed_auth_user_password(UUID, TEXT, TEXT) TO anon, authenticated;

-- ── Alta de cliente (formulario app) ──────────────────────────
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

REVOKE ALL ON FUNCTION public.cliente_registrarse(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT, NUMERIC, NUMERIC, TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_registrarse(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT, NUMERIC, NUMERIC, TEXT
) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
