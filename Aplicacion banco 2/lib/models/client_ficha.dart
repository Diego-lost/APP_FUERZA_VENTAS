import 'package:fuerza_ventas_app/models/bureau_report.dart';
import 'package:fuerza_ventas_app/models/captured_document.dart';
import 'package:fuerza_ventas_app/models/credit_application.dart';
class ClientFicha {
  const ClientFicha({
    required this.cliente,
    required this.posicion,
    required this.historial,
    required this.cuentas,
    required this.transacciones,
    required this.solicitudes,
    required this.documentos,
    this.oferta,
    this.buro,
    this.fichaCampo,
  });

  final ClientProfileData cliente;
  final ClientPosition posicion;
  final List<CreditHistoryItem> historial;
  final List<AccountSummary> cuentas;
  final List<TransactionItem> transacciones;
  final List<CreditApplication> solicitudes;
  final List<CapturedDocument> documentos;
  final PreApprovedOffer? oferta;
  final BureauReport? buro;
  final FieldVisitSummary? fichaCampo;
}

class ClientProfileData {
  const ClientProfileData({
    required this.userId,
    required this.dni,
    required this.nombres,
    required this.apellidos,
    this.telefono,
    this.distrito,
    this.provincia,
    this.departamento,
    this.edad,
    this.tipoNegocio,
    this.nombreNegocio,
    this.direccionNegocio,
    this.latNegocio,
    this.lngNegocio,
    this.antiguedadNegocioMeses,
    this.tenenciaLocal,
    this.calificacionSbs,
    this.entidadesSbs,
    this.deudaTotalSbs,
    this.estadoCliente,
  });

  final String userId;
  final String dni;
  final String nombres;
  final String apellidos;
  final String? telefono;
  final String? distrito;
  final String? provincia;
  final String? departamento;
  final int? edad;
  final String? tipoNegocio;
  final String? nombreNegocio;
  final String? direccionNegocio;
  final double? latNegocio;
  final double? lngNegocio;
  final int? antiguedadNegocioMeses;
  final String? tenenciaLocal;
  final String? calificacionSbs;
  final int? entidadesSbs;
  final double? deudaTotalSbs;
  final String? estadoCliente;

  String get nombreCompleto => '$nombres $apellidos';

  factory ClientProfileData.fromJson(Map<String, dynamic> json) {
    return ClientProfileData(
      userId: json['user_id'] as String,
      dni: json['dni'] as String? ?? '',
      nombres: json['nombres'] as String? ?? '',
      apellidos: json['apellidos'] as String? ?? '',
      telefono: json['telefono'] as String?,
      distrito: json['distrito'] as String?,
      provincia: json['provincia'] as String?,
      departamento: json['departamento'] as String?,
      edad: json['edad'] as int?,
      tipoNegocio: json['tipo_negocio'] as String?,
      nombreNegocio: json['nombre_negocio'] as String?,
      direccionNegocio: json['direccion_negocio'] as String?,
      latNegocio: _toDoubleOrNull(json['lat_negocio']),
      lngNegocio: _toDoubleOrNull(json['lng_negocio']),
      antiguedadNegocioMeses: json['antiguedad_negocio_meses'] as int?,
      tenenciaLocal: json['tenencia_local'] as String?,
      calificacionSbs: json['calificacion_sbs'] as String?,
      entidadesSbs: json['num_entidades_sbs'] as int?,
      deudaTotalSbs: _toDoubleOrNull(json['deuda_total_sbs']),
      estadoCliente: json['estado_cliente'] as String?,
    );
  }

  static double? _toDoubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class ClientPosition {
  const ClientPosition({
    required this.deudaTotal,
    required this.cuentasVigentes,
    required this.cuentasMora,
    required this.diasMayorMora,
    required this.saldoTotal,
  });

  final double deudaTotal;
  final int cuentasVigentes;
  final int cuentasMora;
  final int diasMayorMora;
  final double saldoTotal;
}

class CreditHistoryItem {
  const CreditHistoryItem({
    required this.id,
    required this.producto,
    required this.segmento,
    required this.montoAprobado,
    required this.cuotaMensual,
    required this.plazoMeses,
    required this.estado,
    this.saldoPendiente,
    this.cuotasPagadas = 0,
    this.estadoPago,
    this.diasMora = 0,
    this.tea,
  });

