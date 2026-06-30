-- ============================================================
-- App Fuerza de Ventas: auth de asesores + RLS de cartera
-- Ejecutar DESPUÉS de 03_seed_agencias_asesores.sql y 04_seed_scoring_1800.sql
-- Contraseña de prueba para todos los asesores seed: Asesor2026!
-- Login en la app: código de asesor (ej. AG-001-01) + contraseña
-- ============================================================

-- Vincular asesores con auth.users
ALTER TABLE public.asesores_negocio
  ADD COLUMN IF NOT EXISTS user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_asesores_negocio_user_id
  ON public.asesores_negocio(user_id);

-- Crear usuario auth para asesores (contraseña distinta a clientes)
CREATE OR REPLACE FUNCTION public.seed_auth_asesor(p_id UUID, p_email TEXT)
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
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    is_super_admin,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change
  ) VALUES (
    v_instance_id,
    p_id,
    'authenticated',
    'authenticated',
    p_email,
    crypt('Asesor2026!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"seed":true,"role":"asesor"}'::jsonb,
    now(),
    now(),
    false,
    '',
    '',
    '',
    ''
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    encrypted_password = EXCLUDED.encrypted_password,
    email_confirmed_at = COALESCE(auth.users.email_confirmed_at, EXCLUDED.email_confirmed_at),
    updated_at = now();

  DELETE FROM auth.identities
  WHERE user_id = p_id AND provider = 'email';

  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    p_id,
    jsonb_build_object(
      'sub', p_id::text,
      'email', p_email,
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    p_email,
    now(),
    now(),
    now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.seed_auth_asesor(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.seed_auth_asesor(UUID, TEXT) TO postgres;
GRANT EXECUTE ON FUNCTION public.seed_auth_asesor(UUID, TEXT) TO service_role;

-- Crear auth para asesores que aún no tienen user_id
DO $$
DECLARE
  r RECORD;
  uid UUID;
BEGIN
  FOR r IN
    SELECT an.id, an.email
    FROM public.asesores_negocio an
    WHERE an.user_id IS NULL
      AND an.email IS NOT NULL
      AND an.activo = TRUE
  LOOP
    uid := gen_random_uuid();
    PERFORM public.seed_auth_asesor(uid, r.email);
    INSERT INTO public.auth_mock (id, email)
    VALUES (uid, r.email)
    ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
    UPDATE public.asesores_negocio
    SET user_id = uid
    WHERE id = r.id;
  END LOOP;
END $$;

-- Login por código de asesor (para signInWithPassword)
CREATE OR REPLACE FUNCTION public.get_asesor_email_by_codigo(p_codigo text)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT an.email
  FROM public.asesores_negocio an
  WHERE upper(trim(an.codigo)) = upper(trim(p_codigo))
    AND an.activo = TRUE
    AND an.email IS NOT NULL
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_asesor_email_by_codigo(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_asesor_email_by_codigo(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_asesor_email_by_codigo(text) TO authenticated;

-- Helper RLS: el asesor autenticado atiende a ese cliente
CREATE OR REPLACE FUNCTION public.asesor_atiende_cliente(p_client_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.fichas_campo fc
    JOIN public.asesores_negocio an
      ON fc.asesor_nombre = (an.nombres || ' ' || an.apellidos)
    WHERE fc.user_id = p_client_user_id
      AND an.user_id = auth.uid()
      AND an.activo = TRUE
  );
$$;

REVOKE ALL ON FUNCTION public.asesor_atiende_cliente(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_atiende_cliente(UUID) TO authenticated;

-- RLS: asesor ve su perfil
ALTER TABLE public.asesores_negocio ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Asesor ve su perfil" ON public.asesores_negocio;
CREATE POLICY "Asesor ve su perfil"
  ON public.asesores_negocio FOR SELECT
  USING (user_id = auth.uid());

-- RLS: asesor ve cartera de clientes
DROP POLICY IF EXISTS "Asesor ve perfiles de su cartera" ON public.perfiles_clientes;
CREATE POLICY "Asesor ve perfiles de su cartera"
  ON public.perfiles_clientes FOR SELECT
  USING (public.asesor_atiende_cliente(user_id));

DROP POLICY IF EXISTS "Asesor ve fichas de su cartera" ON public.fichas_campo;
CREATE POLICY "Asesor ve fichas de su cartera"
  ON public.fichas_campo FOR SELECT
  USING (public.asesor_atiende_cliente(user_id));

DROP POLICY IF EXISTS "Asesor ve creditos de su cartera" ON public.creditos_preaprobados;
CREATE POLICY "Asesor ve creditos de su cartera"
  ON public.creditos_preaprobados FOR SELECT
  USING (public.asesor_atiende_cliente(user_id));

DROP POLICY IF EXISTS "Asesor ve scores de su cartera" ON public.scores_transaccionales;
CREATE POLICY "Asesor ve scores de su cartera"
  ON public.scores_transaccionales FOR SELECT
  USING (public.asesor_atiende_cliente(user_id));

DROP POLICY IF EXISTS "Asesor ve cuentas de su cartera" ON public.cuentas;
CREATE POLICY "Asesor ve cuentas de su cartera"
  ON public.cuentas FOR SELECT
  USING (public.asesor_atiende_cliente(user_id));

DROP POLICY IF EXISTS "Asesor ve transacciones de su cartera" ON public.transacciones;
CREATE POLICY "Asesor ve transacciones de su cartera"
  ON public.transacciones FOR SELECT
  USING (public.asesor_atiende_cliente(user_id));

-- Resumen de cartera para el dashboard (opcional, vía RPC)
CREATE OR REPLACE FUNCTION public.get_resumen_cartera_asesor()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_asesor public.asesores_negocio%ROWTYPE;
  v_clientes INT;
  v_mora INT;
BEGIN
  SELECT * INTO v_asesor
  FROM public.asesores_negocio
  WHERE user_id = auth.uid() AND activo = TRUE
  LIMIT 1;

  IF v_asesor.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'asesor_no_encontrado');
  END IF;

  SELECT COUNT(DISTINCT pc.user_id) INTO v_clientes
  FROM public.perfiles_clientes pc
  WHERE public.asesor_atiende_cliente(pc.user_id);

  SELECT COUNT(DISTINCT cp.user_id) INTO v_mora
  FROM public.creditos_preaprobados cp
  WHERE public.asesor_atiende_cliente(cp.user_id)
    AND COALESCE(cp.dias_mora, 0) > 0;

  RETURN jsonb_build_object(
    'ok', true,
    'codigo', v_asesor.codigo,
    'nombres', v_asesor.nombres,
    'apellidos', v_asesor.apellidos,
    'nivel', v_asesor.nivel,
    'zona_asignada', v_asesor.zona_asignada,
    'total_clientes', v_clientes,
    'clientes_en_mora', v_mora
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_resumen_cartera_asesor() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_resumen_cartera_asesor() TO authenticated;
