import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';
import 'package:fuerza_ventas_app/utils/credit_simulator.dart';

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  final _montoController = TextEditingController(text: '3000');
  final _plazoController = TextEditingController(text: '12');
  double _tea = 60;
  CreditSimulation? _result;

  @override
  void dispose() {
    _montoController.dispose();
    _plazoController.dispose();
    super.dispose();
  }

  void _calcular() {
    final monto = double.tryParse(_montoController.text.trim());
    final plazo = int.tryParse(_plazoController.text.trim());
    if (monto == null || monto <= 0 || plazo == null || plazo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa monto y plazo válidos.')),
      );
      return;
    }

    setState(() {
      _result = CreditSimulator.calculate(
        monto: monto,
        plazoMeses: plazo,
        teaPorcentaje: _tea,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Simulador de crédito')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
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
          Text('TEA referencial: ${_tea.toStringAsFixed(0)}%',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(
            value: _tea,
            min: 40,
            max: 80,
            divisions: 8,
            label: '${_tea.toStringAsFixed(0)}%',
            activeColor: AppColors.brandRed,
            onChanged: (v) => setState(() => _tea = v),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _calcular,
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Calcular cuota'),
          ),
          if (result != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resultado',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _Row('Cuota mensual',
                        'S/ ${result.cuotaMensual.toStringAsFixed(2)}'),
                    _Row('Total a pagar',
                        'S/ ${result.totalPagar.toStringAsFixed(2)}'),
                    _Row('Costo financiero',
                        'S/ ${result.costoFinanciero.toStringAsFixed(2)}'),
                    _Row('TEA usada',
                        '${result.teaReferencial.toStringAsFixed(0)}%'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cronograma de cuotas (RF-47)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Cuota')),
                    DataColumn(label: Text('Capital')),
                    DataColumn(label: Text('Interés')),
                    DataColumn(label: Text('Saldo')),
                  ],
                  rows: result.cronograma
                      .map(
                        (c) => DataRow(cells: [
                          DataCell(Text('${c.nroCuota}')),
                          DataCell(Text('S/ ${c.montoCuota.toStringAsFixed(2)}')),
                          DataCell(Text('S/ ${c.montoCapital.toStringAsFixed(2)}')),
                          DataCell(Text('S/ ${c.montoInteres.toStringAsFixed(2)}')),
                          DataCell(Text('S/ ${c.saldo.toStringAsFixed(2)}')),
                        ]),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
