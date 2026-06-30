import { supabase, supabaseError } from '../lib/supabase.js'

/** Clientes en mora del día (sincroniza cronograma + RLS). */
export async function listarMora() {
  const { data: raw, error } = await supabase.rpc('asesor_listar_mora_dia')
  if (error) {
    const msg = error.message || ''
    if (msg.includes('asesor_listar_mora_dia')) {
      throw new Error(
        'Cobranza no configurada en Supabase. Ejecuta database/supabase/30_cobranza_completa.sql en el SQL Editor.',
      )
    }
    throw new Error(supabaseError(error))
  }
  if (!raw?.ok) throw new Error(raw?.error || 'No se pudo cargar la mora.')
  return raw.items || []
}

/** Historial de gestiones de un cliente. */
export async function historialCobranza(clienteId) {
  const { data: raw, error } = await supabase.rpc('asesor_historial_cobranza', {
    p_cliente_user_id: clienteId,
  })
  if (error) throw new Error(supabaseError(error))
  if (!raw?.ok) throw new Error(raw?.error || 'No se pudo cargar el historial.')
  return raw.items || []
}

/** Registra una gestión de cobranza en Supabase. */
export async function registrarAccion(payload) {
  const { data: raw, error } = await supabase.rpc('asesor_registrar_accion_cobranza', {
    p_cliente_user_id: payload.cliente_id,
    p_tipo_gestion: payload.tipo_gestion,
    p_resultado: payload.resultado,
    p_credito_id: payload.credito_id || null,
    p_cod_cuenta_credito: payload.cod_cuenta_credito || null,
    p_monto_pagado: payload.monto_pagado ?? null,
    p_fecha_compromiso: payload.fecha_compromiso || null,
    p_monto_compromiso: payload.monto_compromiso ?? null,
    p_observaciones: payload.observaciones || '',
    p_lat: payload.lat ?? null,
    p_lng: payload.lng ?? null,
  })
  if (error) {
    const msg = error.message || ''
    if (msg.includes('asesor_registrar_accion_cobranza')) {
      throw new Error(
        'Cobranza no configurada en Supabase. Ejecuta database/supabase/30_cobranza_completa.sql en el SQL Editor.',
      )
    }
    throw new Error(supabaseError(error))
  }
  if (!raw?.ok) throw new Error(raw?.error || 'No se pudo registrar la gestión.')
  return raw
}
