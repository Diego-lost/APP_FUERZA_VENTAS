import { supabase, supabaseError } from '../lib/supabase.js'

/** Productividad del mes desde solicitudes_prestamo (cartera del asesor). */
export async function productividad() {
  const now = new Date()
  const inicioMes = new Date(now.getFullYear(), now.getMonth(), 1).toISOString()

  const { data: resumen } = await supabase.rpc('get_resumen_cartera_asesor')
  const nombre = resumen?.ok
    ? `${resumen.nombres ?? ''} ${resumen.apellidos ?? ''}`.trim()
    : 'Mi equipo'

  const { data: solicitudes, error } = await supabase
    .from('solicitudes_prestamo')
    .select('id, estado, monto, asesor_codigo, created_at')
    .gte('created_at', inicioMes)

  if (error) throw new Error(supabaseError(error))

  const rows = solicitudes || []
  const enviadas = rows.length
  const aprobadas = rows.filter((s) => ['aprobado', 'desembolsado', 'completado'].includes(s.estado)).length
  const montoTotal = rows
    .filter((s) => ['aprobado', 'desembolsado', 'completado'].includes(s.estado))
    .reduce((a, s) => a + (Number(s.monto) || 0), 0)

  return [{
    nombre,
    codigo: resumen?.codigo || '—',
    enviadas,
    aprobadas,
    monto_total: montoTotal,
    tasa_aprobacion: enviadas ? (aprobadas / enviadas) * 100 : 0,
  }]
}
