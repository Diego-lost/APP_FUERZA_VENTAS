class ProductivityReport {
  const ProductivityReport({
    required this.nombre,
    required this.codigo,
    required this.enviadas,
    required this.aprobadas,
    required this.montoTotal,
    required this.tasaAprobacion,
  });

  final String nombre;
  final String codigo;
  final int enviadas;
  final int aprobadas;
  final double montoTotal;
  final double tasaAprobacion;
}
