import { supabase, supabaseError } from '../lib/supabase.js'
import { fetchConsultaBuro } from './supabaseHelpers.js'

/** Pre-evaluación local (misma lógica referencial que el portal SURGIR). */
export async function preEvaluar(payload) {
  const ingresos = Number(payload.ingresos_estimados) || 0
  const monto = Number(payload.monto_solicitado) || 0

  if (ingresos <= 0) {
    return {
      calificacion: 'NO_PROCEDE',
      puntaje: 15,
      motivo: 'No hay ingresos estimados suficientes para evaluar capacidad de pago.',
    }
  }

  const ratio = monto / ingresos
  let calificacion = 'APTO'
  let puntaje = 78
  let motivo = 'El monto solicitado es razonable frente a los ingresos declarados.'

  if (ratio > 0.5) {
    calificacion = 'NO_PROCEDE'
    puntaje = 22
    motivo = 'El monto supera el 50% de los ingresos mensuales. No procede por capacidad de pago.'
  } else if (ratio > 0.3) {
    calificacion = 'REVISAR'
    puntaje = 52
    motivo = 'El monto está entre 30% y 50% de los ingresos. Requiere revisión en comité.'
  }

  return { calificacion, puntaje, motivo, ratio_cuota: ratio }
}

/** Consulta buró desde perfiles_clientes + scores + fichas (Supabase). */
export async function consultarBuro({ dni }) {
  const { data: cliente, error: cliErr } = await supabase
    .from('perfiles_clientes')
    .select('user_id')
    .eq('dni', dni.trim())
    .maybeSingle()

  if (cliErr) throw new Error(supabaseError(cliErr))
  if (!cliente?.user_id) {
    throw new Error('Cliente no encontrado en tu cartera. Verifica el DNI.')
  }

  const raw = await fetchConsultaBuro(cliente.user_id)
  if (!raw?.ok) throw new Error(raw?.error || 'No se pudo consultar el buró.')

  const cal = raw.sbs?.calificacion || 'Normal'
  const bloqueados = ['Dudoso', 'Perdida', 'Deficiente']
  const enLista = bloqueados.includes(cal)

  const interpretaciones = {
    Normal: 'Sin señales de alerta en el sistema financiero.',
    CPP: 'Con deudas en etapa de cobranza preventiva. Revisar con cautela.',
    Deficiente: 'Deudas con problemas de pago. Alto riesgo.',
    Dudoso: 'Deudas con alta probabilidad de incobrabilidad.',
    Perdida: 'Deudas incobrables. No procede.',
  }

  return {
    en_lista_negra: enLista,
    motivo_bloqueo: enLista ? `Calificación SBS: ${cal}. No procede automáticamente.` : null,
    calificacion_sbs: cal,
    interpretacion: interpretaciones[cal] || 'Consulta realizada.',
    entidades_con_deuda: raw.sbs?.entidades ?? 0,
    deuda_total: raw.sbs?.deuda_total ?? 0,
    mayor_deuda: raw.sbs?.deuda_total ?? 0,
    dias_mayor_mora: raw.dias_mayor_mora ?? 0,
    scoring: raw.scoring,
  }
}
