import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/screens/client_detail_screen.dart';
import 'package:fuerza_ventas_app/models/route_stop.dart';
import 'package:fuerza_ventas_app/screens/modules/portfolio_visit_sheet.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class RoutePlanningScreen extends StatefulWidget {
  const RoutePlanningScreen({super.key});

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
  final _service = ClientManagementService();
  List<RouteStop> _stops = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stops = await _service.fetchRouteDay();
      if (!mounted) return;
      setState(() {
        _stops = stops;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la ruta.';
        _loading = false;
      });
    }
  }

  Future<void> _openMaps(RouteStop stop) async {
    final uri = stop.lat != null && stop.lng != null
        ? Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${stop.lat},${stop.lng}',
          )
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${stop.direccion ?? stop.distrito ?? stop.nombreCompleto}, Peru')}',
          );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el mapa.')),
      );
    }
  }

  Future<void> _registerVisit(RouteStop stop) async {
    final ok = await showPortfolioVisitSheet(context, stop: stop);
    if (ok != true || !mounted) return;
    setState(() {
      _stops = _stops.where((s) => s.userId != stop.userId).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Visita de ${stop.nombreCompleto} registrada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planificación de ruta'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _stops.isEmpty
                  ? const Center(child: Text('No hay visitas programadas.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: _stops.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final stop = _stops[index];
                        return Card(
                          color: stop.esNuevaSolicitud
                              ? const Color(0xFFFFF8E6)
                              : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: stop.esNuevaSolicitud
                                  ? Colors.orange.shade100
                                  : const Color(0xFFFFECEB),
                              child: Text(
                                stop.esNuevaSolicitud ? '!' : '${index + 1}',
                                style: TextStyle(
                                  color: stop.esNuevaSolicitud
                                      ? Colors.orange.shade900
                                      : AppColors.brandRed,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              stop.nombreCompleto,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (stop.esNuevaSolicitud) ...[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'NUEVA_SOLICITUD · '
                                      'S/ ${stop.solicitudMonto?.toStringAsFixed(0) ?? '—'} '
                                      '· ${stop.solicitudPlazo ?? '—'} meses',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                                Text(stop.prioridadLabel),
                                Text(
                                  'S/ ${stop.saldoCuenta.toStringAsFixed(2)} saldo cuenta',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                if (stop.distrito != null)
                                  Text('${stop.distrito} · DNI ${stop.dni}'),
                                if (stop.direccion != null)
                                  Text(stop.direccion!),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Registrar visita',
                                  onPressed: () => _registerVisit(stop),
                                  icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: AppColors.brandRed,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Abrir en mapa',
                                  onPressed: () => _openMaps(stop),
                                  icon: const Icon(
                                    Icons.map_outlined,
                                    color: AppColors.brandRed,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ClientDetailScreen(
                                    userId: stop.userId,
                                    solicitudId: stop.solicitudId,
                                    solicitudExpediente: stop.numeroExpediente,
                                    solicitudMonto: stop.solicitudMonto,
                                    solicitudPlazo: stop.solicitudPlazo,
                                    solicitudEstado: stop.solicitudEstado,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
