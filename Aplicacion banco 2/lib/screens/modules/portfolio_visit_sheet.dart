import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/models/route_stop.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';

const _resultados = [
  ('visitado', 'Visitado'),
  ('no_encontrado', 'No encontrado'),
  ('reagendado', 'Reagendado'),
  ('negocio_cerrado', 'Negocio cerrado'),
];

Future<bool?> showPortfolioVisitSheet(
  BuildContext context, {
  required RouteStop stop,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PortfolioVisitSheet(stop: stop),
  );
}

class _PortfolioVisitSheet extends StatefulWidget {
  const _PortfolioVisitSheet({required this.stop});

  final RouteStop stop;

  @override
  State<_PortfolioVisitSheet> createState() => _PortfolioVisitSheetState();
}

class _PortfolioVisitSheetState extends State<_PortfolioVisitSheet> {
  final _service = ClientManagementService();
  final _obsController = TextEditingController();
  String _resultado = 'visitado';
  bool _loading = false;

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final result = await _service.registerPortfolioVisit(
        clienteUserId: widget.stop.userId,
        resultado: _resultado,
        observacion: _obsController.text.trim(),
      );
      if (!mounted) return;
      if (!result.ok) {
        _snack(result.error ?? 'No se pudo registrar la visita.');
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Registrar visita · ${widget.stop.nombreCompleto}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 4),
          Text(
            'DNI ${widget.stop.dni}',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Text(
            'Resultado de la visita',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _resultados.map((r) {
              final selected = _resultado == r.$1;
              return ChoiceChip(
                label: Text(r.$2),
                selected: selected,
                onSelected: (_) => setState(() => _resultado = r.$1),
                selectedColor: const Color(0xFFFFECEB),
                labelStyle: TextStyle(
                  color: selected ? AppColors.brandRed : AppColors.ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _obsController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Observación (opcional)',
              hintText: 'Detalle de la gestión…',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(_loading ? 'Guardando…' : 'Guardar visita'),
          ),
        ],
      ),
    );
  }
}
