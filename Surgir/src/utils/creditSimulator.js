/** Simulador de cuota con amortización francesa + cronograma (RF-47). */
export function calcularCredito({ monto, plazoMeses, teaPorcentaje = 60 }) {
  if (monto <= 0 || plazoMeses <= 0) {
    return {
      cuotaMensual: 0,
      totalPagar: 0,
      costoFinanciero: 0,
      teaReferencial: teaPorcentaje,
      cronograma: [],
    }
  }

  const tea = teaPorcentaje / 100
  const tm = (1 + tea) ** (1 / 12) - 1
  const cuota = tm === 0 ? monto / plazoMeses : (monto * tm) / (1 - (1 + tm) ** -plazoMeses)
  const total = cuota * plazoMeses

  let saldo = monto
  const cronograma = []
  for (let i = 1; i <= plazoMeses; i++) {
    const interes = saldo * tm
    let capital = cuota - interes
    if (i === plazoMeses) capital = saldo
    saldo = Math.max(0, saldo - capital)
    cronograma.push({
      nroCuota: i,
      montoCuota: cuota,
      montoCapital: capital,
      montoInteres: interes,
      saldo,
    })
  }

  return {
    cuotaMensual: cuota,
    totalPagar: total,
    costoFinanciero: total - monto,
    teaReferencial: teaPorcentaje,
    cronograma,
  }
}
