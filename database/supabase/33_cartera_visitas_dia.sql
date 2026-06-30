-- Visitas de cartera del día + saldo cliente en ruta
-- Ejecutar después de 21_cliente_solicitud_fventas.sql

CREATE TABLE IF NOT EXISTS public.visitas_cartera_dia (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asesor_user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  cliente_user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fecha             DATE NOT NULL DEFAULT CURRENT_DATE,
  resultado         TEXT NOT NULL
                      CHECK (resultado IN (
                        'visitado', 'no_encontrado', 'reagendado', 'negocio_cerrado'
                      )),
  observacion       TEXT NOT NULL DEFAULT '',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (asesor_user_id, cliente_user_id, fecha)
);

CREATE INDEX IF NOT EXISTS idx_visitas_cartera_dia_fecha
  ON public.visitas_cartera_dia(asesor_user_id, fecha);

ALTER TABLE public.visitas_cartera_dia ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Asesor ve sus visitas del día" ON public.visitas_cartera_dia;
CREATE POLICY "Asesor ve sus visitas del día"
  ON public.visitas_cartera_dia FOR SELECT
  USING (asesor_user_id = auth.uid());

DROP POLICY IF EXISTS "Asesor registra visitas de su cartera" ON public.visitas_cartera_dia;
CREATE POLICY "Asesor registra visitas de su cartera"
  ON public.visitas_cartera_dia FOR INSERT
  WITH CHECK (
    asesor_user_id = auth.uid()
    AND public.asesor_atiende_cliente(cliente_user_id)
  );

-- Registrar visita y quitar cliente de la ruta del día
CREATE OR REPLACE FUNCTION public.asesor_registrar_visita_cartera(
  p_cliente_user_id UUID,
  p_resultado       TEXT,
  p_observacion     TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  IF NOT public.asesor_atiende_cliente(p_cliente_user_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cliente_no_cartera');
  END IF;

  IF p_resultado NOT IN ('visitado', 'no_encontrado', 'reagendado', 'negocio_cerrado') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'resultado_invalido');
  END IF;

  INSERT INTO public.visitas_cartera_dia (
    asesor_user_id, cliente_user_id, fecha, resultado, observacion
  ) VALUES (
    auth.uid(), p_cliente_user_id, CURRENT_DATE, p_resultado,
    COALESCE(p_observacion, '')
  )
  ON CONFLICT (asesor_user_id, cliente_user_id, fecha)
  DO UPDATE SET
    resultado = EXCLUDED.resultado,
    observacion = EXCLUDED.observacion,
    created_at = now();

  RETURN jsonb_build_object('ok', true, 'estado_visita', p_resultado);
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_registrar_visita_cartera(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_registrar_visita_cartera(UUID, TEXT, TEXT) TO authenticated;

-- Ruta del día: excluye visitados hoy + incluye saldo en cuenta
CREATE OR REPLACE FUNCTION public.asesor_get_ruta_dia()
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  SELECT COALESCE(jsonb_agg(row ORDER BY
    (row->>'prioridad')::INT DESC,
    row->>'distrito',
    row->>'apellidos'
  ), '[]'::JSONB)
  INTO v_result
  FROM (
    SELECT jsonb_build_object(
      'user_id', pc.user_id,
      'dni', pc.dni,
      'nombres', pc.nombres,
      'apellidos', pc.apellidos,
      'distrito', pc.distrito,
      'direccion_negocio', pc.direccion_negocio,
      'lat_negocio', pc.lat_negocio,
      'lng_negocio', pc.lng_negocio,
      'telefono', pc.telefono,
      'dias_mora', COALESCE(cp.dias_mora, 0),
      'estado_pago', cp.estado_pago,
      'saldo_cuenta', COALESCE(cta.saldo_total, 0),
      'tipo_gestion', CASE
        WHEN sp.id IS NOT NULL THEN 'NUEVA_SOLICITUD'
        WHEN COALESCE(cp.dias_mora, 0) > 30 THEN 'RECUPERACION_MORA'
        WHEN COALESCE(cp.dias_mora, 0) > 0 THEN 'SEGUIMIENTO'
        ELSE 'RENOVACION'
      END,
      'solicitud_id', sp.id,
      'numero_expediente', sp.numero_expediente,
      'solicitud_monto', sp.monto,
      'solicitud_plazo', sp.plazo_meses,
      'solicitud_cuota', sp.cuota_mensual,
      'solicitud_estado', sp.estado,
      'solicitud_producto', sp.tipo_producto,
      'prioridad', CASE
        WHEN sp.id IS NOT NULL THEN 150
        WHEN COALESCE(cp.dias_mora, 0) > 30 THEN 100
        WHEN COALESCE(cp.dias_mora, 0) > 0  THEN 80
        WHEN cp.estado_pago IS DISTINCT FROM 'al_dia' THEN 60
        ELSE 40
      END,
      'estado_visita', 'pendiente'
    ) AS row
    FROM public.perfiles_clientes pc
    LEFT JOIN LATERAL (
      SELECT dias_mora, estado_pago
      FROM public.creditos_preaprobados
      WHERE user_id = pc.user_id
      ORDER BY created_at DESC
      LIMIT 1
    ) cp ON TRUE
    LEFT JOIN LATERAL (
      SELECT COALESCE(SUM(c.saldo), 0) AS saldo_total
      FROM public.cuentas c
      WHERE c.user_id = pc.user_id
    ) cta ON TRUE
    LEFT JOIN LATERAL (
      SELECT sp2.id, sp2.monto, sp2.plazo_meses, sp2.cuota_mensual,
             sp2.estado, sp2.numero_expediente, sp2.tipo_producto
      FROM public.solicitudes_prestamo sp2
      WHERE sp2.user_id = pc.user_id
        AND sp2.estado IN ('enviado', 'pendiente', 'en_comite')
        AND COALESCE(sp2.origen, 'asesor') = 'cliente'
      ORDER BY sp2.created_at DESC
      LIMIT 1
    ) sp ON TRUE
    WHERE public.asesor_atiende_cliente(pc.user_id)
      AND NOT EXISTS (
        SELECT 1
        FROM public.visitas_cartera_dia v
        WHERE v.asesor_user_id = auth.uid()
          AND v.cliente_user_id = pc.user_id
          AND v.fecha = CURRENT_DATE
      )
  ) sub;

  RETURN jsonb_build_object('ok', true, 'paradas', v_result);
END;
$$;

REVOKE ALL ON FUNCTION public.asesor_get_ruta_dia() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asesor_get_ruta_dia() TO authenticated;

NOTIFY pgrst, 'reload schema';
