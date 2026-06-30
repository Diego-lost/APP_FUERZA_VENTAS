-- Login por DNI: devuelve el email del cliente (para signInWithPassword)
-- Ejecutar en Supabase SQL Editor después de los seeds.

CREATE OR REPLACE FUNCTION public.get_client_email_by_dni(p_dni text)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT am.email
  FROM public.perfiles_clientes pc
  JOIN public.auth_mock am ON am.id = pc.user_id
  WHERE pc.dni = trim(p_dni)
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_client_email_by_dni(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_client_email_by_dni(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_client_email_by_dni(text) TO authenticated;
