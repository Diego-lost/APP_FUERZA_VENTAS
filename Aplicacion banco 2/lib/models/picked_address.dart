import 'package:google_maps_flutter/google_maps_flutter.dart';

class PickedAddress {
  const PickedAddress({
    required this.formattedAddress,
    required this.position,
    this.distrito,
  });

  final String formattedAddress;
  final LatLng position;
  final String? distrito;
}
