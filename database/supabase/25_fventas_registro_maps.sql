-- ============================================================
-- FVentas: registro de clientes/asesores + coordenadas GPS
-- Ejecutar después de 24_fix_registro_estado_ficha.sql
-- ============================================================

-- ── Registrar cliente nuevo (asesor autenticado) ─────────────
CREATE OR REPLACE FUNCTION public.asesor_registrar_cliente(
  p_dni                 TEXT,
  p_nombres             TEXT,
  p_apellidos           TEXT,
  p_telefono            TEXT DEFAULT NULL,
  p_nombre_negocio      TEXT DEFAULT NULL,
  p_tipo_negocio        TEXT DEFAULT 'Bodega',
  p_distrito            TEXT DEFAULT NULL,
  p_direccion_negocio   TEXT DEFAULT NULL,
  p_lat_negocio         NUMERIC DEFAULT NULL,
  p_lng_negocio         NUMERIC DEFAULT NULL,
  p_antiguedad_meses    INT DEFAULT NULL,
  p_ingresos_mensuales  NUMERIC DEFAULT NULL,
  p_gastos_mensuales    NUMERIC DEFAULT NULL,
  p_password            TEXT DEFAULT 'Cliente2026!'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_codigo TEXT;
  v_result JSONB;
  v_uid    UUID;
BEGIN
  v_codigo := public.current_asesor_codigo();
  IF v_codigo IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'asesor_no_autenticado');
  END IF;

  v_result := public.cliente_registrarse(
    p_dni,
    p_nombres,
    p_apellidos,
    COALESCE(NULLIF(trim(p_password), ''), 'Cliente2026!'),
    p_telefono,
    p_nombre_negocio,
    p_tipo_negocio,
    p_distrito,
    p_direccion_negocio,
    p_antiguedad_meses,
    p_ingresos_mensuales,
    p_gastos_mensuales,
    v_codigo
  );

  IF (v_result->>'ok')::boolean IS NOT TRUE THEN
    RETURN v_result;
  END IF;

  v_uid := (v_result->>'user_id')::uuid;

  IF p_lat_negocio IS NOT NULL AND p_lng_negocio IS NOT NULL THEN
    UPDATE public.perfiles_clientes
    SET lat_negocio = p_lat_negocio,
        lng_negocio = p_lng_negocio
    WHERE user_id = v_uid;
  END IF;

  RETURN v_result || jsonb_build_object(
    'lat', COALESCE(p_lat_negocio, -12.0581),
    'lng', COALESCE(p_lng_negocio, -75.2027)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_registrar_cliente(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, INT, NUMERIC, NUMERIC, TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_registrar_cliente(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, INT, NUMERIC, NUMERIC, TEXT
) TO authenticated;

-- ── Actualizar dirección y coordenadas del cliente ───────────
CREATE OR REPLACE FUNCTION public.asesor_actualizar_direccion_cliente(
  p_user_id           UUID,
  p_direccion_negocio TEXT,
  p_distrito          TEXT DEFAULT NULL,
  p_lat_negocio       NUMERIC DEFAULT NULL,
  p_lng_negocio       NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.asesor_atiende_cliente(p_user_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cliente_no_cartera');
  END IF;

  UPDATE public.perfiles_clientes
  SET direccion_negocio = NULLIF(trim(p_direccion_negocio), ''),
      distrito = COALESCE(NULLIF(trim(p_distrito), ''), distrito),
      lat_negocio = COALESCE(p_lat_negocio, lat_negocio),
      lng_negocio = COALESCE(p_lng_negocio, lng_negocio)
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_actualizar_direccion_cliente(UUID, TEXT, TEXT, NUMERIC, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_actualizar_direccion_cliente(UUID, TEXT, TEXT, NUMERIC, NUMERIC) TO authenticated;

-- ── Listar agencias (solo administrador) ─────────────────────
CREATE OR REPLACE FUNCTION public.admin_listar_agencias()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil TEXT;
BEGIN
  SELECT perfil INTO v_perfil
  FROM public.asesores_negocio
  WHERE user_id = auth.uid() AND activo = TRUE;

  IF v_perfil IS DISTINCT FROM 'administrador' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'sin_permiso');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'agencias', (
      SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', a.id,
          'codigo', a.codigo,
          'nombre', a.nombre,
          'distrito', a.distrito
        ) ORDER BY a.codigo
      ), '[]'::jsonb)
      FROM public.agencias a
      WHERE a.activa = TRUE
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_listar_agencias() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_listar_agencias() TO authenticated;

-- ── Crear asesor nuevo (solo administrador) ──────────────────
CREATE OR REPLACE FUNCTION public.admin_crear_asesor(
  p_codigo        TEXT,
  p_nombres       TEXT,
  p_apellidos     TEXT,
  p_email         TEXT,
  p_id_agencia    INT,
  p_nivel         TEXT DEFAULT 'Junior I',
  p_perfil        TEXT DEFAULT 'operador',
  p_password      TEXT DEFAULT 'Asesor2026!',
  p_telefono      TEXT DEFAULT NULL,
  p_dni           TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_perfil_admin TEXT;
  v_uid          UUID := gen_random_uuid();
  v_cartera      INT;
  v_meta_creditos INT;
  v_meta_monto   NUMERIC;
BEGIN
  SELECT perfil INTO v_perfil_admin
  FROM public.asesores_negocio
  WHERE user_id = auth.uid() AND activo = TRUE;

  IF v_perfil_admin IS DISTINCT FROM 'administrador' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'sin_permiso');
  END IF;

  IF trim(COALESCE(p_codigo, '')) = '' OR trim(COALESCE(p_nombres, '')) = ''
     OR trim(COALESCE(p_apellidos, '')) = '' OR trim(COALESCE(p_email, '')) = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'campos_requeridos');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.asesores_negocio
    WHERE upper(trim(codigo)) = upper(trim(p_codigo))
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'codigo_ya_existe');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.agencias WHERE id = p_id_agencia AND activa = TRUE) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'agencia_no_encontrada');
  END IF;

  v_cartera := CASE p_nivel
    WHEN 'Senior II' THEN 400
    WHEN 'Senior I'  THEN 300
    WHEN 'Junior II' THEN 180
    ELSE 90
  END;
  v_meta_creditos := CASE p_nivel
    WHEN 'Senior II' THEN 25
    WHEN 'Senior I'  THEN 18
    WHEN 'Junior II' THEN 12
    ELSE 8
  END;
  v_meta_monto := v_meta_creditos * 2500;

  PERFORM public.seed_auth_user_password(v_uid, lower(trim(p_email)), trim(p_password));

  INSERT INTO public.auth_mock (id, email)
  VALUES (v_uid, lower(trim(p_email)))
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;

  INSERT INTO public.asesores_negocio (
    codigo, id_agencia, nombres, apellidos, dni, email, telefono,
    nivel, cartera_clientes_promedio, meta_creditos_mes, meta_monto_mes,
    perfil, activo, user_id
  ) VALUES (
    upper(trim(p_codigo)),
    p_id_agencia,
    trim(p_nombres),
    trim(p_apellidos),
    NULLIF(trim(p_dni), ''),
    lower(trim(p_email)),
    NULLIF(trim(p_telefono), ''),
    p_nivel,
    v_cartera,
    v_meta_creditos,
    v_meta_monto,
    p_perfil,
    TRUE,
    v_uid
  );

  RETURN jsonb_build_object(
    'ok', true,
    'codigo', upper(trim(p_codigo)),
    'email', lower(trim(p_email)),
    'user_id', v_uid
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_crear_asesor(
  TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_crear_asesor(
  TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, TEXT
) TO authenticated;

NOTIFY pgrst, 'reload schema';
