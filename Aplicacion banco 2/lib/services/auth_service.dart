import 'package:fuerza_ventas_app/core/storage/secure_storage_service.dart';
import 'package:fuerza_ventas_app/core/supabase/supabase_bootstrap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const _maxIntentos = 5;
  static const _mensajeBloqueo =
      'Cuenta bloqueada por intentos fallidos. Intenta en 10 segundos.';

  AuthService({
    SupabaseClient? client,
    SecureStorageService? secureStorage,
  })  : _client = client ?? SupabaseBootstrap.client,
        _secure = secureStorage ?? SecureStorageService();

  final SupabaseClient _client;
  final SecureStorageService _secure;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signInWithCodigo({
    required String codigo,
    required String password,
    bool rememberCodigo = true,
  }) async {
    final codigoTrim = codigo.trim();

    await _throwIfBlocked(codigoTrim);

    final raw = await _client.rpc(
      'get_asesor_email_by_codigo',
      params: {'p_codigo': codigoTrim},
    );
    final email = raw as String?;

    if (email == null || email.isEmpty) {
      throw const AuthException(
        'No encontramos un asesor activo con ese código.',
      );
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final token = response.session?.accessToken;
      if (token != null) {
        await _secure.saveToken(token);
      }
      if (rememberCodigo) {
        await _secure.saveRememberedCodigo(codigoTrim);
      }
      await _client.rpc(
        'asesor_reset_intentos',
        params: {'p_codigo': codigoTrim},
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('bloqueada')) rethrow;

      final fallo = await _registrarIntentoFallido(codigoTrim);
      if (fallo.bloqueado) {
        throw const AuthException(_mensajeBloqueo);
      }

      if (msg.contains('invalid') ||
          msg.contains('credentials') ||
          msg.contains('incorrect')) {
        throw AuthException(_mensajeConIntentos(fallo.intentosRestantes));
      }
      if (msg.contains('email not confirmed')) {
        throw const AuthException(
          'Tu cuenta aún no está activada. Contacta a tu supervisor.',
        );
      }
      throw AuthException(_mensajeConIntentos(fallo.intentosRestantes));
    }
  }

  Future<void> _throwIfBlocked(String codigo) async {
    final bloqueo = await _client.rpc(
      'asesor_verificar_bloqueo',
      params: {'p_codigo': codigo},
    );
    final bloqueoData = Map<String, dynamic>.from(bloqueo as Map);
    if (bloqueoData['bloqueado'] == true) {
      throw const AuthException(_mensajeBloqueo);
    }
  }

  Future<({bool bloqueado, int intentosRestantes})> _registrarIntentoFallido(
    String codigo,
  ) async {
    try {
      final raw = await _client.rpc(
        'asesor_registrar_intento_fallido',
        params: {'p_codigo': codigo},
      );
      final data = Map<String, dynamic>.from(raw as Map);
      if (data['ok'] != true) {
        return (bloqueado: false, intentosRestantes: _maxIntentos);
      }
      return (
        bloqueado: data['bloqueado'] == true,
        intentosRestantes: (data['intentos_restantes'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return (bloqueado: false, intentosRestantes: 0);
    }
  }

  String _mensajeConIntentos(int restantes) {
    if (restantes <= 0) {
      return 'Contraseña incorrecta.';
    }
    if (restantes == 1) {
      return 'Contraseña incorrecta. Te queda 1 intento (de $_maxIntentos).';
    }
    return 'Contraseña incorrecta. Te quedan $restantes intentos (de $_maxIntentos).';
  }

  Future<void> signOut() async {
    await _secure.clearToken();
    await _client.auth.signOut();
  }

  Future<String?> getRememberedCodigo() => _secure.readRememberedCodigo();

  Future<String?> getStoredToken() => _secure.readToken();
}
