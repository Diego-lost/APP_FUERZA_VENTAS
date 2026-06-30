class CreditApplication {
  const CreditApplication({
    required this.id,
    required this.userId,
    required this.monto,
    required this.plazoMeses,
    required this.cuotaMensual,
    required this.estado,
    this.proposito,
    this.tipoProducto,
    this.asesorCodigo,
    this.createdAt,
    this.clienteNombre,
    this.clienteDni,
  });

  final String id;
  final String userId;
  final double monto;
  final int plazoMeses;
  final double cuotaMensual;
  final String estado;
  final String? proposito;
  final String? tipoProducto;
  final String? asesorCodigo;
  final DateTime? createdAt;
  final String? clienteNombre;
  final String? clienteDni;

  String get estadoLabel {
    switch (estado) {
      case 'enviado':
        return 'Enviado (app cliente)';
      case 'pendiente':
        return 'Pendiente';
      case 'en_comite':
        return 'En comité';
      case 'aprobado':
        return 'Aprobado';
      case 'desembolsado':
        return 'Desembolsado';
      case 'rechazado':
        return 'Rechazado';
      case 'completado':
        return 'Completado';
      default:
        return estado;
    }
  }

  factory CreditApplication.fromJson(Map<String, dynamic> json) {
    final perfil = json['perfiles_clientes'];
    Map<String, dynamic>? p;
    if (perfil is Map) {
      p = Map<String, dynamic>.from(perfil);
    } else if (perfil is List && perfil.isNotEmpty) {
      p = Map<String, dynamic>.from(perfil.first as Map);
    }

    return CreditApplication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      monto: _toDouble(json['monto']),
      plazoMeses: (json['plazo_meses'] as num?)?.toInt() ?? 0,
      cuotaMensual: _toDouble(json['cuota_mensual']),
      estado: json['estado'] as String? ?? 'pendiente',
      proposito: json['proposito'] as String?,
      tipoProducto: json['tipo_producto'] as String?,
      asesorCodigo: json['asesor_codigo'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      clienteNombre: p != null
          ? '${p['nombres'] ?? ''} ${p['apellidos'] ?? ''}'.trim()
          : json['cliente_nombre'] as String?,
      clienteDni: p?['dni'] as String? ?? json['cliente_dni'] as String?,
    );
  }

  static double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class CreateApplicationResult {
  const CreateApplicationResult({
    required this.ok,
    this.solicitudId,
    this.cuotaMensual,
    this.error,
  });

  final bool ok;
  final String? solicitudId;
  final double? cuotaMensual;
  final String? error;

  factory CreateApplicationResult.fromJson(Map<String, dynamic> json) {
    return CreateApplicationResult(
      ok: json['ok'] == true,
      solicitudId: json['solicitud_id'] as String?,
      cuotaMensual: json['cuota_mensual'] != null
          ? CreditApplication._toDouble(json['cuota_mensual'])
          : null,
      error: json['error'] as String?,
    );
  }
}

class SolicitudDecisionResult {
  const SolicitudDecisionResult({
    required this.ok,
    this.estado,
    this.decision,
    this.monto,
    this.cuotaMensual,
    this.error,
    this.desembolsado = false,
    this.prestamoId,
    this.codCredito,
    this.nuevoSaldoCuenta,
  });

  final bool ok;
  final String? estado;
  final String? decision;
  final double? monto;
  final double? cuotaMensual;
  final String? error;
  final bool desembolsado;
  final String? prestamoId;
  final String? codCredito;
  final double? nuevoSaldoCuenta;

  factory SolicitudDecisionResult.fromJson(Map<String, dynamic> json) {
    return SolicitudDecisionResult(
      ok: json['ok'] == true,
      estado: json['estado'] as String?,
      decision: json['decision'] as String?,
      monto: json['monto'] != null
          ? CreditApplication._toDouble(json['monto'])
          : null,
      cuotaMensual: json['cuota_mensual'] != null
          ? CreditApplication._toDouble(json['cuota_mensual'])
          : null,
      error: json['error'] as String?,
      desembolsado: json['desembolsado'] == true,
      prestamoId: json['prestamo_id'] as String?,
      codCredito: json['cod_credito'] as String?,
      nuevoSaldoCuenta: json['nuevo_saldo_cuenta'] != null
          ? CreditApplication._toDouble(json['nuevo_saldo_cuenta'])
          : null,
    );
  }
}
