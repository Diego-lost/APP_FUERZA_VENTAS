-- ============================================================
-- Fix bloqueo login clientes (5 intentos) + DNI normalizado
-- Ejecutar si el bloqueo no funciona o faltan columnas del 13.
-- ============================================================

ALTER TABLE public.perfiles_clientes
  ADD COLUMN IF NOT EXISTS intentos_fallidos INT NOT NULL DEFAULT 0;

ALTER TABLE public.perfiles_clientes
  ADD COLUMN IF NOT EXISTS bloqueado_hasta TIMESTAMPTZ;

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

CREATE OR REPLACE FUNCTION public.get_client_email_by_dni(p_dni TEXT)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT am.email
  FROM public.perfiles_clientes pc
  JOIN public.auth_mock am ON am.id = pc.user_id
  WHERE public.cliente_normalizar_dni(pc.dni) = public.cliente_normalizar_dni(p_dni)
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.cliente_verificar_bloqueo(p_dni TEXT)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_dni TEXT := public.cliente_normalizar_dni(p_dni);
  v_pc RECORD;
BEGIN
  IF v_dni IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'bloqueado', false);
  END IF;

  SELECT intentos_fallidos, bloqueado_hasta
  INTO v_pc
  FROM public.perfiles_clientes
  WHERE public.cliente_normalizar_dni(dni) = v_dni;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'bloqueado', false);
  END IF;

  IF v_pc.bloqueado_hasta IS NOT NULL AND v_pc.bloqueado_hasta > now() THEN
    RETURN jsonb_build_object(
      'ok', true,
      'bloqueado', true,
      'intentos_fallidos', v_pc.intentos_fallidos,
      'hasta', v_pc.bloqueado_hasta
    );
  END IF;

  -- Bloqueo expirado o intentos incompletos: limpiar bloqueo previo
  IF v_pc.bloqueado_hasta IS NOT NULL AND v_pc.bloqueado_hasta <= now() THEN
    UPDATE public.perfiles_clientes
    SET intentos_fallidos = 0, bloqueado_hasta = NULL
    WHERE public.cliente_normalizar_dni(dni) = v_dni;
    v_pc.intentos_fallidos := 0;
    v_pc.bloqueado_hasta := NULL;
  END IF;

  IF v_pc.intentos_fallidos < 5 THEN
    UPDATE public.perfiles_clientes
    SET bloqueado_hasta = NULL
    WHERE public.cliente_normalizar_dni(dni) = v_dni
      AND bloqueado_hasta IS NOT NULL;
    v_pc.bloqueado_hasta := NULL;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'bloqueado', false,
    'intentos_fallidos', v_pc.intentos_fallidos
  );
END;
$$;

-- Cambió de VOID (script 13) a JSONB: hay que eliminar antes
DROP FUNCTION IF EXISTS public.cliente_registrar_intento_fallido(TEXT);

CREATE OR REPLACE FUNCTION public.cliente_registrar_intento_fallido(p_dni TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_dni TEXT := public.cliente_normalizar_dni(p_dni);
  v_intentos INT;
  v_hasta TIMESTAMPTZ;
  v_max CONSTANT INT := 5;
BEGIN
  IF v_dni IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'dni_invalido');
  END IF;

  UPDATE public.perfiles_clientes
  SET intentos_fallidos = intentos_fallidos + 1,
      bloqueado_hasta = CASE
        WHEN intentos_fallidos + 1 >= v_max THEN now() + INTERVAL '10 seconds'
        ELSE NULL
      END
  WHERE public.cliente_normalizar_dni(dni) = v_dni
  RETURNING intentos_fallidos, bloqueado_hasta
  INTO v_intentos, v_hasta;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cliente_no_encontrado');
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'intentos_fallidos', v_intentos,
    'bloqueado', v_intentos >= v_max AND v_hasta IS NOT NULL AND v_hasta > now(),
    'intentos_restantes', GREATEST(0, v_max - v_intentos),
    'hasta', v_hasta
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cliente_reset_intentos(p_dni TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_dni TEXT := public.cliente_normalizar_dni(p_dni);
BEGIN
  UPDATE public.perfiles_clientes
  SET intentos_fallidos = 0, bloqueado_hasta = NULL
  WHERE public.cliente_normalizar_dni(dni) = v_dni;
END;
$$;

REVOKE ALL ON FUNCTION public.cliente_normalizar_dni(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_normalizar_dni(TEXT) TO anon, authenticated;

REVOKE ALL ON FUNCTION public.get_client_email_by_dni(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_client_email_by_dni(TEXT) TO anon, authenticated;

REVOKE ALL ON FUNCTION public.cliente_verificar_bloqueo(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_verificar_bloqueo(TEXT) TO anon, authenticated;

REVOKE ALL ON FUNCTION public.cliente_registrar_intento_fallido(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_registrar_intento_fallido(TEXT) TO anon, authenticated;

REVOKE ALL ON FUNCTION public.cliente_reset_intentos(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_reset_intentos(TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- Limpiar bloqueos viejos (30 min) de pruebas anteriores
UPDATE public.perfiles_clientes
SET intentos_fallidos = 0, bloqueado_hasta = NULL
WHERE bloqueado_hasta IS NOT NULL OR intentos_fallidos > 0;
