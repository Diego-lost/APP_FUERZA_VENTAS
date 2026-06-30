import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/models/pre_eval_result.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';

class PreEvaluationScreen extends StatefulWidget {
  const PreEvaluationScreen({super.key});

  @override
  State<PreEvaluationScreen> createState() => _PreEvaluationScreenState();
}

class _PreEvaluationScreenState extends State<PreEvaluationScreen> {
  final _service = ClientManagementService();
  final _dniController = TextEditingController();
  final _nombresController = TextEditingController();
  final _ingresosController = TextEditingController();
  final _montoController = TextEditingController(text: '2000');
  final _negocioController = TextEditingController();
  final _destinoController = TextEditingController();

  PreEvalResult? _result;

  @override
  void dispose() {
    _dniController.dispose();
    _nombresController.dispose();
    _ingresosController.dispose();
    _montoController.dispose();
    _negocioController.dispose();
    _destinoController.dispose();
    super.dispose();
  }

  void _evaluar() {
    final ingresos = double.tryParse(_ingresosController.text.trim());
    final monto = double.tryParse(_montoController.text.trim());
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto solicitado válido.')),
      );
      return;
    }

    setState(() {
      _result = _service.preEvaluate(
        ingresosEstimados: ingresos ?? 0,
        montoSolicitado: monto,
      );
    });
  }

  Color _color(String calificacion) {
    switch (calificacion) {
      case 'APTO':
        return Colors.green.shade700;
      case 'REVISAR':
        return Colors.orange.shade800;
      case 'NO_PROCEDE':
        return Colors.red.shade700;
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Pre-evaluación')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            'Evalúa la capacidad de pago del prospecto según ingresos y monto.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _dniController,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'DNI (opcional)',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nombresController,
            decoration: const InputDecoration(
              labelText: 'Nombres (opcional)',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ingresosController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Ingresos estimados (mensual S/)',
              prefixIcon: Icon(Icons.trending_up),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _montoController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Monto solicitado (S/)',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _negocioController,
            decoration: const InputDecoration(
              labelText: 'Tipo de negocio (opcional)',
              prefixIcon: Icon(Icons.store_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destinoController,
            decoration: const InputDecoration(
              labelText: 'Destino del crédito (opcional)',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _evaluar,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Evaluar capacidad de pago'),
          ),
          if (result != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          result.calificacion == 'APTO'
                              ? Icons.check_circle
                              : result.calificacion == 'REVISAR'
                                  ? Icons.warning_amber_rounded
                                  : Icons.cancel_outlined,
                          color: _color(result.calificacion),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          result.calificacionLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: _color(result.calificacion),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Puntaje: ${result.puntaje}'),
                    Text(
                      'Ratio monto/ingresos: '
                      '${(result.ratioCuota * 100).toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 8),
                    Text(result.motivo),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
