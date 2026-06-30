-- ============================================================
-- Fix: cliente_verificar_bloqueo / asesor_verificar_bloqueo
-- Error en app: "Revisa tu conexión" al login
-- Causa: STABLE + UPDATE → "UPDATE is not allowed in a non-volatile function"
-- Ejecutar en Supabase SQL Editor (un solo Run).
-- ============================================================

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

CREATE OR REPLACE FUNCTION public.asesor_verificar_bloqueo(p_codigo TEXT)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_codigo TEXT := upper(trim(p_codigo));
  v_a RECORD;
BEGIN
  SELECT intentos_fallidos, bloqueado_hasta
  INTO v_a
  FROM public.asesores_negocio
  WHERE upper(trim(codigo)) = v_codigo
    AND activo = TRUE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'bloqueado', false);
  END IF;

  IF v_a.bloqueado_hasta IS NOT NULL AND v_a.bloqueado_hasta > now() THEN
    RETURN jsonb_build_object(
      'ok', true,
      'bloqueado', true,
      'intentos_fallidos', v_a.intentos_fallidos,
      'hasta', v_a.bloqueado_hasta
    );
  END IF;

  IF v_a.bloqueado_hasta IS NOT NULL AND v_a.bloqueado_hasta <= now() THEN
    UPDATE public.asesores_negocio
    SET intentos_fallidos = 0, bloqueado_hasta = NULL
    WHERE upper(trim(codigo)) = v_codigo;
    v_a.intentos_fallidos := 0;
    v_a.bloqueado_hasta := NULL;
  END IF;

  IF v_a.intentos_fallidos < 5 THEN
    UPDATE public.asesores_negocio
    SET bloqueado_hasta = NULL
    WHERE upper(trim(codigo)) = v_codigo
      AND bloqueado_hasta IS NOT NULL;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'bloqueado', false,
    'intentos_fallidos', v_a.intentos_fallidos
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cliente_verificar_bloqueo(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_verificar_bloqueo(TEXT) TO anon, authenticated;

REVOKE ALL ON FUNCTION public.asesor_verificar_bloqueo(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_verificar_bloqueo(TEXT) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
