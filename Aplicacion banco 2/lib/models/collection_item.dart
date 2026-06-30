class CollectionActionResult {
  const CollectionActionResult({
    required this.ok,
    this.accionId,
    this.error,
  });

  final bool ok;
  final String? accionId;
  final String? error;

  factory CollectionActionResult.fromJson(Map<String, dynamic> json) {
    return CollectionActionResult(
      ok: json['ok'] == true,
      accionId: json['accion_id'] as String?,
      error: json['error'] as String?,
    );
  }
}

class CollectionItem {
  const CollectionItem({
    required this.id,
    required this.userId,
    required this.clienteNombre,
    required this.dni,
    required this.diasMora,
    required this.montoVencido,
    this.telefono,
    this.codCuentaCredito,
    this.creditoId,
  });

  final String id;
  final String userId;
  final String clienteNombre;
  final String dni;
  final int diasMora;
  final double montoVencido;
  final String? telefono;
  final String? codCuentaCredito;
  final String? creditoId;

  factory CollectionItem.fromRpc(Map<String, dynamic> json) {
    return CollectionItem(
      id: json['id'] as String? ?? json['credito_id'] as String? ?? '',
      userId: json['cliente_id'] as String? ?? '',
      clienteNombre: json['cliente_nombre'] as String? ?? 'Cliente',
      dni: json['documento'] as String? ?? '',
      telefono: json['telefono'] as String?,
      diasMora: (json['dias_mora'] as num?)?.toInt() ?? 0,
      montoVencido: _toDouble(json['monto_vencido']),
      codCuentaCredito: json['cod_cuenta_credito'] as String?,
      creditoId: json['credito_id'] as String?,
    );
  }

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    final perfil = json['perfiles_clientes'];
    Map<String, dynamic>? pc;
    if (perfil is Map) {
      pc = Map<String, dynamic>.from(perfil);
    }

    final cuota = _toDouble(json['cuota_mensual']);
    final monto = _toDouble(json['monto_aprobado']);

    return CollectionItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      clienteNombre: pc == null
          ? 'Cliente'
          : '${pc['nombres'] ?? ''} ${pc['apellidos'] ?? ''}'.trim(),
      dni: pc?['dni'] as String? ?? '',
      telefono: pc?['telefono'] as String?,
      diasMora: json['dias_mora'] as int? ?? 0,
      montoVencido: cuota > 0 ? cuota : monto,
    );
  }

  static double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
