import 'dart:convert';

import 'package:fuerza_ventas_app/core/maps/maps_config.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class PlacePrediction {
  const PlacePrediction({
    required this.description,
    required this.placeId,
  });

  final String description;
  final String placeId;
}

class GeocodingResult {
  const GeocodingResult({
    required this.position,
    required this.formattedAddress,
  });

  final LatLng position;
  final String formattedAddress;
}

class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<PlacePrediction>> autocomplete(String input) async {
    final key = MapsConfig.apiKey;
    if (key.isEmpty || input.trim().length < 3) return [];

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': input.trim(),
        'key': key,
        'language': 'es',
        'components': 'country:pe',
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
      return [];
    }

    final predictions = data['predictions'] as List<dynamic>? ?? [];
    return predictions
        .map(
          (p) => PlacePrediction(
            description: p['description'] as String? ?? '',
            placeId: p['place_id'] as String? ?? '',
          ),
        )
        .where((p) => p.description.isNotEmpty)
        .toList();
  }

  Future<GeocodingResult?> resolvePlace(String placeId) async {
    final key = MapsConfig.apiKey;
    if (key.isEmpty || placeId.isEmpty) return null;

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'key': key,
        'language': 'es',
        'fields': 'geometry,formatted_address',
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final result = data['result'] as Map<String, dynamic>?;
    final geometry = result?['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    if (location == null) return null;

    return GeocodingResult(
      position: LatLng(
        (location['lat'] as num).toDouble(),
        (location['lng'] as num).toDouble(),
      ),
      formattedAddress: result?['formatted_address'] as String? ?? '',
    );
  }

  Future<GeocodingResult?> geocodeAddress(String address) async {
    final key = MapsConfig.apiKey;
    if (key.isEmpty || address.trim().isEmpty) return null;

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'address': address.trim(),
        'key': key,
        'language': 'es',
        'region': 'pe',
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    final first = results.first as Map<String, dynamic>;
    final geometry = first['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    return GeocodingResult(
      position: LatLng(
        (location['lat'] as num).toDouble(),
        (location['lng'] as num).toDouble(),
      ),
      formattedAddress: first['formatted_address'] as String? ?? address,
    );
  }

  Future<GeocodingResult?> reverseGeocode(LatLng position) async {
    final key = MapsConfig.apiKey;
    if (key.isEmpty) return null;

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '${position.latitude},${position.longitude}',
        'key': key,
        'language': 'es',
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    final first = results.first as Map<String, dynamic>;
    return GeocodingResult(
      position: position,
      formattedAddress: first['formatted_address'] as String? ?? '',
    );
  }
}
