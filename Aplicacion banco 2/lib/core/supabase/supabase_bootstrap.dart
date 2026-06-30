import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fuerza_ventas_app/core/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class SupabaseBootstrap {
  static bool _initialized = false;

  static bool get isReady => _initialized;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('SupabaseBootstrap: no se cargó .env ($e)');
    }

    if (!SupabaseConfig.isConfigured) {
      debugPrint(
        'SupabaseBootstrap: faltan SUPABASE_URL o SUPABASE_ANON_KEY en .env',
      );
      return;
    }

    for (final issue in SupabaseConfig.configurationIssues) {
      debugPrint('SupabaseBootstrap: $issue');
    }

    if (!SupabaseConfig.hasValidAnonKeyFormat) {
      debugPrint(
        'SupabaseBootstrap: anon key inválida — revisa Project Settings → API.',
      );
      return;
    }

    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _initialized = true;
  }
}
