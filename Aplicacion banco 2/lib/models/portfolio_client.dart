import 'package:fuerza_ventas_app/models/route_stop.dart';

class PortfolioClient {
  const PortfolioClient({
    required this.userId,
    required this.dni,
    required this.nombres,
    required this.apellidos,
    this.telefono,
    this.distrito,
    this.tipoNegocio,
    this.nombreNegocio,
    this.direccionNegocio,
    this.saldoCuenta,
    this.segmento,
    this.estadoPago,
    this.diasMora = 0,
    this.prioridad = 0,
    this.tipoGestion,
    this.solicitudMonto,
    this.estadoVisita = 'pendiente',
    this.solicitudId,
    this.numeroExpediente,
    this.solicitudPlazo,
    this.solicitudEstado,
  });

  final String userId;
  final String dni;
  final String nombres;
  final String apellidos;
  final String? telefono;
  final String? distrito;
  final String? tipoNegocio;
  final String? nombreNegocio;
  final String? direccionNegocio;
  final double? saldoCuenta;
  final String? segmento;
  final String? estadoPago;
  final int diasMora;
  final int prioridad;
  final String? tipoGestion;
  final double? solicitudMonto;
  final String estadoVisita;
  final String? solicitudId;
  final String? numeroExpediente;
  final int? solicitudPlazo;
  final String? solicitudEstado;

  String get prioridadLabel {
    if (diasMora > 30) return 'Urgente';
    if (diasMora > 0) return 'En mora';
    if (estadoPago != null && estadoPago != 'al_dia') return 'Seguimiento';
    return 'Al día';
  }

  factory PortfolioClient.fromRouteStop(RouteStop stop) {
    final parts = stop.nombreCompleto.split(' ');
    final nombres = parts.isNotEmpty ? parts.first : '';
    final apellidos =
        parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return PortfolioClient(
      userId: stop.userId,
      dni: stop.dni,
      nombres: nombres,
      apellidos: apellidos,
      telefono: stop.telefono,
      distrito: stop.distrito,
      direccionNegocio: stop.direccion,
      saldoCuenta: stop.saldoCuenta,
      estadoPago: stop.estadoPago,
      diasMora: stop.diasMora,
      prioridad: stop.prioridad,
      tipoGestion: stop.tipoGestion,
      solicitudMonto: stop.solicitudMonto,
      estadoVisita: stop.estadoVisita,
      solicitudId: stop.solicitudId,
      numeroExpediente: stop.numeroExpediente,
      solicitudPlazo: stop.solicitudPlazo,
      solicitudEstado: stop.solicitudEstado,
    );
  }

  String get nombreCompleto => '$nombres $apellidos';

  factory PortfolioClient.fromJson(Map<String, dynamic> json) {
    final creditos = json['creditos_preaprobados'];
    Map<String, dynamic>? credito;
    if (creditos is List && creditos.isNotEmpty) {
      credito = Map<String, dynamic>.from(creditos.first as Map);
    }

    final cuentas = json['cuentas'];
    double? saldo;
    if (cuentas is List && cuentas.isNotEmpty) {
      final cuenta = cuentas.first as Map;
      saldo = _toDouble(cuenta['saldo']);
    }

    return PortfolioClient(
      userId: json['user_id'] as String,
      dni: json['dni'] as String? ?? '',
      nombres: json['nombres'] as String? ?? '',
      apellidos: json['apellidos'] as String? ?? '',
      telefono: json['telefono'] as String?,
      distrito: json['distrito'] as String?,
      tipoNegocio: json['tipo_negocio'] as String?,
      saldoCuenta: saldo,
      segmento: credito?['segmento'] as String?,
      estadoPago: credito?['estado_pago'] as String?,
      diasMora: credito?['dias_mora'] as int? ?? 0,
    );
  }

  static double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class ClientCreditDetail {
  const ClientCreditDetail({
    required this.id,
    required this.segmento,
    required this.montoAprobado,
    required this.cuotaMensual,
    required this.plazoMeses,
    required this.estado,
    this.tipoProducto,
    this.estadoPago,
    this.diasMora = 0,
  });

  final String id;
  final String segmento;
  final double montoAprobado;
  final double cuotaMensual;
  final int plazoMeses;
  final String estado;
  final String? tipoProducto;
  final String? estadoPago;
  final int diasMora;

  factory ClientCreditDetail.fromJson(Map<String, dynamic> json) {
    return ClientCreditDetail(
      id: json['id'] as String,
      segmento: json['segmento'] as String? ?? 'SURGIR',
      montoAprobado: _toDouble(json['monto_aprobado']),
      cuotaMensual: _toDouble(json['cuota_mensual']),
      plazoMeses: json['plazo_meses'] as int? ?? 0,
      estado: json['estado'] as String? ?? 'preaprobado',
      tipoProducto: json['tipo_producto'] as String?,
      estadoPago: json['estado_pago'] as String?,
      diasMora: json['dias_mora'] as int? ?? 0,
    );
  }

  static double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
