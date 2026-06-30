import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/core/maps/maps_config.dart';
import 'package:fuerza_ventas_app/models/picked_address.dart';
import 'package:fuerza_ventas_app/screens/modules/address_picker_screen.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientLocationMapScreen extends StatefulWidget {
  const ClientLocationMapScreen({
    super.key,
    required this.userId,
    required this.clientName,
    this.direccion,
    this.lat,
    this.lng,
    this.distrito,
    this.editable = false,
  });

  final String userId;
  final String clientName;
  final String? direccion;
  final double? lat;
  final double? lng;
  final String? distrito;
  final bool editable;

  @override
  State<ClientLocationMapScreen> createState() => _ClientLocationMapScreenState();
}

class _ClientLocationMapScreenState extends State<ClientLocationMapScreen> {
  final _mgmt = ClientManagementService();
  GoogleMapController? _mapController;

  late String? _direccion;
  late double? _lat;
  late double? _lng;
  bool _saving = false;

  static const _peruCenter = LatLng(-12.0581, -75.2027);

  @override
  void initState() {
    super.initState();
    _direccion = widget.direccion;
    _lat = widget.lat;
    _lng = widget.lng;
  }

  LatLng get _position {
    if (_lat != null && _lng != null) return LatLng(_lat!, _lng!);
    return _peruCenter;
  }

  bool get _hasCoords => _lat != null && _lng != null;

  Future<void> _editAddress() async {
    final picked = await Navigator.of(context).push<PickedAddress>(
      MaterialPageRoute(
        builder: (_) => AddressPickerScreen(
          initialAddress: _direccion,
          initialPosition: _hasCoords ? _position : null,
        ),
      ),
    );
    if (picked == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final ok = await _mgmt.updateClientAddress(
        userId: widget.userId,
        direccion: picked.formattedAddress,
        distrito: picked.distrito ?? widget.distrito,
        lat: picked.position.latitude,
        lng: picked.position.longitude,
      );
      if (!mounted) return;
      if (ok) {
        setState(() {
          _direccion = picked.formattedAddress;
          _lat = picked.position.latitude;
          _lng = picked.position.longitude;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(picked.position, 16),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ubicación actualizada.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openDirections() async {
    if (!_hasCoords) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$_lat,$_lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ubicación — ${widget.clientName}'),
        actions: [
          if (_hasCoords)
            IconButton(
              onPressed: _openDirections,
              icon: const Icon(Icons.directions_rounded),
              tooltip: 'Cómo llegar',
            ),
          if (widget.editable)
            IconButton(
              onPressed: _saving ? null : _editAddress,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_location_alt_rounded),
              tooltip: 'Corregir ubicación',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_direccion != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.storefront_outlined, color: AppColors.brandRed),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _direccion!,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: MapsConfig.isConfigured && _hasCoords
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _position,
                      zoom: 16,
                    ),
                    onMapCreated: (c) => _mapController = c,
                    markers: {
                      Marker(
                        markerId: MarkerId(widget.userId),
                        position: _position,
                        infoWindow: InfoWindow(
                          title: widget.clientName,
                          snippet: _direccion,
                        ),
                      ),
                    },
                    myLocationEnabled: true,
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_off_outlined,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _hasCoords
                                ? 'Configura GOOGLE_MAPS_API_KEY en .env'
                                : 'Sin coordenadas GPS. ${widget.editable ? "Toca el ícono de editar para ubicar." : ""}',
                            textAlign: TextAlign.center,
                          ),
                          if (widget.editable && !_hasCoords) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _editAddress,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brandRed,
                              ),
                              icon: const Icon(Icons.map_rounded),
                              label: const Text('Ubicar en mapa'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
