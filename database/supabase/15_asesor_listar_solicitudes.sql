-- ============================================================
-- FVentas: listar solicitudes del asesor (evita RLS vacío en app)
-- Ejecutar si "Estado de solicitudes" aparece vacío pero hay datos en BD.
-- ============================================================

ALTER TABLE public.solicitudes_prestamo
  ADD COLUMN IF NOT EXISTS tipo_producto TEXT DEFAULT 'prospera';

ALTER TABLE public.solicitudes_prestamo
  ADD COLUMN IF NOT EXISTS asesor_codigo TEXT;

-- RLS extra: el asesor ve lo que registró con su código
DROP POLICY IF EXISTS "Asesor ve solicitudes que registro" ON public.solicitudes_prestamo;
CREATE POLICY "Asesor ve solicitudes que registro"
  ON public.solicitudes_prestamo FOR SELECT
  USING (
    asesor_codigo IS NOT NULL
    AND asesor_codigo = public.current_asesor_codigo()
  );

CREATE OR REPLACE FUNCTION public.asesor_listar_solicitudes(p_estado TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_codigo TEXT;
  v_items  JSONB;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  v_codigo := public.current_asesor_codigo();

  SELECT COALESCE(
    jsonb_agg(row_data ORDER BY (row_data->>'created_at') DESC),
    '[]'::JSONB
  )
  INTO v_items
  FROM (
    SELECT jsonb_build_object(
      'id', sp.id,
      'user_id', sp.user_id,
      'monto', sp.monto,
      'plazo_meses', sp.plazo_meses,
      'cuota_mensual', sp.cuota_mensual,
      'proposito', sp.proposito,
      'estado', sp.estado,
      'tipo_producto', sp.tipo_producto,
      'asesor_codigo', sp.asesor_codigo,
      'created_at', sp.created_at,
      'cliente_nombre', NULLIF(TRIM(pc.nombres || ' ' || pc.apellidos), ''),
      'cliente_dni', pc.dni
    ) AS row_data
    FROM public.solicitudes_prestamo sp
    LEFT JOIN public.perfiles_clientes pc ON pc.user_id = sp.user_id
    WHERE (
      (v_codigo IS NOT NULL AND sp.asesor_codigo = v_codigo)
      OR public.asesor_atiende_cliente(sp.user_id)
    )
    AND (
      p_estado IS NULL
      OR TRIM(p_estado) = ''
      OR LOWER(TRIM(p_estado)) = 'todas'
      OR sp.estado = TRIM(p_estado)
    )
  ) sub;

  RETURN jsonb_build_object('ok', true, 'solicitudes', v_items);
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_listar_solicitudes(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_listar_solicitudes(TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
