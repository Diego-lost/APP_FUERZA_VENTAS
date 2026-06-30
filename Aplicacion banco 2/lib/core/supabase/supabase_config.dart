import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class SupabaseConfig {
  static String get url =>
      _normalizeUrl(_env('SUPABASE_URL'));

  static String get anonKey => _env('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static bool get hasValidAnonKeyFormat =>
      anonKey.length > 100 && anonKey.startsWith('eyJ');

  static List<String> get configurationIssues {
    final issues = <String>[];
    final rawUrl = _env('SUPABASE_URL');

    if (rawUrl.isEmpty || anonKey.isEmpty) {
      issues.add('Falta SUPABASE_URL o SUPABASE_ANON_KEY en el archivo .env');
      return issues;
    }

    if (rawUrl.startsWith('db.')) {
      issues.add(
        'SUPABASE_URL no debe ser db.xxx.supabase.co. '
        'Usa Project URL: https://TU_PROYECTO.supabase.co',
      );
    }

    if (!hasValidAnonKeyFormat) {
      issues.add(
        'SUPABASE_ANON_KEY debe ser la clave anon public (JWT que empieza con eyJ).',
      );
    }

    return issues;
  }

  static String _env(String key) {
    if (!dotenv.isInitialized) return '';
    return dotenv.env[key]?.trim() ?? '';
  }

  static String _normalizeUrl(String raw) {
    if (raw.isEmpty) return '';

    var u = raw;
    if (u.startsWith('db.') && u.contains('.supabase.co')) {
      u = 'https://${u.substring(3)}';
    } else if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    return u.endsWith('/') ? u.substring(0, u.length - 1) : u;
  }
}
