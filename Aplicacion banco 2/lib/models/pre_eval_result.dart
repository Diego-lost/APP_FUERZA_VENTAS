class PreEvalResult {
  const PreEvalResult({
    required this.calificacion,
    required this.puntaje,
    required this.motivo,
    required this.ratioCuota,
  });

  final String calificacion;
  final int puntaje;
  final String motivo;
  final double ratioCuota;

  String get calificacionLabel {
    switch (calificacion) {
      case 'APTO':
        return 'Apto';
      case 'REVISAR':
        return 'Revisar';
      case 'NO_PROCEDE':
        return 'No procede';
      default:
        return calificacion;
    }
  }
}
