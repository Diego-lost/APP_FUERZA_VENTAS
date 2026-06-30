import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/models/route_stop.dart';
import 'package:fuerza_ventas_app/screens/client_detail_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/portfolio_visit_sheet.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';

class CarteraDiaScreen extends StatefulWidget {
  const CarteraDiaScreen({super.key});

  @override
  State<CarteraDiaScreen> createState() => _CarteraDiaScreenState();
}

class _CarteraDiaScreenState extends State<CarteraDiaScreen> {
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _registerVisit(RouteStop stop) async {
    final ok = await showPortfolioVisitSheet(context, stop: stop);
    if (ok != true || !mounted) return;
    setState(() {
      _stops = _stops.where((s) => s.userId != stop.userId).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Visita de ${stop.nombreCompleto} registrada. Ya no aparece en la cartera de hoy.',
        ),
      ),
    );
  }

  Color _prioColor(String nivel) {
    switch (nivel) {
      case 'alta':
        return Colors.red.shade700;
      case 'media':
        return Colors.amber.shade800;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _stops.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartera del día'),
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      child: Text(
                        '${_stops.length} clientes asignados · $pendientes pendientes de visita',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _stops.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No hay clientes pendientes en tu cartera de hoy.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(14),
                              itemCount: _stops.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, index) {
                                final stop = _stops[index];
                                final prio = stop.prioridadNivel;
                                return Card(
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          width: 4,
                                          decoration: BoxDecoration(
                                            color: _prioColor(prio),
                                            borderRadius:
                                                const BorderRadius.horizontal(
                                              left: Radius.circular(18),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  stop.nombreCompleto,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'DNI ${stop.dni} · ${stop.tipoGestionLabel} · score ${stop.prioridad}',
                                                  style: const TextStyle(
                                                    color: AppColors.muted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: [
                                                    _Badge(
                                                      label:
                                                          'Prioridad ${prio[0].toUpperCase()}${prio.substring(1)}',
                                                      color: _prioColor(prio),
                                                    ),
                                                    _Badge(
                                                      label: 'Pendiente',
                                                      color:
                                                          Colors.amber.shade800,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  'S/ ${stop.saldoCuenta.toStringAsFixed(2)} saldo cuenta',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                if ((stop.solicitudMonto ?? 0) >
                                                    0)
                                                  Text(
                                                    'S/ ${stop.solicitudMonto!.toStringAsFixed(2)} solicitud',
                                                    style: const TextStyle(
                                                      color: AppColors.muted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    OutlinedButton.icon(
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .push(
                                                          MaterialPageRoute<
                                                              void>(
                                                            builder: (_) =>
                                                                ClientDetailScreen(
                                                              userId:
                                                                  stop.userId,
                                                              solicitudId: stop
                                                                  .solicitudId,
                                                              solicitudExpediente:
                                                                  stop.numeroExpediente,
                                                              solicitudMonto: stop
                                                                  .solicitudMonto,
                                                              solicitudPlazo: stop
                                                                  .solicitudPlazo,
                                                              solicitudEstado: stop
                                                                  .solicitudEstado,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      icon: const Icon(
                                                        Icons.description_outlined,
                                                        size: 18,
                                                      ),
                                                      label: const Text('Ficha'),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    FilledButton.icon(
                                                      onPressed: () =>
                                                          _registerVisit(stop),
                                                      style:
                                                          FilledButton.styleFrom(
                                                        backgroundColor:
                                                            AppColors.brandRed,
                                                      ),
                                                      icon: const Icon(
                                                        Icons
                                                            .check_circle_outline_rounded,
                                                        size: 18,
                                                      ),
                                                      label: const Text(
                                                        'Registrar',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
