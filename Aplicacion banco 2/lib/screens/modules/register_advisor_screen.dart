import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/core/supabase/supabase_bootstrap.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';

class RegisterAdvisorScreen extends StatefulWidget {
  const RegisterAdvisorScreen({super.key});

  @override
  State<RegisterAdvisorScreen> createState() => _RegisterAdvisorScreenState();
}

class _RegisterAdvisorScreenState extends State<RegisterAdvisorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mgmt = ClientManagementService();

  final _codigo = TextEditingController();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _dni = TextEditingController();
  final _password = TextEditingController(text: 'Asesor2026!');

  List<AgencyOption> _agencias = [];
  int? _agenciaId;
  String _nivel = 'Junior I';
  String _perfil = 'operador';
  bool _loading = false;
  bool _loadingAgencias = true;
  String? _accessError;

  static const _niveles = ['Junior I', 'Junior II', 'Senior I', 'Senior II'];
  static const _perfiles = ['operador', 'super_operador', 'supervisor', 'administrador'];

  @override
  void initState() {
    super.initState();
    _loadAgencias();
  }

  @override
  void dispose() {
    for (final c in [_codigo, _nombres, _apellidos, _email, _telefono, _dni, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAgencias() async {
    setState(() {
      _loadingAgencias = true;
      _accessError = null;
    });
    try {
      final agencias = await _mgmt.listAgencies();
      if (!mounted) return;
      setState(() {
        _agencias = agencias;
        _agenciaId = agencias.isNotEmpty ? agencias.first.id : null;
        _loadingAgencias = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accessError = e.toString().contains('sin_permiso')
            ? 'Solo administradores pueden crear asesores.'
            : 'No se pudieron cargar agencias. Ejecuta 25_fventas_registro_maps.sql.';
        _loadingAgencias = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_agenciaId == null) {
      _snack('Selecciona una agencia.');
      return;
    }
    if (!SupabaseBootstrap.isReady) {
      _snack('Configura Supabase en .env');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _mgmt.createAdvisor(
        codigo: _codigo.text.trim(),
        nombres: _nombres.text.trim(),
        apellidos: _apellidos.text.trim(),
        email: _email.text.trim(),
        idAgencia: _agenciaId!,
        nivel: _nivel,
        perfil: _perfil,
        password: _password.text,
        telefono: _telefono.text.trim(),
        dni: _dni.text.trim(),
      );

      if (!mounted) return;
      if (!result.ok) {
        _snack(_errorMessage(result.error));
        return;
      }

      _snack(
        'Asesor ${result.codigo} creado. Login: código + contraseña.',
        success: true,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorMessage(String? code) {
    switch (code) {
      case 'sin_permiso':
        return 'No tienes permiso de administrador.';
      case 'codigo_ya_existe':
        return 'Ese código de asesor ya existe.';
      case 'campos_requeridos':
        return 'Completa código, nombres, apellidos y email.';
      case 'agencia_no_encontrada':
        return 'Agencia no válida.';
      default:
        return 'No se pudo crear ($code).';
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAgencias) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nuevo asesor')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_accessError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nuevo asesor')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(_accessError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _loadAgencias,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo asesor')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Alta de asesor de negocios. Solo perfil administrador.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _field(_codigo, 'Código (ej. AG-001-13)', validator: _required),
            _field(_nombres, 'Nombres', validator: _required),
            _field(_apellidos, 'Apellidos', validator: _required),
            _field(_email, 'Email', keyboard: TextInputType.emailAddress, validator: _required),
            _field(_telefono, 'Teléfono', keyboard: TextInputType.phone),
            _field(_dni, 'DNI', keyboard: TextInputType.number),
            DropdownButtonFormField<int>(
              value: _agenciaId,
              decoration: const InputDecoration(labelText: 'Agencia'),
              items: _agencias
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.codigo} — ${a.nombre}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _agenciaId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _nivel,
              decoration: const InputDecoration(labelText: 'Nivel'),
              items: _niveles
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (v) => setState(() => _nivel = v ?? 'Junior I'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _perfil,
              decoration: const InputDecoration(labelText: 'Perfil RBAC'),
              items: _perfiles
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _perfil = v ?? 'operador'),
            ),
            const SizedBox(height: 12),
            _field(_password, 'Contraseña inicial', obscure: true, validator: _required),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.badge_outlined),
              label: Text(_loading ? 'Creando…' : 'Crear asesor'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo requerido' : null;

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        keyboardType: keyboard,
        validator: validator,
        obscureText: obscure,
      ),
    );
  }
}
