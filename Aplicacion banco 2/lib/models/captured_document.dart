class CapturedDocument {
  const CapturedDocument({
    required this.id,
    required this.userId,
    required this.tipo,
    required this.estado,
    this.referencia,
    this.observaciones,
    this.createdAt,
    this.clienteNombre,
  });

  final String id;
  final String userId;
  final String tipo;
  final String estado;
  final String? referencia;
  final String? observaciones;
  final DateTime? createdAt;
  final String? clienteNombre;

  String get tipoLabel {
    switch (tipo) {
      case 'dni_frontal':
        return 'DNI frontal';
      case 'dni_posterior':
        return 'DNI posterior';
      case 'foto_negocio':
        return 'Foto del negocio';
      case 'recibo_servicio':
        return 'Recibo de servicio';
      case 'contrato_alquiler':
        return 'Contrato de alquiler';
      default:
        return 'Otro documento';
    }
  }

  factory CapturedDocument.fromJson(Map<String, dynamic> json) {
    final perfil = json['perfiles_clientes'];
    Map<String, dynamic>? p;
    if (perfil is Map) {
      p = Map<String, dynamic>.from(perfil);
    } else if (perfil is List && perfil.isNotEmpty) {
      p = Map<String, dynamic>.from(perfil.first as Map);
    }

    return CapturedDocument(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tipo: json['tipo'] as String? ?? 'otro',
      estado: json['estado'] as String? ?? 'capturado',
      referencia: json['referencia'] as String?,
      observaciones: json['observaciones'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      clienteNombre: p != null
          ? '${p['nombres'] ?? ''} ${p['apellidos'] ?? ''}'.trim()
          : null,
    );
  }
}

class TransmissionResult {
  const TransmissionResult({
    required this.ok,
    this.solicitudesTransmitidas = 0,
    this.documentosTransmitidos = 0,
    this.desembolsosReflejados = 0,
    this.error,
  });

  final bool ok;
  final int solicitudesTransmitidas;
  final int documentosTransmitidos;
  final int desembolsosReflejados;
  final String? error;

  factory TransmissionResult.fromJson(Map<String, dynamic> json) {
    return TransmissionResult(
      ok: json['ok'] == true,
      solicitudesTransmitidas: json['solicitudes_transmitidas'] as int? ?? 0,
      documentosTransmitidos: json['documentos_transmitidos'] as int? ?? 0,
      desembolsosReflejados: json['desembolsos_reflejados'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }
}

class DisbursementResult {
  const DisbursementResult({
    required this.ok,
    this.desembolsosOk = 0,
    this.desembolsosFallidos = 0,
    this.error,
  });

  final bool ok;
  final int desembolsosOk;
  final int desembolsosFallidos;
  final String? error;

  factory DisbursementResult.fromJson(Map<String, dynamic> json) {
    return DisbursementResult(
      ok: json['ok'] == true,
      desembolsosOk: json['desembolsos_ok'] as int? ??
          json['desembolsos_reflejados'] as int? ??
          0,
      desembolsosFallidos: json['desembolsos_fallidos'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }
}
