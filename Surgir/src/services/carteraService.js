import { supabase, supabaseError } from '../lib/supabase.js'

function mapParada(p, idx) {
  const prioridad = Number(p.prioridad) || 0
  const diasMora = Number(p.dias_mora) || 0
  const esNuevo = p.tipo_gestion === 'NUEVO_CLIENTE'
  const esNueva = p.tipo_gestion === 'NUEVA_SOLICITUD'
  const esAprobado = p.tipo_gestion === 'CREDITO_APROBADO'
  const lat = p.lat_negocio != null ? Number(p.lat_negocio) : null
  const lng = p.lng_negocio != null ? Number(p.lng_negocio) : null
  const tieneUbicacion = Boolean(
    p.tiene_ubicacion ?? (Number.isFinite(lat) && Number.isFinite(lng)),
  )
  return {
    id: p.user_id || `ruta-${idx}`,
    cliente_id: p.user_id,
    cliente_nombre: `${p.nombres ?? ''} ${p.apellidos ?? ''}`.trim(),
    documento: p.dni,
    tipo_gestion: p.tipo_gestion || (diasMora > 30
      ? 'RECUPERACION_MORA'
      : diasMora > 0
        ? 'SEGUIMIENTO'
        : 'RENOVACION'),
    prioridad: prioridad >= 80 ? 'alta' : prioridad >= 60 ? 'media' : 'normal',
    score_prioridad: prioridad,
    monto_credito: p.solicitud_monto || 0,
    saldo_cuenta: Number(p.saldo_cuenta) || 0,
    estado_visita: p.estado_visita || 'pendiente',
    lat,
    lng,
    tiene_ubicacion: tieneUbicacion,
    telefono: p.telefono,
    distrito: p.distrito,
    direccion: p.direccion_negocio,
    solicitud_id: p.solicitud_id,
    solicitud_monto: p.solicitud_monto,
    solicitud_plazo: p.solicitud_plazo,
    solicitud_estado: p.solicitud_estado,
    es_nuevo_cliente: esNuevo,
    es_nueva_solicitud: esNueva,
    es_credito_aprobado: esAprobado,
  }
}

/** Cartera del día — todos los clientes pendientes de gestión hoy. */
export async function listarCartera() {
  const { data: raw, error } = await supabase.rpc('asesor_get_ruta_dia')
  if (error) throw new Error(supabaseError(error))
  if (!raw?.ok) throw new Error(raw?.error || 'No se pudo cargar la cartera.')

  const paradas = raw.paradas || []
  return paradas.map(mapParada)
}

/** Planificación de ruta — solo paradas con GPS (misma fuente, filtrada). */
export async function listarRuta() {
  const paradas = await listarCartera()
  return paradas.filter((p) => p.tiene_ubicacion)
}

/** Registra visita del día — desaparece de la cartera al recargar. */
export async function marcarVisita(carteraId, { resultado, observacion }) {
  const { data: raw, error } = await supabase.rpc('asesor_registrar_visita_cartera', {
    p_cliente_user_id: carteraId,
    p_resultado: resultado,
    p_observacion: observacion || '',
  })

  if (error) {
    const msg = error.message || ''
    if (msg.includes('asesor_registrar_visita_cartera')) {
      throw new Error(
        'Ejecuta database/supabase/33_cartera_visitas_dia.sql en Supabase para registrar visitas.',
      )
    }
    throw new Error(supabaseError(error, 'No se pudo registrar la visita.'))
  }

  if (!raw?.ok) throw new Error(raw?.error || 'No se pudo registrar la visita.')
  return raw
}
