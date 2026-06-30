import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/models/portfolio_client.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';
import 'package:fuerza_ventas_app/widgets/client_picker_sheet.dart';

class NewCreditRequestScreen extends StatefulWidget {
  const NewCreditRequestScreen({super.key});

  @override
  State<NewCreditRequestScreen> createState() => _NewCreditRequestScreenState();
}

class _NewCreditRequestScreenState extends State<NewCreditRequestScreen> {
  final _service = ClientManagementService();
  final _montoController = TextEditingController(text: '2000');
  final _plazoController = TextEditingController(text: '6');
  final _propositoController = TextEditingController();

  PortfolioClient? _client;
  String _producto = 'prospera';
  bool _loading = false;

  @override
  void dispose() {
    _montoController.dispose();
    _plazoController.dispose();
    _propositoController.dispose();
    super.dispose();
  }

  Future<void> _pickClient() async {
    final client = await showClientPicker(context);
    if (client != null) setState(() => _client = client);
  }

  Future<void> _submit() async {
    final client = _client;
    if (client == null) {
      _show('Selecciona un cliente de tu cartera.');
      return;
    }

    final monto = double.tryParse(_montoController.text.trim());
    final plazo = int.tryParse(_plazoController.text.trim());
    if (monto == null || monto <= 0 || plazo == null || plazo <= 0) {
      _show('Monto y plazo deben ser números válidos.');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _service.createCreditApplication(
        userId: client.userId,
        monto: monto,
        plazoMeses: plazo,
        tipoProducto: _producto,
        proposito: _propositoController.text.trim().isEmpty
            ? null
            : _propositoController.text.trim(),
      );

      if (!mounted) return;
      if (result.ok) {
        // Transmitir y desembolsar para que el cliente lo vea en su app.
        final tx = await _service.transmitPending();
        final desembolsos = tx.desembolsosReflejados;
        _show(
          desembolsos > 0
              ? 'Solicitud enviada y desembolsada. El cliente ${client.dni} '
                  'ya puede verla en Créditos (app clientes).'
              : 'Solicitud creada (cuota S/ ${result.cuotaMensual?.toStringAsFixed(2) ?? '—'}). '
                  'Ve a Transmisión o ejecuta el script 13 en Supabase si no aparece en clientes.',
          success: desembolsos > 0,
        );
        _propositoController.clear();
      } else {
        _show(_errorMessage(result.error));
      }
    } catch (_) {
      _show('Error al registrar la solicitud.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorMessage(String? code) {
    switch (code) {
      case 'cliente_no_cartera':
        return 'Ese cliente no pertenece a tu cartera.';
      case 'producto_invalido':
        return 'Producto no válido.';
      case 'datos_invalidos':
        return 'Revisa monto y plazo.';
      default:
        return 'No se pudo crear la solicitud.';
    }
  }

  void _show(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva solicitud de crédito')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_search, color: AppColors.brandRed),
              title: Text(
                _client?.nombreCompleto ?? 'Seleccionar cliente',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _client != null
                    ? 'DNI ${_client!.dni}'
                    : 'Elige un cliente de la app SURGIR Clientes',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickClient,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _producto,
            decoration: const InputDecoration(labelText: 'Producto'),
            items: const [
              DropdownMenuItem(value: 'prospera', child: Text('Prospera')),
              DropdownMenuItem(
                value: 'mujeres_unidas',
                child: Text('Mujeres Unidas'),
              ),
              DropdownMenuItem(
                value: 'construyendo_suenos',
                child: Text('Construyendo Sueños'),
              ),
            ],
            onChanged: _loading ? null : (v) => setState(() => _producto = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _montoController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Monto (S/)',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _plazoController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Plazo (meses)',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _propositoController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Propósito (opcional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.post_add),
            label: Text(_loading ? 'Registrando...' : 'Registrar solicitud'),
          ),
        ],
      ),
    );
  }
}
