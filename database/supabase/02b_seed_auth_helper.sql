-- ============================================================
-- Helper: crear usuarios en auth.users para el seed piloto
-- Ejecutar ANTES de 04_seed_scoring_1800.sql
-- Contraseña de prueba para todos los clientes seed: Cliente2026!
-- ============================================================

CREATE TABLE IF NOT EXISTS public.auth_mock (
  id         UUID PRIMARY KEY,
  email      TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.seed_auth_user(p_id UUID, p_email TEXT)
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
    crypt('Cliente2026!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"seed":true}'::jsonb,
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
    updated_at = now();

  BEGIN
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
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;
END;
$$;

REVOKE ALL ON FUNCTION public.seed_auth_user(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.seed_auth_user(UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.seed_auth_user(UUID, TEXT) TO postgres;
