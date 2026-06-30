import 'package:fuerza_ventas_app/core/supabase/supabase_bootstrap.dart';

import 'package:fuerza_ventas_app/models/advisor_profile.dart';

import 'package:fuerza_ventas_app/models/bureau_report.dart';

import 'package:fuerza_ventas_app/models/captured_document.dart';

import 'package:fuerza_ventas_app/models/client_ficha.dart';

import 'package:fuerza_ventas_app/models/credit_application.dart';

import 'package:fuerza_ventas_app/models/portfolio_client.dart';

import 'package:fuerza_ventas_app/models/route_stop.dart';

import 'package:supabase_flutter/supabase_flutter.dart';



class AdvisorDataService {

  AdvisorDataService({SupabaseClient? client})

      : _client = client ?? SupabaseBootstrap.client;



  final SupabaseClient _client;



  Future<AdvisorProfile?> fetchResumen() async {

    final raw = await _client.rpc('get_resumen_cartera_asesor');

    if (raw == null) return null;



    final data = Map<String, dynamic>.from(raw as Map);

    if (data['ok'] != true) return null;

    return AdvisorProfile.fromResumen(data);

  }



  /// Cartera del asesor vía RPC (misma fuente que ruta y portal web).

  Future<List<PortfolioClient>> fetchPortfolio() async {

    final raw = await _client.rpc('asesor_get_ruta_dia');

    if (raw != null) {

      final data = Map<String, dynamic>.from(raw as Map);

      if (data['ok'] == true) {

        final paradas = data['paradas'] as List? ?? [];

        if (paradas.isNotEmpty) {

          return paradas

              .map((e) => PortfolioClient.fromRouteStop(

                    RouteStop.fromJson(

                      Map<String, dynamic>.from(e as Map),

                    ),

                  ))

              .toList();

        }

      }

    }



    final rows = await _client

        .from('perfiles_clientes')

        .select(

          'user_id, dni, nombres, apellidos, telefono, distrito, tipo_negocio, '

          'nombre_negocio, direccion_negocio, lat_negocio, lng_negocio, '

          'cuentas(saldo), '

          'creditos_preaprobados(segmento, estado_pago, dias_mora)',

        )

        .order('apellidos');



    return (rows as List)

        .cast<Map<String, dynamic>>()

        .map(PortfolioClient.fromJson)

        .toList();

  }



  Future<PortfolioClient?> fetchClient(String userId) async {

    final row = await _client

        .from('perfiles_clientes')

        .select(

          'user_id, dni, nombres, apellidos, telefono, distrito, tipo_negocio, '

          'nombre_negocio, direccion_negocio, lat_negocio, lng_negocio, '

          'cuentas(saldo), '

          'creditos_preaprobados(segmento, estado_pago, dias_mora)',

        )

        .eq('user_id', userId)

        .maybeSingle();



    if (row == null) return null;

    return PortfolioClient.fromJson(row);

  }



