import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/models/bureau_report.dart';
import 'package:fuerza_ventas_app/models/portfolio_client.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';
import 'package:fuerza_ventas_app/widgets/client_picker_sheet.dart';

class CreditBureauScreen extends StatefulWidget {
  const CreditBureauScreen({super.key});

  @override
  State<CreditBureauScreen> createState() => _CreditBureauScreenState();
}

class _CreditBureauScreenState extends State<CreditBureauScreen> {
  final _service = ClientManagementService();
  PortfolioClient? _client;
  BureauReport? _report;
  bool _loading = false;
  String? _error;
  bool _consentimiento = false;
  final _firmaController = TextEditingController();

  @override
  void dispose() {
    _firmaController.dispose();
    super.dispose();
  }

  Future<void> _pickAndConsult() async {
    final client = await showClientPicker(context);
    if (client == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var consent = _consentimiento;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Consentimiento (Ley 29733)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  value: consent,
                  onChanged: (v) =>
                      setDialogState(() => consent = v ?? false),
                  title: const Text(
                    'El cliente autoriza la consulta de su historial crediticio.',
                    style: TextStyle(fontSize: 13),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _firmaController,
                  decoration: const InputDecoration(
                    labelText: 'Firma del cliente (nombre completo)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  setState(() => _consentimiento = consent);
                  Navigator.pop(ctx, consent);
                },
                child: const Text('Consultar buró'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _client = client;
      _loading = true;
      _error = null;
      _report = null;
    });

    try {
      final firma = _firmaController.text.trim().isNotEmpty
          ? base64Encode(utf8.encode(_firmaController.text.trim()))
          : null;
      final report = await _service.fetchBureauReport(
        client.userId,
        consentimiento: true,
        firmaBase64: firma,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
        if (report == null) _error = 'No hay datos de buró para este cliente.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error al consultar buró.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consulta de buró')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.query_stats, color: AppColors.brandRed),
              title: Text(
                _client?.nombreCompleto ?? 'Seleccionar cliente',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Scores SBS, transaccional y de campo',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _loading ? null : _pickAndConsult,
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_report != null) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Central de Riesgos (SBS)',
              rows: [
                _Row('Calificación', _report!.calificacionSbs),
                _Row('Entidades', '${_report!.entidadesSbs}'),
                _Row(
                  'Deuda total',
                  'S/ ${_report!.deudaTotalSbs.toStringAsFixed(2)}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SectionCard(
              title: 'Scoring SURGIR',
              rows: [
                if (_report!.scoreTransaccional != null)
                  _Row(
                    'Score transaccional',
                    '${_report!.scoreTransaccional}',
                  ),
                if (_report!.segmentoPreliminar != null)
                  _Row('Segmento preliminar', _report!.segmentoPreliminar!),
                if (_report!.montoHipotesis != null)
                  _Row(
                    'Monto hipótesis',
                    'S/ ${_report!.montoHipotesis!.toStringAsFixed(2)}',
                  ),
                if (_report!.scoreCampo != null)
                  _Row('Score de campo', '${_report!.scoreCampo}'),
                if (_report!.scoreFinal != null)
                  _Row('Score final', '${_report!.scoreFinal}'),
                if (_report!.segmentoResultante != null)
                  _Row('Segmento final', _report!.segmentoResultante!),
                if (_report!.recomendacionAsesor != null)
                  _Row('Recomendación', _report!.recomendacionAsesor!),
                if (_report!.estadoFicha != null)
                  _Row('Estado ficha', _report!.estadoFicha!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        r.label,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.value,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.value);
  final String label;
  final String value;
}
