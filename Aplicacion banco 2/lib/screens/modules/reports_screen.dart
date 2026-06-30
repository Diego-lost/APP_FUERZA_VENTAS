import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/models/productivity_report.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _service = ClientManagementService();
  ProductivityReport? _report;
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
      final report = await _service.fetchProductivityReport();
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
        if (report == null) _error = 'No se pudo cargar el reporte.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().contains('sin_permiso')
            ? 'Acceso denegado (403). Solo supervisores pueden ver reportes.'
            : 'Error al cargar reportes.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes del mes'),
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
              : report == null
                  ? const Center(child: Text('Sin datos.'))
                  : ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.nombre,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'Código ${report.codigo}',
                                  style: const TextStyle(color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _KpiCard(
                          icon: Icons.send_outlined,
                          label: 'Solicitudes enviadas',
                          value: '${report.enviadas}',
                          color: AppColors.brandRed,
                        ),
                        const SizedBox(height: 10),
                        _KpiCard(
                          icon: Icons.check_circle_outline,
                          label: 'Aprobadas',
                          value: '${report.aprobadas}',
                          subtitle:
                              '${report.tasaAprobacion.toStringAsFixed(1)}% de aprobación',
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(height: 10),
                        _KpiCard(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Monto colocado',
                          value: 'S/ ${report.montoTotal.toStringAsFixed(2)}',
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(height: 16),
                        if (report.enviadas > 0)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Avance del mes',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 12),
                                  LinearProgressIndicator(
                                    value: report.enviadas > 0
                                        ? report.aprobadas / report.enviadas
                                        : 0,
                                    minHeight: 10,
                                    borderRadius: BorderRadius.circular(6),
                                    backgroundColor: const Color(0xFFE5E7EB),
                                    color: AppColors.brandRed,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.muted)),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
