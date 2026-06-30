class BureauReport {
  const BureauReport({
    required this.dni,
    required this.nombreCompleto,
    required this.calificacionSbs,
    required this.entidadesSbs,
    required this.deudaTotalSbs,
    this.scoreTransaccional,
    this.segmentoPreliminar,
    this.montoHipotesis,
    this.scoreCampo,
    this.scoreFinal,
    this.segmentoResultante,
    this.recomendacionAsesor,
    this.estadoFicha,
  });

  final String dni;
  final String nombreCompleto;
  final String calificacionSbs;
  final int entidadesSbs;
  final double deudaTotalSbs;
  final int? scoreTransaccional;
  final String? segmentoPreliminar;
  final double? montoHipotesis;
  final int? scoreCampo;
  final int? scoreFinal;
  final String? segmentoResultante;
  final String? recomendacionAsesor;
  final String? estadoFicha;

  factory BureauReport.fromJson(Map<String, dynamic> json) {
    final cliente = Map<String, dynamic>.from(json['cliente'] as Map? ?? {});
    final sbs = Map<String, dynamic>.from(json['sbs'] as Map? ?? {});
    final scoring = Map<String, dynamic>.from(json['scoring'] as Map? ?? {});

    return BureauReport(
      dni: cliente['dni'] as String? ?? '',
      nombreCompleto:
          '${cliente['nombres'] ?? ''} ${cliente['apellidos'] ?? ''}'.trim(),
      calificacionSbs: sbs['calificacion'] as String? ?? 'Normal',
      entidadesSbs: sbs['entidades'] as int? ?? 0,
      deudaTotalSbs: _toDouble(sbs['deuda_total']),
      scoreTransaccional: scoring['transaccional'] as int?,
      segmentoPreliminar: scoring['segmento_preliminar'] as String?,
      montoHipotesis: scoring['monto_hipotesis'] != null
          ? _toDouble(scoring['monto_hipotesis'])
          : null,
      scoreCampo: scoring['campo'] as int?,
      scoreFinal: scoring['final'] as int?,
      segmentoResultante: scoring['segmento_resultante'] as String?,
      recomendacionAsesor: scoring['recomendacion_asesor'] as String?,
      estadoFicha: scoring['estado_ficha'] as String?,
    );
  }

  static double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
