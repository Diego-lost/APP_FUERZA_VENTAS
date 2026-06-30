import { supabase, supabaseError } from '../lib/supabase.js'

/** Carga perfiles_clientes por user_id (evita joins sin FK en PostgREST). */
export async function fetchPerfilesMap(userIds) {
  const ids = [...new Set(userIds.filter(Boolean))]
  if (!ids.length) return {}

  const { data } = await supabase
    .from('perfiles_clientes')
    .select('user_id, dni, nombres, apellidos, telefono')
    .in('user_id', ids)

  return Object.fromEntries((data || []).map((p) => [p.user_id, p]))
}

/** Buró / scoring desde tablas (misma lógica que RPC asesor_consulta_buro). */
export async function fetchConsultaBuro(userId) {
  const [
    { data: perfil, error: perfilErr },
    { data: scores, error: scoreErr },
    { data: fichas, error: fichaErr },
    { data: creditos, error: credErr },
  ] = await Promise.all([
    supabase
      .from('perfiles_clientes')
      .select('dni, nombres, apellidos, calificacion_sbs, num_entidades_sbs, deuda_total_sbs')
      .eq('user_id', userId)
      .maybeSingle(),
    supabase
      .from('scores_transaccionales')
      .select('score_transaccional, segmento_preliminar, monto_hipotesis')
      .eq('user_id', userId)
      .order('fecha_calculo', { ascending: false })
      .limit(1),
    supabase
      .from('fichas_campo')
      .select('score_campo, score_final, segmento_resultante, recomendacion_asesor, estado_ficha')
      .eq('user_id', userId)
      .order('fecha_visita', { ascending: false })
      .limit(1),
    supabase
      .from('creditos_preaprobados')
      .select('dias_mora')
      .eq('user_id', userId),
  ])

  const err = perfilErr || scoreErr || fichaErr || credErr
  if (err) throw new Error(supabaseError(err))
  if (!perfil) return { ok: false, error: 'cliente_no_cartera' }

  const score = scores?.[0] || null
  const ficha = fichas?.[0] || null
  const diasMayorMora = (creditos || []).reduce(
    (max, c) => Math.max(max, c.dias_mora || 0),
    0,
  )

  return {
    ok: true,
    cliente: {
      dni: perfil.dni,
      nombres: perfil.nombres,
      apellidos: perfil.apellidos,
    },
    sbs: {
      calificacion: perfil.calificacion_sbs || 'Normal',
      entidades: perfil.num_entidades_sbs ?? 0,
      deuda_total: perfil.deuda_total_sbs ?? 0,
    },
    scoring: {
      transaccional: score?.score_transaccional ?? null,
      segmento_preliminar: score?.segmento_preliminar ?? null,
      monto_hipotesis: score?.monto_hipotesis ?? null,
      campo: ficha?.score_campo ?? null,
      final: ficha?.score_final ?? null,
      segmento_resultante: ficha?.segmento_resultante ?? null,
      recomendacion_asesor: ficha?.recomendacion_asesor ?? null,
      estado_ficha: ficha?.estado_ficha ?? null,
    },
    dias_mayor_mora: diasMayorMora,
  }
}
