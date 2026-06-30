import { supabase, supabaseError } from '../lib/supabase.js'
import { fetchPerfilesMap } from './supabaseHelpers.js'

const RPC_ERRORS = {
  dni_invalido: 'El DNI debe tener 8 dígitos.',
  dni_ya_registrado: 'Ese DNI ya está registrado en el sistema.',
  nombre_requerido: 'Ingresa nombres y apellidos del cliente.',
  password_corta: 'La contraseña debe tener al menos 4 caracteres.',
  asesor_no_autenticado: 'Tu sesión de asesor expiró. Vuelve a iniciar sesión.',
  asesor_no_encontrado: 'No se encontró el asesor asignado. Verifica tu código en Supabase.',
  sin_permiso: 'Solo administradores pueden crear asesores.',
  campos_requeridos: 'Completa código, nombres, apellidos y email.',
  codigo_ya_existe: 'Ese código de asesor ya existe.',
  agencia_no_encontrada: 'Selecciona una agencia válida.',
}

function mapRpcError(code, fallback) {
  if (!code) return fallback
  return RPC_ERRORS[code] || String(code).replace(/_/g, ' ')
}

function isMissingRpc(error) {
  const msg = (error?.message || '').toLowerCase()
  return error?.code === 'PGRST202' ||
    msg.includes('could not find the function') ||
    (msg.includes('function') && msg.includes('does not exist'))
}

export async function responderSolicitud({
  solicitudId,
  decision,
  observaciones,
  montoAjustado,
}) {
  const { data, error } = await supabase.rpc('asesor_responder_solicitud', {
    p_solicitud_id: solicitudId,
    p_decision: decision,
    p_observaciones: observaciones || null,
    p_monto_ajustado: montoAjustado ?? null,
  })
  if (error) throw new Error(supabaseError(error))
  if (!data?.ok) throw new Error(mapRpcError(data?.error, 'No se pudo registrar la decisión.'))
  return data
}

export async function transmitirPendientes() {
  const { data, error } = await supabase.rpc('asesor_transmitir_pendientes')
  if (error) throw new Error(supabaseError(error))
  if (!data?.ok) throw new Error(data?.error || 'No se pudo transmitir.')
  return data
}

export async function desembolsarSolicitudes(solicitudIds) {
  const { data, error } = await supabase.rpc('asesor_desembolsar_solicitudes', {
    p_solicitud_ids: solicitudIds,
  })
  if (error) throw new Error(supabaseError(error))
  if (!data?.ok) throw new Error(data?.error || 'No se pudo desembolsar.')
  return data
}

export async function listarDocumentosPendientes() {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return []

  const { data, error } = await supabase
    .from('documentos_captura')
    .select('id, tipo, referencia, user_id')
    .eq('estado', 'capturado')
    .eq('asesor_user_id', user.id)
    .order('created_at', { ascending: false })

  if (error) throw new Error(supabaseError(error))

  const rows = data || []
  const perfilesMap = await fetchPerfilesMap(rows.map((r) => r.user_id))

  return rows.map((row) => {
    const pc = perfilesMap[row.user_id] || {}
    return {
      id: row.id,
      tipo: row.tipo,
      referencia: row.referencia,
      cliente_nombre: `${pc.nombres ?? ''} ${pc.apellidos ?? ''}`.trim() || 'Cliente',
    }
  })
}

export async function atenderSolicitudCliente(solicitudId) {
  const { data, error } = await supabase.rpc('asesor_atender_solicitud_cliente', {
    p_solicitud_id: solicitudId,
  })
  if (error) throw new Error(supabaseError(error))
  return data?.ok === true
}

async function registrarClienteFallback(payload) {
  const { data: resumen, error: resErr } = await supabase.rpc('get_resumen_cartera_asesor')
  if (resErr) throw new Error(supabaseError(resErr))
  if (!resumen?.ok) {
    throw new Error(mapRpcError(resumen?.error, 'No hay sesión de asesor activa.'))
  }

  const { data, error } = await supabase.rpc('cliente_registrarse', {
    p_dni: payload.dni,
    p_nombres: payload.nombres,
    p_apellidos: payload.apellidos,
    p_password: payload.password || 'Cliente2026!',
    p_telefono: payload.telefono || null,
    p_nombre_negocio: payload.nombre_negocio || null,
    p_distrito: payload.distrito || null,
    p_direccion_negocio: payload.direccion || null,
    p_antiguedad_meses: payload.antiguedad_meses ?? null,
    p_ingresos_mensuales: payload.ingresos ?? null,
    p_gastos_mensuales: payload.gastos ?? null,
    p_asesor_codigo: resumen.codigo,
  })
  if (error) throw new Error(supabaseError(error))
  if (!data?.ok) throw new Error(mapRpcError(data?.error, 'No se pudo registrar el cliente.'))

  if (payload.lat != null && payload.lng != null && data.user_id) {
    await supabase.rpc('asesor_actualizar_direccion_cliente', {
      p_user_id: data.user_id,
      p_direccion_negocio: payload.direccion || 'Ubicación registrada en campo',
      p_distrito: payload.distrito || null,
      p_lat_negocio: payload.lat,
      p_lng_negocio: payload.lng,
    }).catch(() => {})
  }

  return data
}

