-- ============================================================
-- Corrige login de clientes seed ya insertados
-- Ejecutar si signInWithPassword falla con "Invalid login credentials"
-- Contraseña después del fix: Cliente2026!
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1) Re-hashear contraseñas (formato que GoTrue / Supabase acepta)
UPDATE auth.users u
SET
  encrypted_password = extensions.crypt('Cliente2026!', extensions.gen_salt('bf')),
  email_confirmed_at = COALESCE(u.email_confirmed_at, now()),
  updated_at = now()
WHERE EXISTS (
  SELECT 1 FROM public.auth_mock am WHERE am.id = u.id
);

-- 2) Recrear identities (provider_id debe ser el UUID, no el email)
DELETE FROM auth.identities i
USING public.auth_mock am
WHERE i.user_id = am.id AND i.provider = 'email';

INSERT INTO auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  last_sign_in_at,
  created_at,
  updated_at
)
SELECT
  u.id,
  u.id,
  jsonb_build_object(
    'sub', u.id::text,
    'email', u.email,
    'email_verified', true,
    'phone_verified', false
  ),
  'email',
  u.id::text,
  now(),
  now(),
  now()
FROM auth.users u
JOIN public.auth_mock am ON am.id = u.id;

-- Verificación rápida (debe devolver 1 fila por cliente seed):
-- SELECT u.email, i.provider_id = u.id::text AS identity_ok
-- FROM auth.users u
-- JOIN public.auth_mock am ON am.id = u.id
-- JOIN auth.identities i ON i.user_id = u.id AND i.provider = 'email'
-- LIMIT 5;