  Future<ClientFicha?> fetchClientFicha(String userId) async {

    final perfil = await _client

        .from('perfiles_clientes')

        .select('*')

        .eq('user_id', userId)

        .maybeSingle();



    if (perfil == null) return null;



    final results = await Future.wait([

      _client

          .from('creditos_preaprobados')

          .select(

            'id, segmento, tipo_producto, monto_aprobado, saldo_pendiente, cuotas_pagadas, '
            'cuota_mensual, plazo_meses, estado, estado_pago, dias_mora, tasa_tea, created_at',

          )

          .eq('user_id', userId)

          .order('created_at', ascending: false),

      _client

          .from('cuentas')

          .select('id, tipo, numero_cuenta, saldo, moneda')

          .eq('user_id', userId)

          .order('created_at'),

      _client

          .from('transacciones')

          .select('id, tipo, descripcion, monto, fecha')

          .eq('user_id', userId)

          .order('fecha', ascending: false)

          .limit(20),

      _client

          .from('solicitudes_prestamo')

          .select(

            'id, user_id, monto, plazo_meses, cuota_mensual, proposito, estado, '

            'tipo_producto, asesor_codigo, created_at',

          )

          .eq('user_id', userId)

          .order('created_at', ascending: false),

      _client

          .from('documentos_captura')

          .select('id, user_id, tipo, referencia, observaciones, estado, created_at')

          .eq('user_id', userId)

          .order('created_at', ascending: false),

      _client

          .from('fichas_campo')

          .select(

            'asesor_nombre, agencia, fecha_visita, score_campo, score_final, '

            'segmento_resultante, recomendacion_asesor, estado_ficha, '

            'monto_aprobado_propuesto',

          )

          .eq('user_id', userId)

          .order('fecha_visita', ascending: false)

          .limit(1)

          .maybeSingle(),

    ]);

    dynamic buroRaw;
    try {
      buroRaw = await _client.rpc(
        'asesor_consulta_buro',
        params: {'p_user_id': userId},
      );
    } catch (_) {
      buroRaw = null;
    }



    final creditos = (results[0] as List).cast<Map<String, dynamic>>();

    final cuentas = (results[1] as List).cast<Map<String, dynamic>>();

    final transacciones = (results[2] as List).cast<Map<String, dynamic>>();

    final solicitudes = (results[3] as List).cast<Map<String, dynamic>>();

    final documentos = (results[4] as List).cast<Map<String, dynamic>>();

    final fichaCampoRaw = results[5] as Map<String, dynamic>?;



    final historial =

        creditos.map(CreditHistoryItem.fromJson).toList();

    final activos = historial.where((c) => c.estado == 'desembolsado').toList();

    final deudaActiva = activos.fold<double>(

      0,

      (sum, c) => sum + (c.saldoPendiente ?? c.montoAprobado),

    );

    final enMora = historial.where((c) => c.diasMora > 0).toList();

    final maxMora =

        historial.fold<int>(0, (m, c) => c.diasMora > m ? c.diasMora : m);

    final saldoTotal = cuentas.fold<double>(

      0,

      (sum, c) => sum + _toDouble(c['saldo']),

    );



    BureauReport? buro;

    if (buroRaw != null) {

      final data = Map<String, dynamic>.from(buroRaw as Map);

      if (data['ok'] == true) {

        buro = BureauReport.fromJson(data);

      }

    }



    final cliente = ClientProfileData.fromJson(perfil);

    CreditHistoryItem? vigente;
    for (final c in activos) {
      vigente = c;
      break;
    }
    if (vigente == null) {
      for (final c in historial) {
        if (c.estado == 'vigente' || c.estado == 'aprobado') {
          vigente = c;
          break;
        }
      }
    }
    vigente ??= historial.isNotEmpty ? historial.first : null;



    return ClientFicha(

      cliente: cliente,

      posicion: ClientPosition(

        deudaTotal: deudaActiva > 0
            ? deudaActiva
            : (cliente.deudaTotalSbs ?? buro?.deudaTotalSbs ?? 0),

        cuentasVigentes: historial.where((c) => c.diasMora == 0).length,

        cuentasMora: enMora.length,

        diasMayorMora: maxMora,

        saldoTotal: saldoTotal,

      ),

      historial: historial,

      cuentas: cuentas.map(AccountSummary.fromJson).toList(),

      transacciones: transacciones.map(TransactionItem.fromJson).toList(),

      solicitudes: solicitudes.map(CreditApplication.fromJson).toList(),

      documentos: documentos.map(CapturedDocument.fromJson).toList(),

      oferta: vigente != null

          ? PreApprovedOffer(

              montoMaximo: vigente.saldoPendiente ?? vigente.montoAprobado,

              plazoMeses: vigente.plazoMeses,

              teaReferencial: _teaPorcentaje(vigente.tea),

              scoreConfianza: buro?.scoreTransaccional,

            )

          : null,

      buro: buro,

      fichaCampo: fichaCampoRaw != null

          ? FieldVisitSummary.fromJson(fichaCampoRaw)

          : null,

    );

  }



  Future<List<ClientCreditDetail>> fetchClientCredits(String userId) async {

    final rows = await _client

        .from('creditos_preaprobados')

        .select(

          'id, segmento, tipo_producto, monto_aprobado, saldo_pendiente, cuotas_pagadas, '
          'cuota_mensual, plazo_meses, estado, estado_pago, dias_mora',

        )

        .eq('user_id', userId)

        .order('created_at', ascending: false);



    return (rows as List)

        .cast<Map<String, dynamic>>()

        .map(ClientCreditDetail.fromJson)

        .toList();

  }



  Future<double?> fetchClientBalance(String userId) async {

    final row = await _client

        .from('cuentas')

        .select('saldo')

        .eq('user_id', userId)

        .order('created_at')

        .limit(1)

        .maybeSingle();



    if (row == null) return null;

    return _toDouble(row['saldo']);

  }



  static double _toDouble(Object? value) {

    if (value == null) return 0;

    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;

  }

  static double _teaPorcentaje(double? tea) {

    final v = tea ?? 0.6;

    return v < 1 ? v * 100 : v;

  }

}


