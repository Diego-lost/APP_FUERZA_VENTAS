import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuerza_ventas_app/models/collection_item.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';

Future<bool?> showCollectionActionSheet(
  BuildContext context, {
  required CollectionItem item,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CollectionActionSheet(item: item),
  );
}

class _CollectionActionSheet extends StatefulWidget {
  const _CollectionActionSheet({required this.item});

  final CollectionItem item;

  @override
  State<_CollectionActionSheet> createState() => _CollectionActionSheetState();
}

class _CollectionActionSheetState extends State<_CollectionActionSheet> {
  final _service = ClientManagementService();
  final _montoPagadoController = TextEditingController();
  final _montoCompromisoController = TextEditingController();
  final _obsController = TextEditingController();

  String _tipoGestion = 'llamada';
  String _resultado = 'compromiso_pago';
  DateTime? _fechaCompromiso;
  bool _loading = false;

  @override
  void dispose() {
    _montoPagadoController.dispose();
    _montoCompromisoController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    double? montoPagado;
    double? montoCompromiso;

    if (_resultado == 'pago_parcial') {
      montoPagado = double.tryParse(
        _montoPagadoController.text.replaceAll(',', '.'),
      );
      if (montoPagado == null || montoPagado <= 0) {
        _snack('Indica el monto pagado.');
        return;
      }
    }

    if (_resultado == 'compromiso_pago') {
      if (_fechaCompromiso == null) {
        _snack('Selecciona la fecha de compromiso.');
        return;
      }
      montoCompromiso = double.tryParse(
        _montoCompromisoController.text.replaceAll(',', '.'),
      );
      if (montoCompromiso == null || montoCompromiso <= 0) {
        _snack('Indica el monto comprometido.');
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final result = await _service.registerCollectionAction(
        clienteUserId: widget.item.userId,
        tipoGestion: _tipoGestion,
        resultado: _resultado,
        creditoId: widget.item.creditoId ?? widget.item.id,
        codCuentaCredito: widget.item.codCuentaCredito,
        montoPagado: montoPagado,
        fechaCompromiso: _fechaCompromiso,
        montoCompromiso: montoCompromiso,
        observaciones: _obsController.text.trim(),
      );

      if (!mounted) return;
      if (result.ok) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gestión registrada para ${widget.item.clienteNombre}.',
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _snack(_errorMessage(result.error));
      }
    } catch (_) {
      if (mounted) {
        _snack(
          'No se pudo registrar. Ejecuta 30_cobranza_completa.sql en Supabase.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorMessage(String? code) => switch (code) {
        'cliente_fuera_cartera' => 'El cliente no pertenece a tu cartera.',
        'tipo_gestion_invalido' => 'Tipo de gestión no válido.',
        'resultado_invalido' => 'Resultado no válido.',
        'no_auth' => 'Sesión expirada. Vuelve a iniciar sesión.',
        _ => 'No se pudo registrar la gestión.',
      };

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 8,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gestión de cobranza · ${widget.item.clienteNombre}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.item.diasMora} días de mora · '
              'S/ ${widget.item.montoVencido.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _tipoGestion,
              decoration: const InputDecoration(labelText: 'Tipo de gestión'),
              items: const [
                DropdownMenuItem(value: 'visita', child: Text('Visita')),
                DropdownMenuItem(value: 'llamada', child: Text('Llamada')),
                DropdownMenuItem(value: 'mensaje', child: Text('Mensaje')),
              ],
              onChanged: (v) => setState(() => _tipoGestion = v ?? 'llamada'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _resultado,
              decoration: const InputDecoration(labelText: 'Resultado'),
              items: const [
                DropdownMenuItem(
                  value: 'compromiso_pago',
                  child: Text('Compromiso de pago'),
                ),
                DropdownMenuItem(
                  value: 'pago_parcial',
                  child: Text('Pago parcial'),
                ),
                DropdownMenuItem(
                  value: 'sin_contacto',
                  child: Text('Sin contacto'),
                ),
                DropdownMenuItem(value: 'se_niega', child: Text('Se niega')),
              ],
              onChanged: (v) =>
                  setState(() => _resultado = v ?? 'compromiso_pago'),
            ),
            if (_resultado == 'pago_parcial') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _montoPagadoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(labelText: 'Monto pagado (S/)'),
              ),
            ],
            if (_resultado == 'compromiso_pago') ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.event, size: 18),
                label: Text(
                  _fechaCompromiso == null
                      ? 'Fecha de compromiso'
                      : 'Compromiso: ${_fechaCompromiso!.day.toString().padLeft(2, '0')}/'
                          '${_fechaCompromiso!.month.toString().padLeft(2, '0')}/'
                          '${_fechaCompromiso!.year}',
                ),
                onPressed: () async {
                  final hoy = DateTime.now();
                  final fecha = await showDatePicker(
                    context: context,
                    initialDate: hoy.add(const Duration(days: 3)),
                    firstDate: hoy,
                    lastDate: hoy.add(const Duration(days: 365)),
                  );
                  if (fecha != null) setState(() => _fechaCompromiso = fecha);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _montoCompromisoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Monto comprometido (S/)',
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _obsController,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Observaciones'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                ),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Registrar gestión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
