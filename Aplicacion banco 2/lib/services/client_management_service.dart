import 'package:fuerza_ventas_app/core/supabase/supabase_bootstrap.dart';
import 'package:fuerza_ventas_app/models/bureau_report.dart';
import 'package:fuerza_ventas_app/models/campaign_offer.dart';
import 'package:fuerza_ventas_app/models/captured_document.dart';
import 'package:fuerza_ventas_app/models/collection_item.dart';
import 'package:fuerza_ventas_app/models/credit_application.dart';
import 'package:fuerza_ventas_app/models/pre_eval_result.dart';
import 'package:fuerza_ventas_app/models/productivity_report.dart';
import 'package:fuerza_ventas_app/models/route_stop.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterClientResult {
  const RegisterClientResult({required this.ok, this.userId, this.error});

  final bool ok;
  final String? userId;
  final String? error;

  factory RegisterClientResult.fromJson(Map<String, dynamic> json) {
    return RegisterClientResult(
      ok: json['ok'] == true,
      userId: json['user_id'] as String?,
      error: json['error'] as String?,
    );
  }
}

class CreateAdvisorResult {
  const CreateAdvisorResult({required this.ok, this.codigo, this.error});

  final bool ok;
  final String? codigo;
  final String? error;

  factory CreateAdvisorResult.fromJson(Map<String, dynamic> json) {
    return CreateAdvisorResult(
      ok: json['ok'] == true,
      codigo: json['codigo'] as String?,
      error: json['error'] as String?,
    );
  }
}

class PortfolioVisitResult {
  const PortfolioVisitResult({required this.ok, this.error, this.estadoVisita});

  final bool ok;
  final String? error;
  final String? estadoVisita;

  factory PortfolioVisitResult.fromJson(Map<String, dynamic> json) {
    return PortfolioVisitResult(
      ok: json['ok'] == true,
      error: json['error'] as String?,
      estadoVisita: json['estado_visita'] as String?,
    );
  }
}

class AgencyOption {
  const AgencyOption({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.distrito,
  });

  final int id;
  final String codigo;
  final String nombre;
  final String? distrito;

  factory AgencyOption.fromJson(Map<String, dynamic> json) {
    return AgencyOption(
      id: (json['id'] as num).toInt(),
      codigo: json['codigo'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      distrito: json['distrito'] as String?,
    );
  }
}

class ClientManagementService {
  ClientManagementService({SupabaseClient? client})
      : _client = client ?? SupabaseBootstrap.client;

  final SupabaseClient _client;

