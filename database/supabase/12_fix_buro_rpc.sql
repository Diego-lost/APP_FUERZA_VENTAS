-- Corrige asesor_consulta_buro: scores_transaccionales usa fecha_calculo, no created_at.
-- Ejecutar en Supabase SQL Editor si el buró devuelve error 42703.

CREATE OR REPLACE FUNCTION public.asesor_consulta_buro(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil  RECORD;
  v_score   RECORD;
  v_ficha   RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  IF NOT public.asesor_atiende_cliente(p_user_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'cliente_no_cartera');
  END IF;

  SELECT dni, nombres, apellidos,
         calificacion_sbs, num_entidades_sbs, deuda_total_sbs
  INTO v_perfil
  FROM public.perfiles_clientes
  WHERE user_id = p_user_id;

  SELECT score_transaccional, segmento_preliminar, monto_hipotesis
  INTO v_score
  FROM public.scores_transaccionales
  WHERE user_id = p_user_id
  ORDER BY fecha_calculo DESC
  LIMIT 1;

  SELECT score_campo, score_final, segmento_resultante,
         recomendacion_asesor, estado_ficha
  INTO v_ficha
  FROM public.fichas_campo
  WHERE user_id = p_user_id
  ORDER BY fecha_visita DESC
  LIMIT 1;

  RETURN jsonb_build_object(
    'ok', true,
    'cliente', jsonb_build_object(
      'dni', v_perfil.dni,
      'nombres', v_perfil.nombres,
      'apellidos', v_perfil.apellidos
    ),
    'sbs', jsonb_build_object(
      'calificacion', COALESCE(v_perfil.calificacion_sbs, 'Normal'),
      'entidades', COALESCE(v_perfil.num_entidades_sbs, 0),
      'deuda_total', COALESCE(v_perfil.deuda_total_sbs, 0)
    ),
    'scoring', jsonb_build_object(
      'transaccional', v_score.score_transaccional,
      'segmento_preliminar', v_score.segmento_preliminar,
      'monto_hipotesis', v_score.monto_hipotesis,
      'campo', v_ficha.score_campo,
      'final', v_ficha.score_final,
      'segmento_resultante', v_ficha.segmento_resultante,
      'recomendacion_asesor', v_ficha.recomendacion_asesor,
      'estado_ficha', v_ficha.estado_ficha
    )
  );
END;
$$;

NOTIFY pgrst, 'reload schema';
