import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/models/captured_document.dart';
import 'package:fuerza_ventas_app/models/credit_application.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';

class TransmissionScreen extends StatefulWidget {
  const TransmissionScreen({super.key});

  @override
  State<TransmissionScreen> createState() => _TransmissionScreenState();
}

class _TransmissionScreenState extends State<TransmissionScreen> {
  final _service = ClientManagementService();
  List<CreditApplication> _aprobadas = [];
  List<CapturedDocument> _documentos = [];
  final Set<String> _seleccionadas = {};
  bool _loading = true;
  bool _disbursing = false;
  bool _transmittingDocs = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.fetchApprovedApplications(),
        _service.fetchPendingDocuments(),
      ]);
      if (!mounted) return;
      final aprobadas = results[0] as List<CreditApplication>;
      setState(() {
        _aprobadas = aprobadas;
        _documentos = results[1] as List<CapturedDocument>;
        _seleccionadas
          ..clear()
          ..addAll(aprobadas.map((s) => s.id));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        _seleccionadas.addAll(_aprobadas.map((s) => s.id));
      } else {
        _seleccionadas.clear();
      }
    });
  }

  Future<void> _desembolsar() async {
    if (_seleccionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una solicitud.')),
      );
      return;
    }

    setState(() => _disbursing = true);
    try {
      final result =
          await _service.disburseSelected(_seleccionadas.toList(growable: false));
      if (!mounted) return;
      if (result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Desembolsados: ${result.desembolsosOk}. '
              'Fallidos: ${result.desembolsosFallidos}.',
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'No se pudo desembolsar.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error al desembolsar. Ejecuta 31_desembolso_seleccion_transmision.sql.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _disbursing = false);
    }
  }

  Future<void> _transmitDocs() async {
    setState(() => _transmittingDocs = true);
    try {
      final result = await _service.transmitPending();
      if (!mounted) return;
      if (result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Documentos transmitidos: ${result.documentosTransmitidos}.',
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _load();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron transmitir documentos.')),
      );
    } finally {
      if (mounted) setState(() => _transmittingDocs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transmisión electrónica'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Text(
                  'Solicitudes aprobadas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Elige a quién desembolsar. Aprobar no desembolsa automáticamente.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 10),
                if (_aprobadas.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('No hay solicitudes aprobadas pendientes.'),
                    ),
                  )
                else ...[
                  CheckboxListTile(
                    value: _seleccionadas.length == _aprobadas.length,
                    tristate: true,
                    onChanged: _toggleAll,
                    title: Text('Seleccionar todas (${_aprobadas.length})'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  ..._aprobadas.map((s) {
                    return Card(
                      child: CheckboxListTile(
                        value: _seleccionadas.contains(s.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _seleccionadas.add(s.id);
                            } else {
                              _seleccionadas.remove(s.id);
                            }
                          });
                        },
                        title: Text(
                          s.clienteNombre ?? 'Cliente',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'S/ ${s.monto.toStringAsFixed(2)} · '
                          '${s.plazoMeses} meses · ${s.estadoLabel}',
                        ),
                        secondary: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.brandRed,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandRed,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _disbursing || _seleccionadas.isEmpty
                        ? null
                        : _desembolsar,
                    icon: _disbursing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.payments_outlined),
                    label: Text(
                      _disbursing
                          ? 'Desembolsando...'
                          : 'Desembolsar seleccionados (${_seleccionadas.length})',
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Documentos capturados',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (_documentos.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('No hay documentos pendientes.'),
                    ),
                  )
                else
                  ..._documentos.map(
                    (d) => Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.description_outlined,
                          color: AppColors.brandRed,
                        ),
                        title: Text(d.tipoLabel),
                        subtitle: Text(d.clienteNombre ?? ''),
                      ),
                    ),
                  ),
                if (_documentos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _transmittingDocs ? null : _transmitDocs,
                    icon: const Icon(Icons.send_to_mobile),
                    label: Text(
                      _transmittingDocs
                          ? 'Transmitiendo...'
                          : 'Transmitir documentos',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
