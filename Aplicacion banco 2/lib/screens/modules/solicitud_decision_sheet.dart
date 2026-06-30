import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuerza_ventas_app/models/credit_application.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';

Future<bool?> showSolicitudDecisionSheet(
  BuildContext context, {
  required CreditApplication solicitud,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SolicitudDecisionSheet(solicitud: solicitud),
  );
}

class _SolicitudDecisionSheet extends StatefulWidget {
  const _SolicitudDecisionSheet({required this.solicitud});

  final CreditApplication solicitud;

  @override
  State<_SolicitudDecisionSheet> createState() =>
      _SolicitudDecisionSheetState();
}

class _SolicitudDecisionSheetState extends State<_SolicitudDecisionSheet> {
  final _service = ClientManagementService();
  final _obsController = TextEditingController();
  final _montoController = TextEditingController();

  String _decision = 'aprobar';
  bool _loading = false;

  @override
  void dispose() {
    _obsController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    double? montoAjustado;
    if (_decision == 'aprobar_monto_reducido') {
      montoAjustado = double.tryParse(_montoController.text.replaceAll(',', '.'));
      if (montoAjustado == null || montoAjustado <= 0) {
        _snack('Indica un monto válido menor al solicitado.');
        return;
      }
      if (montoAjustado >= widget.solicitud.monto) {
        _snack('El monto ajustado debe ser menor a S/ ${widget.solicitud.monto.toStringAsFixed(2)}.');
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final result = await _service.respondToSolicitud(
        solicitudId: widget.solicitud.id,
        decision: _decision,
        observaciones: _obsController.text.trim().isEmpty
            ? null
            : _obsController.text.trim(),
        montoAjustado: montoAjustado,
      );

      if (!mounted) return;
      if (result.ok) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_successMessage(result)),
            backgroundColor: _decision == 'rechazar'
                ? Colors.red.shade700
                : Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _snack(_errorMessage(result.error));
      }
    } catch (_) {
      if (mounted) _snack('No se pudo registrar la decisión.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _successMessage(SolicitudDecisionResult result) {
    switch (_decision) {
      case 'rechazar':
        return 'Solicitud rechazada. El cliente fue notificado.';
      case 'elevar_comite':
        return 'Solicitud elevada al comité.';
      case 'aprobar_monto_reducido':
        return 'Aprobada S/ ${result.monto?.toStringAsFixed(2) ?? '—'}. '
            'Desembolsa desde Transmisión cuando corresponda.';
      default:
        return 'Solicitud aprobada. Desembolsa desde Transmisión cuando corresponda.';
    }
  }

  String _errorMessage(String? code) {
    switch (code) {
      case 'estado_invalido':
        return 'Esta solicitud ya fue resuelta.';
      case 'desembolso_fallido':
        return 'Se aprobó pero falló el desembolso. Ejecuta el script 29 en Supabase.';
      case 'monto_requerido':
      case 'monto_debe_ser_menor':
        return 'Indica un monto menor al solicitado.';
      case 'cliente_no_cartera':
        return 'El cliente no está en tu cartera.';
      case 'no_encontrada':
        return 'Solicitud no encontrada.';
      default:
        return 'No se pudo registrar la decisión.';
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final s = widget.solicitud;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Decisión del asesor',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${s.clienteNombre ?? 'Cliente'} · S/ ${s.monto.toStringAsFixed(2)} · ${s.plazoMeses} meses',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          _DecisionTile(
            value: 'aprobar',
            groupValue: _decision,
            title: 'Aprobar',
            subtitle: 'Aprueba; el desembolso se hace en Transmisión',
            icon: Icons.check_circle_outline,
            color: Colors.green,
            onChanged: (v) => setState(() => _decision = v!),
          ),
          _DecisionTile(
            value: 'aprobar_monto_reducido',
            groupValue: _decision,
            title: 'Aprobar con monto reducido',
            subtitle: 'Aprueba un monto menor al solicitado',
            icon: Icons.tune_rounded,
            color: Colors.teal,
            onChanged: (v) => setState(() => _decision = v!),
          ),
          _DecisionTile(
            value: 'elevar_comite',
            groupValue: _decision,
            title: 'Elevar a comité',
            subtitle: 'Requiere revisión del comité de crédito',
            icon: Icons.groups_outlined,
            color: Colors.blue,
            onChanged: (v) => setState(() => _decision = v!),
          ),
          _DecisionTile(
            value: 'rechazar',
            groupValue: _decision,
            title: 'Rechazar',
            subtitle: 'No procede la solicitud',
            icon: Icons.cancel_outlined,
            color: Colors.red,
            onChanged: (v) => setState(() => _decision = v!),
          ),
          if (_decision == 'aprobar_monto_reducido') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _montoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Monto aprobado (S/)',
                hintText: 'Menor a ${s.monto.toStringAsFixed(2)}',
                border: const OutlineInputBorder(),
                prefixText: 'S/ ',
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _obsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Observaciones (opcional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.gavel_rounded),
            label: Text(_loading ? 'Guardando...' : 'Confirmar decisión'),
          ),
        ],
      ),
    );
  }
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onChanged,
  });

  final String value;
  final String groupValue;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Radio<String>(
                  value: value,
                  groupValue: groupValue,
                  onChanged: onChanged,
                  activeColor: color,
                ),
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
