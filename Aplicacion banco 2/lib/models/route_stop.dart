class RouteStop {
  const RouteStop({
    required this.userId,
    required this.dni,
    required this.nombreCompleto,
    required this.prioridad,
    this.distrito,
    this.direccion,
    this.telefono,
    this.lat,
    this.lng,
    this.diasMora = 0,
    this.estadoPago,
    this.tipoGestion,
    this.solicitudId,
    this.numeroExpediente,
    this.solicitudMonto,
    this.solicitudPlazo,
    this.solicitudCuota,
    this.solicitudEstado,
    this.solicitudProducto,
    this.saldoCuenta = 0,
    this.estadoVisita = 'pendiente',
  });

  final String userId;
  final String dni;
  final String nombreCompleto;
  final int prioridad;
  final String? distrito;
  final String? direccion;
  final String? telefono;
  final double? lat;
  final double? lng;
  final int diasMora;
  final String? estadoPago;
  final String? tipoGestion;
  final String? solicitudId;
  final String? numeroExpediente;
  final double? solicitudMonto;
  final int? solicitudPlazo;
  final double? solicitudCuota;
  final String? solicitudEstado;
  final String? solicitudProducto;
  final double saldoCuenta;
  final String estadoVisita;

  bool get esNuevaSolicitud => tipoGestion == 'NUEVA_SOLICITUD';
  bool get esCreditoAprobado => tipoGestion == 'CREDITO_APROBADO';
  bool get visitaGestionada =>
      estadoVisita.isNotEmpty && estadoVisita != 'pendiente';

  String get prioridadNivel {
    if (prioridad >= 80) return 'alta';
    if (prioridad >= 60) return 'media';
    return 'normal';
  }

  String get tipoGestionLabel {
    switch (tipoGestion) {
      case 'NUEVA_SOLICITUD':
        return 'Nueva solicitud';
      case 'CREDITO_APROBADO':
        return 'Crédito aprobado — visita';
      case 'RECUPERACION_MORA':
        return 'Recuperación mora';
      case 'SEGUIMIENTO':
        return 'Seguimiento';
      case 'RENOVACION':
        return 'Renovación';
      default:
        return tipoGestion ?? 'Visita';
    }
  }

  String get prioridadLabel {
    if (esCreditoAprobado) {
      return 'CRÉDITO APROBADO — visita para desembolso';
    }
    if (esNuevaSolicitud) {
      return 'NUEVA SOLICITUD — visita requerida';
    }
    if (diasMora > 30) return 'Urgente — mora alta';
    if (diasMora > 0) return 'Prioridad — en mora';
    if (estadoPago != null && estadoPago != 'al_dia') {
      return 'Seguimiento de pago';
    }
    return 'Visita programada';
  }

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      userId: json['user_id'] as String,
      dni: json['dni'] as String? ?? '',
      nombreCompleto:
          '${json['nombres'] ?? ''} ${json['apellidos'] ?? ''}'.trim(),
      prioridad: json['prioridad'] as int? ?? 0,
      distrito: json['distrito'] as String?,
      direccion: json['direccion_negocio'] as String?,
      telefono: json['telefono'] as String?,
      lat: _toDoubleOrNull(json['lat_negocio']),
      lng: _toDoubleOrNull(json['lng_negocio']),
      diasMora: json['dias_mora'] as int? ?? 0,
      estadoPago: json['estado_pago'] as String?,
      tipoGestion: json['tipo_gestion'] as String?,
      solicitudId: json['solicitud_id'] as String?,
      numeroExpediente: json['numero_expediente'] as String?,
      solicitudMonto: _toDoubleOrNull(json['solicitud_monto']),
      solicitudPlazo: (json['solicitud_plazo'] as num?)?.toInt(),
      solicitudCuota: _toDoubleOrNull(json['solicitud_cuota']),
      solicitudEstado: json['solicitud_estado'] as String?,
      solicitudProducto: json['solicitud_producto'] as String?,
      saldoCuenta: _toDoubleOrNull(json['saldo_cuenta']) ?? 0,
      estadoVisita: json['estado_visita'] as String? ?? 'pendiente',
    );
  }

  static double? _toDoubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
