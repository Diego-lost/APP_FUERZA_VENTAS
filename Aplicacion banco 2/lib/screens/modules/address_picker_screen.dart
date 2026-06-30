import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/core/maps/maps_config.dart';
import 'package:fuerza_ventas_app/models/picked_address.dart';
import 'package:fuerza_ventas_app/services/geocoding_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AddressPickerScreen extends StatefulWidget {
  const AddressPickerScreen({
    super.key,
    this.initialAddress,
    this.initialPosition,
  });

  final String? initialAddress;
  final LatLng? initialPosition;

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  final _geocoding = GeocodingService();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  GoogleMapController? _mapController;
  GeocodingResult? _selected;
  List<PlacePrediction> _predictions = [];
  bool _searching = false;
  Timer? _debounce;

  static const _peruCenter = LatLng(-12.0581, -75.2027);

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _searchController.text = widget.initialAddress!;
    }
    _searchController.addListener(_onSearchChanged);
    if (widget.initialPosition != null) {
      _selected = GeocodingResult(
        position: widget.initialPosition!,
        formattedAddress: widget.initialAddress ?? '',
      );
    } else if (widget.initialAddress != null &&
        widget.initialAddress!.trim().isNotEmpty) {
      _geocodeInitial();
    }
  }

  Future<void> _geocodeInitial() async {
    if (!MapsConfig.isConfigured) return;
    final result = await _geocoding.geocodeAddress(widget.initialAddress!);
    if (!mounted || result == null) return;
    setState(() => _selected = result);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(result.position, 16),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!MapsConfig.isConfigured) return;
      final query = _searchController.text;
      if (query.trim().length < 3) {
        if (mounted) setState(() => _predictions = []);
        return;
      }
      final results = await _geocoding.autocomplete(query);
      if (mounted) setState(() => _predictions = results);
    });
  }

  Future<void> _selectPlace(GeocodingResult place) async {
    setState(() {
      _selected = place;
      _predictions = [];
      _searchController.text = place.formattedAddress;
    });
    _searchFocus.unfocus();
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(place.position, 16),
    );
  }

  Future<void> _onMapTap(LatLng position) async {
    if (!MapsConfig.isConfigured) return;
    setState(() => _searching = true);
    try {
      final result = await _geocoding.reverseGeocode(position);
      if (!mounted || result == null) return;
      await _selectPlace(result);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useMyLocation() async {
    if (!MapsConfig.isConfigured) {
      _snack('Configura GOOGLE_MAPS_API_KEY en .env');
      return;
    }
    setState(() => _searching = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack('Permiso de ubicación denegado.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);
      final result = await _geocoding.reverseGeocode(latLng);
      if (!mounted) return;
      if (result != null) {
        await _selectPlace(result);
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _confirm() {
    final sel = _selected;
    if (sel == null || sel.formattedAddress.isEmpty) {
      _snack('Selecciona una dirección en el mapa o búsqueda.');
      return;
    }
    final parts = sel.formattedAddress.split(',');
    final distrito = parts.length > 1 ? parts[parts.length - 2].trim() : null;
    Navigator.of(context).pop(
      PickedAddress(
        formattedAddress: sel.formattedAddress,
        position: sel.position,
        distrito: distrito,
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialPosition ?? _selected?.position ?? _peruCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación del cliente'),
        actions: [
          TextButton(
            onPressed: _selected == null ? null : _confirm,
            child: const Text(
              'Confirmar',
              style: TextStyle(color: AppColors.brandRed, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  decoration: InputDecoration(
                    hintText: 'Buscar dirección en Perú…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            onPressed: _useMyLocation,
                            icon: const Icon(Icons.my_location_rounded),
                            tooltip: 'Mi ubicación',
                          ),
                  ),
                  onSubmitted: (_) async {
                    final result =
                        await _geocoding.geocodeAddress(_searchController.text);
                    if (result != null) await _selectPlace(result);
                  },
                ),
                if (_predictions.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(top: 4),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _predictions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = _predictions[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined, size: 20),
                          title: Text(p.description, style: const TextStyle(fontSize: 13)),
                          onTap: () async {
                            final result = await _geocoding.resolvePlace(p.placeId);
                            if (result != null) await _selectPlace(result);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: MapsConfig.isConfigured
                ? Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: initial,
                          zoom: _selected != null ? 16 : 12,
                        ),
                        onMapCreated: (c) => _mapController = c,
                        onTap: _onMapTap,
                        markers: _selected == null
                            ? {}
                            : {
                                Marker(
                                  markerId: const MarkerId('picked'),
                                  position: _selected!.position,
                                  infoWindow: InfoWindow(
                                    title: 'Ubicación',
                                    snippet: _selected!.formattedAddress,
                                  ),
                                ),
                              },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                      ),
                      if (_selected != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                _selected!.formattedAddress,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Agrega GOOGLE_MAPS_API_KEY en .env y habilita '
                        'Maps SDK, Geocoding y Places en Google Cloud.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirm,
        backgroundColor: AppColors.brandRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.check_rounded),
        label: const Text('Usar esta dirección'),
      ),
    );
  }
}
