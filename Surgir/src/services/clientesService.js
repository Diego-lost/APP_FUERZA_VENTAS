import { supabase, supabaseError } from '../lib/supabase.js'
import { fetchConsultaBuro } from './supabaseHelpers.js'

/** Ficha 360° del cliente desde perfiles + créditos + buró (Supabase). */
export async function obtenerFicha(clienteId) {
  const { data: perfil, error: perfilErr } = await supabase
    .from('perfiles_clientes')
    .select('*')
    .eq('user_id', clienteId)
    .maybeSingle()

  if (perfilErr) throw new Error(supabaseError(perfilErr))
  if (!perfil) throw new Error('Cliente no encontrado en tu cartera.')

  const { data: creditos } = await supabase
    .from('creditos_preaprobados')
    .select(
      'id, segmento, tipo_producto, monto_aprobado, saldo_pendiente, cuotas_pagadas, '
      + 'cuota_mensual, plazo_meses, estado, estado_pago, dias_mora, tea, created_at',
    )
    .eq('user_id', clienteId)
    .order('created_at', { ascending: false })

  const { data: cuentas } = await supabase
    .from('cuentas')
    .select('id, tipo, numero_cuenta, saldo, moneda')
    .eq('user_id', clienteId)
    .order('created_at')

  const buroRaw = await fetchConsultaBuro(clienteId).catch(() => null)

  const lista = creditos || []
  const listaCuentas = cuentas || []
  const saldoCuentas = listaCuentas.reduce((s, c) => s + Number(c.saldo || 0), 0)
  const activos = lista.filter((c) => c.estado === 'desembolsado')
  const deudaActiva = activos.reduce(
    (sum, c) => sum + Number(c.saldo_pendiente ?? c.monto_aprobado ?? 0),
    0,
  )
  const enMora = lista.filter((c) => (c.dias_mora || 0) > 0)
  const maxMora = lista.reduce((m, c) => Math.max(m, c.dias_mora || 0), 0)
  const vigente = activos[0] || lista.find((c) => c.estado === 'vigente' || c.estado === 'aprobado') || lista[0]

  const buro = buroRaw?.ok ? buroRaw : null

  return {
    cliente: {
      nombres: perfil.nombres,
      apellidos: perfil.apellidos,
      numero_documento: perfil.dni,
      telefono: perfil.telefono,
      tipo_negocio: perfil.tipo_negocio,
      nombre_negocio: perfil.nombre_negocio,
      direccion: perfil.direccion_negocio,
      calificacion_sbs: perfil.calificacion_sbs || buro?.sbs?.calificacion || 'Normal',
      antiguedad_negocio_meses: perfil.antiguedad_negocio_meses,
    },
    posicion: {
      deuda_total: deudaActiva > 0
        ? deudaActiva
        : (perfil.deuda_total_sbs || buro?.sbs?.deuda_total || 0),
      saldo_cuentas: saldoCuentas,
      cuentas_vigentes: lista.filter((c) => (c.dias_mora || 0) === 0).length,
      cuentas_mora: enMora.length,
      dias_mayor_mora: maxMora,
    },
    cuentas: listaCuentas.map((c) => ({
      id: c.id,
      tipo: c.tipo,
      numero_cuenta: c.numero_cuenta,
      saldo: Number(c.saldo) || 0,
      moneda: c.moneda || 'PEN',
    })),
    historial: lista.map((c) => ({
      producto: c.tipo_producto || c.segmento || 'Crédito',
      monto_desembolsado: c.monto_aprobado,
      saldo_pendiente: c.saldo_pendiente ?? c.monto_aprobado,
      plazo_meses: c.plazo_meses,
      tea: c.tea || 60,
      cuotas_pagadas: c.cuotas_pagadas ?? 0,
      cuotas_total: c.plazo_meses,
      dias_mora: c.dias_mora || 0,
      estado: c.estado_pago || c.estado || 'vigente',
    })),
    oferta: vigente
      ? {
          monto_maximo: vigente.saldo_pendiente ?? vigente.monto_aprobado,
          plazo_sugerido_meses: vigente.plazo_meses,
          tea_referencial: vigente.tea || 60,
          score_confianza: buro?.scoring?.transaccional ?? null,
          fecha_vencimiento: null,
        }
      : null,
    indicadores: buro?.scoring
      ? {
          pct_puntual: buro.scoring.transaccional,
          dias_prom_mora: maxMora,
          monto_pagado: 0,
        }
      : null,
  }
}