export async function registrarCliente(payload) {
  try {
    const { data, error } = await supabase.rpc('asesor_registrar_cliente', {
      p_dni: payload.dni,
      p_nombres: payload.nombres,
      p_apellidos: payload.apellidos,
      p_telefono: payload.telefono || null,
      p_nombre_negocio: payload.nombre_negocio || null,
      p_distrito: payload.distrito || null,
      p_direccion_negocio: payload.direccion || null,
      p_lat_negocio: payload.lat ?? null,
      p_lng_negocio: payload.lng ?? null,
      p_antiguedad_meses: payload.antiguedad_meses ?? null,
      p_ingresos_mensuales: payload.ingresos ?? null,
      p_gastos_mensuales: payload.gastos ?? null,
      p_password: payload.password || 'Cliente2026!',
    })
    if (error) {
      if (isMissingRpc(error)) return registrarClienteFallback(payload)
      throw new Error(supabaseError(error))
    }
    if (!data?.ok) throw new Error(mapRpcError(data?.error, 'No se pudo registrar el cliente.'))
    return data
  } catch (err) {
    if (isMissingRpc(err)) return registrarClienteFallback(payload)
    throw err
  }
}

export async function crearAsesor(payload) {
  const { data, error } = await supabase.rpc('admin_crear_asesor', {
    p_codigo: payload.codigo,
    p_nombres: payload.nombres,
    p_apellidos: payload.apellidos,
    p_email: payload.email,
    p_id_agencia: payload.id_agencia,
    p_nivel: payload.nivel,
    p_perfil: payload.perfil,
    p_password: payload.password,
    p_telefono: payload.telefono || null,
    p_dni: payload.dni || null,
  })
  if (error) {
    const msg = supabaseError(error)
    if (isMissingRpc(error)) {
      throw new Error(
        'Ejecuta database/supabase/25_fventas_registro_maps.sql y 35_fix_registro_web_cliente_asesor.sql en Supabase.',
      )
    }
    throw new Error(msg)
  }
  if (!data?.ok) throw new Error(mapRpcError(data?.error, 'No se pudo crear el asesor.'))
  return data
}

export async function listarAgencias() {
  const { data: rpcData, error: rpcError } = await supabase.rpc('asesor_listar_agencias')
  if (!rpcError && rpcData?.ok) return rpcData.agencias || []

  const { data: adminData, error: adminError } = await supabase.rpc('admin_listar_agencias')
  if (!adminError && adminData?.ok) return adminData.agencias || []

  const { data, error } = await supabase
    .from('agencias')
    .select('id, codigo, nombre, distrito')
    .eq('activa', true)
    .order('codigo')

  if (error) {
    const code = adminData?.error || rpcData?.error
    throw new Error(mapRpcError(code, supabaseError(error, 'No se pudieron cargar las agencias.')))
  }
  return data || []
}

export async function registrarDocumento({ userId, tipo, referencia, observaciones }) {
  const { data, error } = await supabase.rpc('asesor_registrar_documento', {
    p_user_id: userId,
    p_tipo: tipo,
    p_referencia: referencia || null,
    p_observaciones: observaciones || null,
  })
  if (error) throw new Error(supabaseError(error))
  if (!data?.ok) throw new Error(data?.error || 'No se pudo registrar el documento.')
  return data
}

export async function obtenerPerfilRbac() {
  const { data, error } = await supabase.rpc('asesor_obtener_perfil_rbac')
  if (error) throw new Error(supabaseError(error))
  return data
}

export async function listarDocumentosCliente(userId) {
  const { data, error } = await supabase
    .from('documentos_captura')
    .select('id, tipo, referencia, observaciones, estado, created_at')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(10)

  if (error) throw new Error(supabaseError(error))
  return data || []
}

export async function listarCampanas() {
  const { data, error } = await supabase
    .from('creditos_preaprobados')
    .select(
      'id, user_id, monto_aprobado, saldo_pendiente, segmento, estado_pago, dias_mora, estado',
    )
    .eq('dias_mora', 0)
    .eq('estado', 'desembolsado')
    .order('monto_aprobado', { ascending: false })
    .limit(40)

  if (error) throw new Error(supabaseError(error))

  const rows = (data || []).filter((r) => r.estado_pago === 'al_dia')
  const perfilesMap = await fetchPerfilesMap(rows.map((r) => r.user_id))

  return rows.map((row) => ({
    ...row,
    perfiles_clientes: perfilesMap[row.user_id] || null,
  }))
}
