import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/screens/client_detail_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/collection_action_sheet.dart';
import 'package:fuerza_ventas_app/models/collection_item.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  final _service = ClientManagementService();
  List<CollectionItem> _items = [];
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
      final items = await _service.fetchMoraClients();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().contains('mora_error') || e.toString().contains('function')
            ? 'Ejecuta 30_cobranza_completa.sql en Supabase.'
            : 'No se pudo cargar la cobranza.';
        _loading = false;
      });
    }
  }

  Future<void> _call(String? telefono) async {
    if (telefono == null || telefono.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El cliente no tiene teléfono.')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: telefono);
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el marcador.')),
      );
    }
  }

  Color _moraColor(int dias) {
    if (dias >= 90) return Colors.red.shade700;
    if (dias >= 30) return Colors.orange.shade700;
    return Colors.amber.shade800;
  }

  @override
  Widget build(BuildContext context) {
    final totalVencido =
        _items.fold<double>(0, (sum, i) => sum + i.montoVencido);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobranza del día'),
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
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        '${_items.length} cuenta(s) en mora · '
                        'S/ ${totalVencido.toStringAsFixed(2)} vencido',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: _items.isEmpty
                          ? const Center(
                              child: Text('No hay clientes en mora.'),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, index) {
                                final item = _items[index];
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _moraColor(item.diasMora)
                                          .withValues(alpha: 0.15),
                                      child: Icon(
                                        Icons.warning_amber_rounded,
                                        color: _moraColor(item.diasMora),
                                      ),
                                    ),
                                    title: Text(
                                      item.clienteNombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'DNI ${item.dni} · '
                                      '${item.diasMora} días de mora · '
                                      'S/ ${item.montoVencido.toStringAsFixed(2)}',
                                    ),
                                    isThreeLine: true,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Gestionar',
                                          onPressed: () async {
                                            final ok =
                                                await showCollectionActionSheet(
                                              context,
                                              item: item,
                                            );
                                            if (ok == true) _load();
                                          },
                                          icon: const Icon(
                                            Icons.handshake_outlined,
                                            color: AppColors.brandRed,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Llamar',
                                          onPressed: () => _call(item.telefono),
                                          icon: const Icon(
                                            Icons.phone_outlined,
                                            color: AppColors.brandRed,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => ClientDetailScreen(
                                            userId: item.userId,
                                          ),
                                        ),
                                      );
                                    },
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
