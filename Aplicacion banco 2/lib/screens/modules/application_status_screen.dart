import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/screens/client_detail_screen.dart';
import 'package:fuerza_ventas_app/models/credit_application.dart';
import 'package:fuerza_ventas_app/screens/modules/solicitud_decision_sheet.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';

class ApplicationStatusScreen extends StatefulWidget {
  const ApplicationStatusScreen({super.key});

  @override
  State<ApplicationStatusScreen> createState() =>
      _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> {
  final _service = ClientManagementService();
  List<CreditApplication> _applications = [];
  bool _loading = true;
  String? _error;
  String _filter = 'todas';

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
      final apps = await _service.fetchApplications();
      if (!mounted) return;
      setState(() {
        _applications = apps;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las solicitudes.';
        _loading = false;
      });
    }
  }

  List<CreditApplication> get _filtered {
    if (_filter == 'todas') return _applications;
    return _applications.where((a) => a.estado == _filter).toList();
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'enviado':
        return Colors.deepOrange;
      case 'pendiente':
        return Colors.orange;
      case 'en_comite':
        return Colors.blue;
      case 'aprobado':
      case 'desembolsado':
      case 'completado':
        return Colors.green;
      case 'rechazado':
        return Colors.red;
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de solicitudes'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Todas',
                  selected: _filter == 'todas',
                  onTap: () => setState(() => _filter = 'todas'),
                ),
                _FilterChip(
                  label: 'Enviado',
                  selected: _filter == 'enviado',
                  onTap: () => setState(() => _filter = 'enviado'),
                ),
                _FilterChip(
                  label: 'Pendiente',
                  selected: _filter == 'pendiente',
                  onTap: () => setState(() => _filter = 'pendiente'),
                ),
                _FilterChip(
                  label: 'En comité',
                  selected: _filter == 'en_comite',
                  onTap: () => setState(() => _filter = 'en_comite'),
                ),
                _FilterChip(
                  label: 'Aprobado',
                  selected: _filter == 'aprobado',
                  onTap: () => setState(() => _filter = 'aprobado'),
                ),
                _FilterChip(
                  label: 'Desembolsado',
                  selected: _filter == 'desembolsado',
                  onTap: () => setState(() => _filter = 'desembolsado'),
                ),
                _FilterChip(
                  label: 'Rechazado',
                  selected: _filter == 'rechazado',
                  onTap: () => setState(() => _filter = 'rechazado'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : filtered.isEmpty
                        ? const Center(
                            child: Text('No hay solicitudes en este estado.'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final app = filtered[index];
                              return Card(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ClientDetailScreen(
                                          userId: app.userId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                app.clienteNombre ??
                                                    'Cliente',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Chip(
                                              label: Text(
                                                app.estadoLabel,
                                                style: TextStyle(
                                                  color: _estadoColor(
                                                    app.estado,
                                                  ),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              backgroundColor: _estadoColor(
                                                app.estado,
                                              ).withValues(alpha: 0.12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'DNI ${app.clienteDni ?? '—'} · '
                                          'S/ ${app.monto.toStringAsFixed(2)} · '
                                          '${app.plazoMeses} meses',
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                          ),
                                        ),
                                        if (app.proposito != null) ...[
                                          const SizedBox(height: 4),
                                          Text(app.proposito!),
                                        ],
                                        const SizedBox(height: 8),
                                        _Timeline(estado: app.estado),
                                        if (app.estado == 'enviado' ||
                                            app.estado == 'pendiente') ...[
                                          const SizedBox(height: 10),
                                          FilledButton.icon(
                                            onPressed: () async {
                                              final ok =
                                                  await showSolicitudDecisionSheet(
                                                context,
                                                solicitud: app,
                                              );
                                              if (ok == true) _load();
                                            },
                                            icon: const Icon(
                                              Icons.gavel_outlined,
                                              size: 18,
                                            ),
                                            label: const Text('Evaluar'),
                                          ),
                                        ],
                                      ],
                                    ),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFFFFECEB),
        checkmarkColor: AppColors.brandRed,
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.estado});

  final String estado;

  int get _step {
    switch (estado) {
      case 'pendiente':
        return 0;
      case 'en_comite':
        return 1;
      case 'aprobado':
        return 2;
      case 'desembolsado':
      case 'completado':
        return 3;
      case 'rechazado':
        return -1;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step < 0) {
      return const Text(
        'Solicitud rechazada',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
      );
    }

    const steps = ['Enviado', 'Comité', 'Aprobado', 'Desembolsado'];

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final lineIndex = i ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: lineIndex < _step
                  ? AppColors.brandRed
                  : const Color(0xFFE5E7EB),
            ),
          );
        }

        final stepIndex = i ~/ 2;
        final active = stepIndex <= _step;
        return Column(
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: active
                  ? AppColors.brandRed
                  : const Color(0xFFE5E7EB),
              child: active
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              steps[stepIndex],
              style: TextStyle(
                fontSize: 10,
                color: active ? AppColors.ink : AppColors.muted,
                fontWeight: active ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}
