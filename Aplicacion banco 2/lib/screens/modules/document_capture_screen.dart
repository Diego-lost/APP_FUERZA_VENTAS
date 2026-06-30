import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/models/captured_document.dart';
import 'package:fuerza_ventas_app/models/portfolio_client.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';
import 'package:fuerza_ventas_app/widgets/client_picker_sheet.dart';

class DocumentCaptureScreen extends StatefulWidget {
  const DocumentCaptureScreen({super.key});

  @override
  State<DocumentCaptureScreen> createState() => _DocumentCaptureScreenState();
}

class _DocumentCaptureScreenState extends State<DocumentCaptureScreen> {
  final _service = ClientManagementService();
  final _referenciaController = TextEditingController();
  final _obsController = TextEditingController();

  PortfolioClient? _client;
  String _tipo = 'dni_frontal';
  bool _loading = false;
  List<CapturedDocument> _recent = [];

  static const _tipos = <({String value, String label})>[
    (value: 'dni_frontal', label: 'DNI frontal'),
    (value: 'dni_posterior', label: 'DNI posterior'),
    (value: 'foto_negocio', label: 'Foto del negocio'),
    (value: 'recibo_servicio', label: 'Recibo de servicio'),
    (value: 'contrato_alquiler', label: 'Contrato de alquiler'),
    (value: 'otro', label: 'Otro documento'),
  ];

  @override
  void dispose() {
    _referenciaController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _pickClient() async {
    final client = await showClientPicker(context);
    if (client == null) return;
    setState(() => _client = client);
    await _loadRecent(client.userId);
  }

  Future<void> _loadRecent(String userId) async {
    final docs = await _service.fetchClientDocuments(userId);
    if (!mounted) return;
    setState(() => _recent = docs.take(5).toList());
  }

  Future<void> _submit() async {
    final client = _client;
    if (client == null) {
      _show('Selecciona un cliente.');
      return;
    }

    setState(() => _loading = true);
    try {
      final ok = await _service.registerDocument(
        userId: client.userId,
        tipo: _tipo,
        referencia: _referenciaController.text.trim().isEmpty
            ? 'Captura en campo ${DateTime.now().toIso8601String()}'
            : _referenciaController.text.trim(),
        observaciones: _obsController.text.trim().isEmpty
            ? null
            : _obsController.text.trim(),
      );

      if (!mounted) return;
      if (ok) {
        _show('Documento registrado. Transmítelo desde el módulo correspondiente.',
            success: true);
        _referenciaController.clear();
        _obsController.clear();
        await _loadRecent(client.userId);
      } else {
        _show('No se pudo registrar el documento.');
      }
    } catch (_) {
      _show('Error al registrar documento.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Captura de documentos')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person, color: AppColors.brandRed),
              title: Text(
                _client?.nombreCompleto ?? 'Seleccionar cliente',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Cliente de la app SURGIR Clientes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickClient,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo de documento'),
            items: _tipos
                .map(
                  (t) => DropdownMenuItem(
                    value: t.value,
                    child: Text(t.label),
                  ),
                )
                .toList(),
            onChanged: _loading ? null : (v) => setState(() => _tipo = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _referenciaController,
            decoration: const InputDecoration(
              labelText: 'Referencia / nombre del archivo',
              hintText: 'Ej. dni_frontal_001.jpg',
              prefixIcon: Icon(Icons.insert_drive_file_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _obsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Observaciones',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _loading ? null : _submit,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(_loading ? 'Guardando...' : 'Registrar captura'),
          ),
          if (_recent.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Últimos documentos del cliente',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            ..._recent.map(
              (d) => Card(
                child: ListTile(
                  title: Text(d.tipoLabel),
                  subtitle: Text(d.referencia ?? d.observaciones ?? ''),
                  trailing: Chip(
                    label: Text(d.estado),
                    backgroundColor: d.estado == 'transmitido'
                        ? Colors.green.shade50
                        : const Color(0xFFFFECEB),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
