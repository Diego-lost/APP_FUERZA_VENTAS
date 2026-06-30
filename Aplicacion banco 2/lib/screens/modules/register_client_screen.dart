import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuerza_ventas_app/models/picked_address.dart';
import 'package:fuerza_ventas_app/screens/client_detail_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/address_picker_screen.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RegisterClientScreen extends StatefulWidget {
  const RegisterClientScreen({super.key});

  @override
  State<RegisterClientScreen> createState() => _RegisterClientScreenState();
}

class _RegisterClientScreenState extends State<RegisterClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mgmt = ClientManagementService();

  final _dni = TextEditingController();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _telefono = TextEditingController();
  final _negocio = TextEditingController();
  final _distrito = TextEditingController();
  final _direccion = TextEditingController();
  final _antiguedad = TextEditingController(text: '12');
  final _ingresos = TextEditingController(text: '2000');
  final _gastos = TextEditingController(text: '900');
  final _password = TextEditingController(text: 'Cliente2026!');

  PickedAddress? _ubicacion;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [
      _dni, _nombres, _apellidos, _telefono, _negocio, _distrito,
      _direccion, _antiguedad, _ingresos, _gastos, _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final picked = await Navigator.of(context).push<PickedAddress>(
      MaterialPageRoute(
        builder: (_) => AddressPickerScreen(
          initialAddress: _direccion.text.trim().isEmpty ? null : _direccion.text,
          initialPosition: _ubicacion?.position,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _ubicacion = picked;
      _direccion.text = picked.formattedAddress;
      if (picked.distrito != null && picked.distrito!.isNotEmpty) {
        _distrito.text = picked.distrito!;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_ubicacion == null) {
      _snack('Selecciona la ubicación del negocio en el mapa.');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _mgmt.registerClient(
        dni: _dni.text.trim(),
        nombres: _nombres.text.trim(),
        apellidos: _apellidos.text.trim(),
        telefono: _telefono.text.trim(),
        nombreNegocio: _negocio.text.trim(),
        distrito: _distrito.text.trim(),
        direccionNegocio: _direccion.text.trim(),
        lat: _ubicacion!.position.latitude,
        lng: _ubicacion!.position.longitude,
        antiguedadMeses: int.tryParse(_antiguedad.text.trim()) ?? 12,
        ingresosMensuales: double.tryParse(_ingresos.text.trim()) ?? 2000,
        gastosMensuales: double.tryParse(_gastos.text.trim()) ?? 900,
        password: _password.text,
      );

      if (!mounted) return;
      if (!result.ok) {
        _snack(_errorMessage(result.error));
        return;
      }

      if (!mounted) return;
      await _showSuccessDialog(result.userId!, dniNorm: _dni.text.trim());
    } catch (e) {
      _snack('Error al registrar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorMessage(String? code) {
    switch (code) {
      case 'dni_invalido':
        return 'DNI inválido (8 dígitos).';
      case 'dni_ya_registrado':
        return 'Ese DNI ya está registrado.';
      case 'asesor_no_autenticado':
        return 'Sesión de asesor no válida.';
      case 'nombre_requerido':
        return 'Nombres y apellidos son obligatorios.';
      default:
        return 'No se pudo registrar ($code). Ejecuta 25_fventas_registro_maps.sql en Supabase.';
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

  void _resetForm() {
    for (final c in [
      _dni, _nombres, _apellidos, _telefono, _negocio, _distrito, _direccion,
    ]) {
      c.clear();
    }
    _antiguedad.text = '12';
    _ingresos.text = '2000';
    _gastos.text = '900';
    _password.text = 'Cliente2026!';
    setState(() => _ubicacion = null);
    _formKey.currentState?.reset();
  }

  Future<void> _showSuccessDialog(String userId, {required String dniNorm}) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cliente registrado'),
        content: Text(
          'DNI $dniNorm quedó en tu cartera.\n'
          '¿Qué deseas hacer ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'otro'),
            child: const Text('Registrar otro'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cartera'),
            child: const Text('Ver cartera'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'ficha'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandRed),
            child: const Text('Ver ficha'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    switch (action) {
      case 'otro':
        _resetForm();
        _snack('Ingresa otro DNI para el siguiente cliente.', success: true);
      case 'ficha':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ClientDetailScreen(userId: userId),
          ),
        );
      case 'cartera':
      default:
        Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo cliente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Registra un cliente nuevo en tu cartera. '
              'Usa el mapa para ubicar el negocio con precisión.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _field(_dni, 'DNI (8 dígitos)', keyboard: TextInputType.number,
                validator: (v) {
              if ((v ?? '').replaceAll(RegExp(r'\D'), '').length != 8) {
                return 'Ingresa un DNI de 8 dígitos';
              }
              return null;
            }),
            _field(_nombres, 'Nombres', validator: _required),
            _field(_apellidos, 'Apellidos', validator: _required),
            _field(_telefono, 'Teléfono', keyboard: TextInputType.phone),
            _field(_negocio, 'Nombre del negocio'),
            _field(_distrito, 'Distrito'),
            _field(_direccion, 'Dirección', readOnly: true, onTap: _pickAddress),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickAddress,
              icon: const Icon(Icons.map_rounded, color: AppColors.brandRed),
              label: Text(
                _ubicacion == null
                    ? 'Ubicar en Google Maps'
                    : 'Cambiar ubicación en mapa',
              ),
            ),
            if (_ubicacion != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 120,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _ubicacion!.position,
                      zoom: 16,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('preview'),
                        position: _ubicacion!.position,
                      ),
                    },
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    liteModeEnabled: true,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_antiguedad, 'Antigüedad (meses)', keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _field(_ingresos, 'Ingresos S/', keyboard: TextInputType.number)),
              ],
            ),
            _field(_gastos, 'Gastos S/', keyboard: TextInputType.number),
            _field(_password, 'Contraseña app clientes', obscure: true),
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
                  : const Icon(Icons.person_add_rounded),
              label: Text(_loading ? 'Registrando…' : 'Registrar cliente'),
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
    bool readOnly = false,
    bool obscure = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        keyboardType: keyboard,
        inputFormatters: keyboard == TextInputType.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        validator: validator,
        readOnly: readOnly,
        obscureText: obscure,
        onTap: onTap,
      ),
    );
  }
}