  final String id;
  final String producto;
  final String segmento;
  final double montoAprobado;
  final double cuotaMensual;
  final int plazoMeses;
  final String estado;
  final double? saldoPendiente;
  final int cuotasPagadas;
  final String? estadoPago;
  final int diasMora;
  final double? tea;

  factory CreditHistoryItem.fromJson(Map<String, dynamic> json) {
    return CreditHistoryItem(
      id: json['id'] as String,
      producto: json['tipo_producto'] as String? ??
          json['segmento'] as String? ??
          'Crédito',
      segmento: json['segmento'] as String? ?? 'SURGIR',
      montoAprobado: _toDouble(json['monto_aprobado']),
      cuotaMensual: _toDouble(json['cuota_mensual']),
      plazoMeses: json['plazo_meses'] as int? ?? 0,
      estado: json['estado'] as String? ?? 'vigente',
      saldoPendiente: _toDoubleOrNull(json['saldo_pendiente']),
      cuotasPagadas: json['cuotas_pagadas'] as int? ?? 0,
      estadoPago: json['estado_pago'] as String?,
      diasMora: json['dias_mora'] as int? ?? 0,
      tea: _toDoubleOrNull(json['tasa_tea'] ?? json['tea']),
    );
  }

  static double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static double? _toDoubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class PreApprovedOffer {
  const PreApprovedOffer({
    required this.montoMaximo,
    required this.plazoMeses,
    required this.teaReferencial,
    this.scoreConfianza,
  });

  final double montoMaximo;
  final int plazoMeses;
  final double teaReferencial;
  final int? scoreConfianza;
}

class AccountSummary {
  const AccountSummary({
    required this.id,
    required this.tipo,
    required this.numeroCuenta,
    required this.saldo,
    required this.moneda,
  });

  final String id;
  final String tipo;
  final String numeroCuenta;
  final double saldo;
  final String moneda;

  factory AccountSummary.fromJson(Map<String, dynamic> json) {
    return AccountSummary(
      id: json['id'] as String,
      tipo: json['tipo'] as String? ?? 'ahorro',
      numeroCuenta: json['numero_cuenta'] as String? ?? '—',
      saldo: _toDouble(json['saldo']),
      moneda: json['moneda'] as String? ?? 'PEN',
    );
  }

  static double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.monto,
    required this.fecha,
  });

  final String id;
  final String tipo;
  final String descripcion;
  final double monto;
  final DateTime? fecha;

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] as String,
      tipo: json['tipo'] as String? ?? 'debito',
      descripcion: json['descripcion'] as String? ?? '',
      monto: _toDouble(json['monto']),
      fecha: json['fecha'] != null
          ? DateTime.tryParse(json['fecha'] as String)
          : null,
    );
  }

  static double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class FieldVisitSummary {
  const FieldVisitSummary({
    required this.asesorNombre,
    required this.agencia,
    required this.fechaVisita,
    required this.scoreCampo,
    required this.scoreFinal,
    required this.segmentoResultante,
    this.recomendacionAsesor,
    this.estadoFicha,
    this.montoAprobadoPropuesto,
  });

  final String? asesorNombre;
  final String? agencia;
  final DateTime? fechaVisita;
  final int? scoreCampo;
  final int? scoreFinal;
  final String? segmentoResultante;
  final String? recomendacionAsesor;
  final String? estadoFicha;
  final double? montoAprobadoPropuesto;

  factory FieldVisitSummary.fromJson(Map<String, dynamic> json) {
    return FieldVisitSummary(
      asesorNombre: json['asesor_nombre'] as String?,
      agencia: json['agencia'] as String?,
      fechaVisita: json['fecha_visita'] != null
          ? DateTime.tryParse(json['fecha_visita'] as String)
          : null,
      scoreCampo: json['score_campo'] as int?,
      scoreFinal: json['score_final'] as int?,
      segmentoResultante: json['segmento_resultante'] as String?,
      recomendacionAsesor: json['recomendacion_asesor'] as String?,
      estadoFicha: json['estado_ficha'] as String?,
      montoAprobadoPropuesto: _toDoubleOrNull(json['monto_aprobado_propuesto']),
    );
  }

  static double? _toDoubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