  Future<List<RouteStop>> fetchRouteDay() async {
    final raw = await _client.rpc('asesor_get_ruta_dia');
    if (raw == null) return [];

    final data = Map<String, dynamic>.from(raw as Map);
    if (data['ok'] != true) return [];

    final paradas = data['paradas'] as List? ?? [];
    return paradas
        .map((e) => RouteStop.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<PortfolioVisitResult> registerPortfolioVisit({
    required String clienteUserId,
    required String resultado,
    String observacion = '',
  }) async {
    final raw = await _client.rpc(
      'asesor_registrar_visita_cartera',
      params: {
        'p_cliente_user_id': clienteUserId,
        'p_resultado': resultado,
        'p_observacion': observacion,
      },
    );

    final data = Map<String, dynamic>.from(raw as Map);
    final result = PortfolioVisitResult.fromJson(data);
    if (!result.ok) {
      final err = result.error ?? '';
      if (err.contains('asesor_registrar_visita_cartera') ||
          err == 'function_not_found') {
        throw Exception(
          'Ejecuta 33_cartera_visitas_dia.sql en Supabase para registrar visitas.',
        );
      }
    }
    return result;
  }

  Future<bool> attendClientSolicitud(String solicitudId) async {
    final raw = await _client.rpc(
      'asesor_atender_solicitud_cliente',
      params: {'p_solicitud_id': solicitudId},
    );
    final data = Map<String, dynamic>.from(raw as Map);
    return data['ok'] == true;
  }

  Future<SolicitudDecisionResult> respondToSolicitud({
    required String solicitudId,
    required String decision,
    String? observaciones,
    double? montoAjustado,
  }) async {
    final raw = await _client.rpc(
      'asesor_responder_solicitud',
      params: {
        'p_solicitud_id': solicitudId,
        'p_decision': decision,
        'p_observaciones': observaciones,
        'p_monto_ajustado': montoAjustado,
      },
    );
    return SolicitudDecisionResult.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<CreateApplicationResult> createCreditApplication({
    required String userId,
    required double monto,
    required int plazoMeses,
    required String tipoProducto,
    String? proposito,
  }) async {
    final raw = await _client.rpc(
      'asesor_crear_solicitud_credito',
      params: {
        'p_user_id': userId,
        'p_monto': monto,
        'p_plazo_meses': plazoMeses,
        'p_proposito': proposito,
        'p_tipo_producto': tipoProducto,
      },
    );

    return CreateApplicationResult.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<bool> registerDocument({
    required String userId,
    required String tipo,
    String? referencia,
    String? observaciones,
  }) async {
    final raw = await _client.rpc(
      'asesor_registrar_documento',
      params: {
        'p_user_id': userId,
        'p_tipo': tipo,
        'p_referencia': referencia,
        'p_observaciones': observaciones,
      },
    );

    final data = Map<String, dynamic>.from(raw as Map);
    return data['ok'] == true;
  }

  Future<BureauReport?> fetchBureauReport(
    String userId, {
    bool consentimiento = false,
    String? firmaBase64,
  }) async {
    if (consentimiento) {
      final raw = await _client.rpc(
        'asesor_consulta_buro_con_consentimiento',
        params: {
          'p_user_id': userId,
          'p_consentimiento': true,
          'p_firma_base64': firmaBase64,
        },
      );
      if (raw == null) return null;
      final data = Map<String, dynamic>.from(raw as Map);
      if (data['ok'] != true) return null;
      return BureauReport.fromJson(data);
    }

    final raw = await _client.rpc(
      'asesor_consulta_buro',
      params: {'p_user_id': userId},
    );
    if (raw == null) return null;

    final data = Map<String, dynamic>.from(raw as Map);
    if (data['ok'] != true) return null;
    return BureauReport.fromJson(data);
  }

  Future<TransmissionResult> transmitPending() async {
    final raw = await _client.rpc('asesor_transmitir_pendientes');
    return TransmissionResult.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<DisbursementResult> disburseSelected(List<String> solicitudIds) async {
    final raw = await _client.rpc(
      'asesor_desembolsar_solicitudes',
      params: {'p_solicitud_ids': solicitudIds},
    );
    return DisbursementResult.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<List<CreditApplication>> fetchApprovedApplications() async {
    return fetchApplications(estado: 'aprobado');
  }

  Future<List<CreditApplication>> fetchApplications({String? estado}) async {
    try {
      final raw = await _client.rpc(
        'asesor_listar_solicitudes',
        params: {'p_estado': estado ?? 'todas'},
      );
      final data = Map<String, dynamic>.from(raw as Map);
      if (data['ok'] != true) return [];
      final list = data['solicitudes'] as List? ?? [];
      return list
          .map((e) => CreditApplication.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    } catch (_) {
      // Respaldo si el RPC aún no está en Supabase.
      return _fetchApplicationsDirect(estado: estado);
    }
  }

  Future<List<CreditApplication>> _fetchApplicationsDirect({
    String? estado,
  }) async {
    var query = _client.from('solicitudes_prestamo').select(
          'id, user_id, monto, plazo_meses, cuota_mensual, proposito, estado, '
          'tipo_producto, asesor_codigo, created_at, '
          'perfiles_clientes(nombres, apellidos, dni)',
        );

    if (estado != null && estado != 'todas') {
      query = query.eq('estado', estado);
    }

    final rows = await query.order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(CreditApplication.fromJson)
        .toList();
  }

  Future<List<CreditApplication>> fetchPendingApplications() async {
    return fetchApplications(estado: 'pendiente');
  }

  Future<List<CapturedDocument>> fetchPendingDocuments() async {
    final rows = await _client
        .from('documentos_captura')
        .select(
          'id, user_id, tipo, referencia, observaciones, estado, created_at, '
          'perfiles_clientes(nombres, apellidos)',
        )
        .eq('estado', 'capturado')
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(CapturedDocument.fromJson)
        .toList();
  }

  Future<List<CapturedDocument>> fetchClientDocuments(String userId) async {
    final rows = await _client
        .from('documentos_captura')
        .select(
          'id, user_id, tipo, referencia, observaciones, estado, created_at',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(CapturedDocument.fromJson)
        .toList();
  }

  Future<List<CollectionItem>> fetchMoraClients() async {
    final raw = await _client.rpc('asesor_listar_mora_dia');
    if (raw == null) return [];

    final data = Map<String, dynamic>.from(raw as Map);
    if (data['ok'] != true) {
      final code = data['error'] as String? ?? '';
      if (code == 'no_auth') throw Exception('no_auth');
      throw Exception(code.isEmpty ? 'mora_error' : code);
    }

    final items = data['items'] as List? ?? [];
    return items
        .cast<Map<String, dynamic>>()
        .map(CollectionItem.fromRpc)
        .toList();
  }

  Future<CollectionActionResult> registerCollectionAction({
    required String clienteUserId,
    required String tipoGestion,
    required String resultado,
    String? creditoId,
    String? codCuentaCredito,
    double? montoPagado,
    DateTime? fechaCompromiso,
    double? montoCompromiso,
    String observaciones = '',
    double? lat,
    double? lng,
  }) async {
    final raw = await _client.rpc(
      'asesor_registrar_accion_cobranza',
      params: {
        'p_cliente_user_id': clienteUserId,
        'p_tipo_gestion': tipoGestion,
        'p_resultado': resultado,
        'p_credito_id': creditoId,
        'p_cod_cuenta_credito': codCuentaCredito,
        'p_monto_pagado': montoPagado,
        'p_fecha_compromiso': fechaCompromiso != null
            ? fechaCompromiso.toIso8601String().split('T').first
            : null,
        'p_monto_compromiso': montoCompromiso,
        'p_observaciones': observaciones,
        'p_lat': lat,
        'p_lng': lng,
      },
    );

    return CollectionActionResult.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<Map<String, Map<String, dynamic>>> _fetchPerfilesMap(
    List<String> userIds,
  ) async {
    final ids = userIds.toSet().where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return {};

    final rows = await _client
        .from('perfiles_clientes')
        .select('user_id, dni, nombres, apellidos')
        .inFilter('user_id', ids);

    return {
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        row['user_id'] as String: row,
    };
  }

  Future<List<CampaignOffer>> fetchCampaigns() async {
    final rows = await _client
        .from('creditos_preaprobados')
        .select(
          'id, user_id, monto_aprobado, saldo_pendiente, segmento, estado_pago, dias_mora, estado',
        )
        .eq('dias_mora', 0)
        .eq('estado', 'desembolsado')
        .order('monto_aprobado', ascending: false)
        .limit(30);

    final filtered = (rows as List)
        .cast<Map<String, dynamic>>()
        .where((r) => (r['estado_pago'] as String?) == 'al_dia')
        .toList();

    final perfiles = await _fetchPerfilesMap(
      filtered.map((r) => r['user_id'] as String).toList(),
    );

    return filtered
        .map((row) {
          final merged = Map<String, dynamic>.from(row);
          merged['perfiles_clientes'] = perfiles[row['user_id'] as String];
          return CampaignOffer.fromCredit(merged);
        })
        .toList();
  }

  Future<ProductivityReport?> fetchProductivityReport() async {
    final raw = await _client.rpc('asesor_reporte_productividad');
    if (raw == null) return null;

    final data = Map<String, dynamic>.from(raw as Map);
    if (data['ok'] != true) {
      if (data['codigo'] == 403 || data['error'] == 'sin_permiso') {
        throw Exception('sin_permiso');
      }
      return null;
    }

    final reporte = data['reporte'] as List? ?? [];
    if (reporte.isEmpty) {
      return const ProductivityReport(
        nombre: 'Sin datos',
        codigo: '—',
        enviadas: 0,
        aprobadas: 0,
        montoTotal: 0,
        tasaAprobacion: 0,
      );
    }

    final first = Map<String, dynamic>.from(reporte.first as Map);
    final enviadas = (first['enviadas'] as num?)?.toInt() ?? 0;
    final aprobadas = (first['aprobadas'] as num?)?.toInt() ?? 0;
    final monto = _toDouble(first['monto_total']);

    return ProductivityReport(
      nombre: first['asesor_codigo'] as String? ?? 'Equipo',
      codigo: first['asesor_codigo'] as String? ?? '—',
      enviadas: enviadas,
      aprobadas: aprobadas,
      montoTotal: monto,
      tasaAprobacion: enviadas > 0 ? (aprobadas / enviadas) * 100 : 0,
    );
  }

  PreEvalResult preEvaluate({
    required double ingresosEstimados,
    required double montoSolicitado,
  }) {
    if (ingresosEstimados <= 0) {
      return const PreEvalResult(
        calificacion: 'NO_PROCEDE',
        puntaje: 15,
        motivo:
            'No hay ingresos estimados suficientes para evaluar capacidad de pago.',
        ratioCuota: 0,
      );
    }

    final ratio = montoSolicitado / ingresosEstimados;
    if (ratio > 0.5) {
      return PreEvalResult(
        calificacion: 'NO_PROCEDE',
        puntaje: 22,
        motivo:
            'El monto supera el 50% de los ingresos mensuales. No procede por capacidad de pago.',
        ratioCuota: ratio,
      );
    }
    if (ratio > 0.3) {
      return PreEvalResult(
        calificacion: 'REVISAR',
        puntaje: 52,
        motivo:
            'El monto está entre 30% y 50% de los ingresos. Requiere revisión en comité.',
        ratioCuota: ratio,
      );
    }

    return PreEvalResult(
      calificacion: 'APTO',
      puntaje: 78,
      motivo:
          'El monto solicitado es razonable frente a los ingresos declarados.',
      ratioCuota: ratio,
    );
  }

  Future<RegisterClientResult> registerClient({
    required String dni,
    required String nombres,
    required String apellidos,
    String? telefono,
    String? nombreNegocio,
    String? distrito,
    String? direccionNegocio,
    double? lat,
    double? lng,
    int? antiguedadMeses,
    double? ingresosMensuales,
    double? gastosMensuales,
    String? password,
  }) async {
    final dniNorm = _normalizeDni(dni);
    final params = {
      'p_dni': dniNorm,
      'p_nombres': nombres,
      'p_apellidos': apellidos,
      'p_telefono': telefono,
      'p_nombre_negocio': nombreNegocio,
      'p_distrito': distrito,
      'p_direccion_negocio': direccionNegocio,
      'p_lat_negocio': lat,
      'p_lng_negocio': lng,
      'p_antiguedad_meses': antiguedadMeses,
      'p_ingresos_mensuales': ingresosMensuales,
      'p_gastos_mensuales': gastosMensuales,
      'p_password': password,
    };

    try {
      final raw = await _client.rpc('asesor_registrar_cliente', params: params);
      return RegisterClientResult.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      return _registerClientFallback(
        dniNorm: dniNorm,
        nombres: nombres,
        apellidos: apellidos,
        telefono: telefono,
        nombreNegocio: nombreNegocio,
        distrito: distrito,
        direccionNegocio: direccionNegocio,
        lat: lat,
        lng: lng,
        antiguedadMeses: antiguedadMeses,
        ingresosMensuales: ingresosMensuales,
        gastosMensuales: gastosMensuales,
        password: password,
      );
    }
  }

  Future<RegisterClientResult> _registerClientFallback({
    required String dniNorm,
    required String nombres,
    required String apellidos,
    String? telefono,
    String? nombreNegocio,
    String? distrito,
    String? direccionNegocio,
    double? lat,
    double? lng,
    int? antiguedadMeses,
    double? ingresosMensuales,
    double? gastosMensuales,
    String? password,
  }) async {
    final resumenRaw = await _client.rpc('get_resumen_cartera_asesor');
    final resumen = Map<String, dynamic>.from(resumenRaw as Map);
    if (resumen['ok'] != true) {
      return const RegisterClientResult(
        ok: false,
        error: 'asesor_no_autenticado',
      );
    }

    final raw = await _client.rpc(
      'cliente_registrarse',
      params: {
        'p_dni': dniNorm,
        'p_nombres': nombres,
        'p_apellidos': apellidos,
        'p_password': password ?? 'Cliente2026!',
        'p_telefono': telefono,
        'p_nombre_negocio': nombreNegocio,
        'p_distrito': distrito,
        'p_direccion_negocio': direccionNegocio,
        'p_antiguedad_meses': antiguedadMeses,
        'p_ingresos_mensuales': ingresosMensuales,
        'p_gastos_mensuales': gastosMensuales,
        'p_asesor_codigo': resumen['codigo'],
      },
    );

    final result = RegisterClientResult.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );

    if (result.ok &&
        result.userId != null &&
        lat != null &&
        lng != null &&
        direccionNegocio != null) {
      try {
        await updateClientAddress(
          userId: result.userId!,
          direccion: direccionNegocio,
          distrito: distrito,
          lat: lat,
          lng: lng,
        );
      } catch (_) {
        // Sin RPC de ubicación; el cliente ya quedó registrado.
      }
    }

    return result;
  }

  static bool _isMissingRpc(PostgrestException e) {
    final msg = e.message.toLowerCase();
    return e.code == 'PGRST202' ||
        msg.contains('could not find the function') ||
        msg.contains('function') && msg.contains('does not exist');
  }

  static String _normalizeDni(String dni) {
    final digits = dni.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return dni.trim();
    return digits.padLeft(8, '0');
  }

  Future<bool> updateClientAddress({
    required String userId,
    required String direccion,
    String? distrito,
    required double lat,
    required double lng,
  }) async {
    final raw = await _client.rpc(
      'asesor_actualizar_direccion_cliente',
      params: {
        'p_user_id': userId,
        'p_direccion_negocio': direccion,
        'p_distrito': distrito,
        'p_lat_negocio': lat,
        'p_lng_negocio': lng,
      },
    );
    final data = Map<String, dynamic>.from(raw as Map);
    return data['ok'] == true;
  }

  Future<List<AgencyOption>> listAgencies() async {
    final raw = await _client.rpc('admin_listar_agencias');
    final data = Map<String, dynamic>.from(raw as Map);
    if (data['ok'] != true) {
      throw Exception(data['error'] as String? ?? 'sin_permiso');
    }
    final list = data['agencias'] as List? ?? [];
    return list
        .map((e) => AgencyOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CreateAdvisorResult> createAdvisor({
    required String codigo,
    required String nombres,
    required String apellidos,
    required String email,
    required int idAgencia,
    required String nivel,
    required String perfil,
    required String password,
    String? telefono,
    String? dni,
  }) async {
    final raw = await _client.rpc(
      'admin_crear_asesor',
      params: {
        'p_codigo': codigo,
        'p_nombres': nombres,
        'p_apellidos': apellidos,
        'p_email': email,
        'p_id_agencia': idAgencia,
        'p_nivel': nivel,
        'p_perfil': perfil,
        'p_password': password,
        'p_telefono': telefono,
        'p_dni': dni,
      },
    );
    return CreateAdvisorResult.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  static double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
