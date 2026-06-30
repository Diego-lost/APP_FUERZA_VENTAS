import 'dart:math' as math;

class CreditInstallment {
  const CreditInstallment({
    required this.nroCuota,
    required this.montoCuota,
    required this.montoCapital,
    required this.montoInteres,
    required this.saldo,
  });

  final int nroCuota;
  final double montoCuota;
  final double montoCapital;
  final double montoInteres;
  final double saldo;
}

class CreditSimulation {
  const CreditSimulation({
    required this.cuotaMensual,
    required this.totalPagar,
    required this.costoFinanciero,
    required this.teaReferencial,
    required this.cronograma,
  });

  final double cuotaMensual;
  final double totalPagar;
  final double costoFinanciero;
  final double teaReferencial;
  final List<CreditInstallment> cronograma;
}

/// Simulador de cuota con amortización francesa + cronograma (RF-47).
class CreditSimulator {
  CreditSimulator._();

  static CreditSimulation calculate({
    required double monto,
    required int plazoMeses,
    double teaPorcentaje = 60,
  }) {
    if (monto <= 0 || plazoMeses <= 0) {
      return const CreditSimulation(
        cuotaMensual: 0,
        totalPagar: 0,
        costoFinanciero: 0,
        teaReferencial: 60,
        cronograma: [],
      );
    }

    final tea = teaPorcentaje / 100;
    final tm = math.pow(1 + tea, 1 / 12) - 1;
    final cuota = tm == 0
        ? monto / plazoMeses
        : monto * tm / (1 - math.pow(1 + tm, -plazoMeses));
    final total = cuota * plazoMeses;

    var saldo = monto;
    final cronograma = <CreditInstallment>[];
    for (var i = 1; i <= plazoMeses; i++) {
      final interes = saldo * tm;
      var capital = cuota - interes;
      if (i == plazoMeses) {
        capital = saldo;
      }
      saldo = math.max(0, saldo - capital);
      cronograma.add(CreditInstallment(
        nroCuota: i,
        montoCuota: cuota,
        montoCapital: capital,
        montoInteres: interes,
        saldo: saldo,
      ));
    }

    return CreditSimulation(
      cuotaMensual: cuota,
      totalPagar: total,
      costoFinanciero: total - monto,
      teaReferencial: teaPorcentaje,
      cronograma: cronograma,
    );
  }
}
