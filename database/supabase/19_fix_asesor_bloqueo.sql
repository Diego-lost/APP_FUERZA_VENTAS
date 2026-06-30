-- ============================================================
-- Bloqueo login asesores: 5 intentos, 10 segundos (igual que clientes)
-- Ejecutar después de 17_seguridad_asesores_rbac.sql
-- ============================================================

ALTER TABLE public.asesores_negocio
  ADD COLUMN IF NOT EXISTS intentos_fallidos INT NOT NULL DEFAULT 0;

ALTER TABLE public.asesores_negocio
  ADD COLUMN IF NOT EXISTS bloqueado_hasta TIMESTAMPTZ;

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

DROP FUNCTION IF EXISTS public.asesor_registrar_intento_fallido(TEXT);

CREATE OR REPLACE FUNCTION public.asesor_registrar_intento_fallido(p_codigo TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_codigo TEXT := upper(trim(p_codigo));
  v_intentos INT;
  v_hasta TIMESTAMPTZ;
  v_max CONSTANT INT := 5;
BEGIN
  UPDATE public.asesores_negocio
  SET intentos_fallidos = intentos_fallidos + 1,
      bloqueado_hasta = CASE
        WHEN intentos_fallidos + 1 >= v_max THEN now() + INTERVAL '10 seconds'
        ELSE NULL
      END
  WHERE upper(trim(codigo)) = v_codigo
    AND activo = TRUE
  RETURNING intentos_fallidos, bloqueado_hasta
  INTO v_intentos, v_hasta;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'asesor_no_encontrado');
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

CREATE OR REPLACE FUNCTION public.asesor_reset_intentos(p_codigo TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.asesores_negocio
  SET intentos_fallidos = 0,
      bloqueado_hasta = NULL
  WHERE upper(trim(codigo)) = upper(trim(p_codigo))
    AND activo = TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_verificar_bloqueo(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_verificar_bloqueo(TEXT) TO anon, authenticated;

REVOKE ALL ON FUNCTION public.asesor_registrar_intento_fallido(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_registrar_intento_fallido(TEXT) TO anon, authenticated;

REVOKE ALL ON FUNCTION public.asesor_reset_intentos(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_reset_intentos(TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';

UPDATE public.asesores_negocio
SET intentos_fallidos = 0, bloqueado_hasta = NULL
WHERE bloqueado_hasta IS NOT NULL OR intentos_fallidos > 0;
