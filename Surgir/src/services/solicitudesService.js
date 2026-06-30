import { supabase, supabaseError } from '../lib/supabase.js'
import { fetchPerfilesMap } from './supabaseHelpers.js'

function mapSolicitud(row, perfilesMap = {}) {
  const pc = perfilesMap[row.user_id] || row.perfiles_clientes || {}
  const nombre = `${pc.nombres ?? ''} ${pc.apellidos ?? ''}`.trim()
  return {
    id: row.id,
    user_id: row.user_id,
    numero_expediente: row.numero_expediente || String(row.id).slice(0, 8).toUpperCase(),
    cliente_nombre: nombre || row.cliente_nombre || 'Cliente',
    monto_solicitado: row.monto,
    monto_aprobado: ['aprobado', 'desembolsado'].includes(row.estado) ? row.monto : null,
    plazo_meses: row.plazo_meses,
    estado: row.estado,
    created_at: row.created_at,
    tipo_producto: row.tipo_producto,
    cuota_mensual: row.cuota_mensual,
  }
}

/** Tablero vía RPC (misma fuente que app Flutter). */
export async function listarSolicitudesRpc(estado = 'todas') {
  const { data, error } = await supabase.rpc('asesor_listar_solicitudes', {
    p_estado: estado,
  })
  if (error) throw new Error(supabaseError(error))
  if (!data?.ok) return []
  return (data.solicitudes || []).map((r) => mapSolicitud(r))
}

/** Tablero de solicitudes del asesor (RLS en solicitudes_prestamo). */
export async function listarSolicitudes() {
  try {
    const rpc = await listarSolicitudesRpc('todas')
    if (rpc.length > 0) return rpc
  } catch {
    // fallback directo
  }

  const { data, error } = await supabase
    .from('solicitudes_prestamo')
    .select(
      'id, user_id, monto, plazo_meses, cuota_mensual, proposito, estado, '
      + 'tipo_producto, asesor_codigo, created_at',
    )
    .order('created_at', { ascending: false })

  if (error) throw new Error(supabaseError(error))
  const rows = data || []
  const perfilesMap = await fetchPerfilesMap(rows.map((r) => r.user_id))
  return rows.map((r) => mapSolicitud(r, perfilesMap))
}

/** Crea solicitud vía RPC asesor_crear_solicitud_credito. */
export async function crearSolicitud(payload) {
  const { data: cliente, error: cliErr } = await supabase
    .from('perfiles_clientes')
    .select('user_id')
    .eq('dni', payload.numero_documento.trim())
    .maybeSingle()

  if (cliErr) throw new Error(supabaseError(cliErr))
  if (!cliente?.user_id) {
    throw new Error('Cliente no encontrado en tu cartera. Verifica el DNI.')
  }

  const { data: raw, error } = await supabase.rpc('asesor_crear_solicitud_credito', {
    p_user_id: cliente.user_id,
    p_monto: payload.monto_solicitado,
    p_plazo_meses: payload.plazo_meses,
    p_proposito: payload.destino_credito || 'Solicitud registrada desde portal web',
    p_tipo_producto: 'prospera',
  })

  if (error) throw new Error(supabaseError(error))
  if (!raw?.ok) throw new Error(raw?.error || 'No se pudo crear la solicitud.')

  return {
    id: raw.solicitud_id,
    numero_expediente: String(raw.solicitud_id).slice(0, 8).toUpperCase(),
    estado: raw.estado || 'pendiente',
    cuota_mensual: raw.cuota_mensual,
  }
}

/** Notas internas — pendiente de tabla en Supabase. */
export async function listarNotas() {
  return []
}

export async function agregarNota() {
  throw new Error('Las notas internas estarán disponibles en la próxima actualización de Supabase.')
}
