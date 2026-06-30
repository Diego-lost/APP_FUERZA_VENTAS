import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/screens/client_detail_screen.dart';
import 'package:fuerza_ventas_app/models/campaign_offer.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final _service = ClientManagementService();
  List<CampaignOffer> _offers = [];
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
      final offers = await _service.fetchCampaigns();
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las campañas.';
        _loading = false;
      });
    }
  }

  Color _tipoColor(String tipo) {
    switch (tipo) {
      case 'renovacion':
        return Colors.teal.shade700;
      case 'ampliacion':
        return Colors.deepPurple.shade600;
      default:
        return AppColors.brandRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campañas activas'),
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
              : _offers.isEmpty
                  ? const Center(
                      child: Text('No hay campañas activas en tu cartera.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: _offers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final offer = _offers[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  _tipoColor(offer.tipo).withValues(alpha: 0.12),
                              child: Icon(
                                offer.tipo == 'ampliacion'
                                    ? Icons.trending_up
                                    : Icons.autorenew,
                                color: _tipoColor(offer.tipo),
                              ),
                            ),
                            title: Text(
                              offer.clienteNombre,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${offer.tipoLabel} · DNI ${offer.dni}\n'
                              'Oferta S/ ${offer.montoOfertado.toStringAsFixed(2)} · '
                              '${offer.diasRestantes} días restantes',
                            ),
                            isThreeLine: true,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ClientDetailScreen(
                                    userId: offer.userId,
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
