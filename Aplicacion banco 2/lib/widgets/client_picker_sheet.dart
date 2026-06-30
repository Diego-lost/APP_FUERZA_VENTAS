import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';
import 'package:fuerza_ventas_app/models/portfolio_client.dart';
import 'package:fuerza_ventas_app/services/advisor_data_service.dart';

Future<PortfolioClient?> showClientPicker(BuildContext context) async {
  final data = AdvisorDataService();
  final clients = await data.fetchPortfolio();
  if (!context.mounted) return null;

  if (clients.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No tienes clientes en tu cartera.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return null;
  }

  return showModalBottomSheet<PortfolioClient>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Selecciona un cliente',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final client = clients[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          client.nombreCompleto,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'DNI ${client.dni}'
                          '${client.distrito != null ? ' · ${client.distrito}' : ''}'
                          '${client.diasMora > 0 ? ' · Mora ${client.diasMora}d' : ''}',
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.brandRed,
                        ),
                        onTap: () => Navigator.pop(context, client),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
