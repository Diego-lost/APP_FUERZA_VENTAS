import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class MapsConfig {
  static String get apiKey => dotenv.env['GOOGLE_MAPS_API_KEY']?.trim() ?? '';

  static bool get isConfigured => apiKey.isNotEmpty;
}
