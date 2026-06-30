class CampaignOffer {
  const CampaignOffer({
    required this.id,
    required this.userId,
    required this.clienteNombre,
    required this.dni,
    required this.tipo,
    required this.montoOfertado,
    required this.diasRestantes,
  });

  final String id;
  final String userId;
  final String clienteNombre;
  final String dni;
  final String tipo;
  final double montoOfertado;
  final int diasRestantes;

  String get tipoLabel {
    switch (tipo) {
      case 'renovacion':
        return 'Renovación';
      case 'ampliacion':
        return 'Ampliación';
      default:
        return tipo;
    }
  }

  factory CampaignOffer.fromCredit(Map<String, dynamic> json) {
    final perfil = json['perfiles_clientes'];
    Map<String, dynamic>? pc;
    if (perfil is Map) {
      pc = Map<String, dynamic>.from(perfil);
    }

    final monto = _toDouble(json['saldo_pendiente'] ?? json['monto_aprobado']);
    final segmento = (json['segmento'] as String? ?? '').toUpperCase();
    final tipo = monto >= 8000 || segmento.contains('PLUS')
        ? 'ampliacion'
        : 'renovacion';

    return CampaignOffer(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      clienteNombre: pc == null
          ? 'Cliente'
          : '${pc['nombres'] ?? ''} ${pc['apellidos'] ?? ''}'.trim(),
      dni: pc?['dni'] as String? ?? '',
      tipo: tipo,
      montoOfertado: tipo == 'ampliacion' ? monto * 1.25 : monto,
      diasRestantes: 15 + (monto % 10).round(),
    );
  }

  static double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
