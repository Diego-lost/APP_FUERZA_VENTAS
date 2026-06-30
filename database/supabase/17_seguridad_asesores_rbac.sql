-- ============================================================
-- Criterio 4: bloqueo login asesores + RPC matriz RBAC
-- Ejecutar después de 10 y 13.
-- ============================================================

ALTER TABLE public.asesores_negocio
  ADD COLUMN IF NOT EXISTS intentos_fallidos INT NOT NULL DEFAULT 0;

ALTER TABLE public.asesores_negocio
  ADD COLUMN IF NOT EXISTS bloqueado_hasta TIMESTAMPTZ;

-- ── Bloqueo asesor (5 intentos → 30 min) ─────────────────────
CREATE OR REPLACE FUNCTION public.asesor_verificar_bloqueo(p_codigo TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_a RECORD;
BEGIN
  SELECT intentos_fallidos, bloqueado_hasta
  INTO v_a
  FROM public.asesores_negocio
  WHERE upper(trim(codigo)) = upper(trim(p_codigo))
    AND activo = TRUE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'bloqueado', false);
  END IF;

  IF v_a.bloqueado_hasta IS NOT NULL AND v_a.bloqueado_hasta > now() THEN
    RETURN jsonb_build_object(
      'ok', true,
      'bloqueado', true,
      'hasta', v_a.bloqueado_hasta
    );
  END IF;

  RETURN jsonb_build_object('ok', true, 'bloqueado', false);
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_verificar_bloqueo(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_verificar_bloqueo(TEXT) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.asesor_registrar_intento_fallido(p_codigo TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.asesores_negocio
  SET intentos_fallidos = intentos_fallidos + 1,
      bloqueado_hasta = CASE
        WHEN intentos_fallidos + 1 >= 5 THEN now() + INTERVAL '30 minutes'
        ELSE bloqueado_hasta
      END
  WHERE upper(trim(codigo)) = upper(trim(p_codigo))
    AND activo = TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_registrar_intento_fallido(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_registrar_intento_fallido(TEXT) TO anon, authenticated;

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

REVOKE ALL ON FUNCTION public.asesor_reset_intentos(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_reset_intentos(TEXT) TO authenticated;

-- ── Perfil RBAC del asesor autenticado (matriz de permisos) ───
CREATE OR REPLACE FUNCTION public.asesor_obtener_perfil_rbac()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_an RECORD;
  v_supervisor BOOLEAN;
  v_admin BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth', 'codigo_http', 401);
  END IF;

  SELECT codigo, perfil, nombres, apellidos, nivel
  INTO v_an
  FROM public.asesores_negocio
  WHERE user_id = auth.uid() AND activo = TRUE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'asesor_no_encontrado', 'codigo_http', 403);
  END IF;

  v_supervisor := v_an.perfil IN ('supervisor', 'administrador');
  v_admin := v_an.perfil = 'administrador';

  RETURN jsonb_build_object(
    'ok', true,
    'codigo', v_an.codigo,
    'perfil', v_an.perfil,
    'nivel', v_an.nivel,
    'nombres', v_an.nombres,
    'apellidos', v_an.apellidos,
    'permisos', jsonb_build_object(
      'cartera_clientes', true,
      'originar_credito', true,
      'consulta_buro', true,
      'transmision_expediente', true,
      'reportes_productividad', v_supervisor,
      'administracion', v_admin
    ),
    'matriz', jsonb_build_array(
      jsonb_build_object('rol', 'operador', 'reportes', false, 'admin', false),
      jsonb_build_object('rol', 'super_operador', 'reportes', false, 'admin', false),
      jsonb_build_object('rol', 'supervisor', 'reportes', true, 'admin', false),
      jsonb_build_object('rol', 'administrador', 'reportes', true, 'admin', true),
      jsonb_build_object('rol', 'cliente', 'reportes', false, 'admin', false,
        'nota', 'App clientes: solo datos propios vía RLS')
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_obtener_perfil_rbac() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_obtener_perfil_rbac() TO authenticated;

NOTIFY pgrst, 'reload schema';
