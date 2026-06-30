import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/main.dart' show PortfolioScreen;
import 'package:fuerza_ventas_app/models/advisor_profile.dart';
import 'package:fuerza_ventas_app/screens/modules/cartera_dia_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/application_status_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/campaigns_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/collections_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/credit_bureau_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/document_capture_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/new_credit_request_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/pre_evaluation_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/register_advisor_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/register_client_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/reports_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/roles_permissions_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/route_planning_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/simulator_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/transmission_screen.dart';
import 'package:fuerza_ventas_app/services/auth_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.profile});

  final AdvisorProfile? profile;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, Widget screen})>[
      (
        icon: Icons.person_add_rounded,
        label: 'Nuevo cliente',
        screen: const RegisterClientScreen(),
      ),
      (
        icon: Icons.badge_outlined,
        label: 'Nuevo asesor',
        screen: const RegisterAdvisorScreen(),
      ),
      (
        icon: Icons.work_outline_rounded,
        label: 'Cartera del día',
        screen: const CarteraDiaScreen(),
      ),
      (
        icon: Icons.list_alt_rounded,
        label: 'Lista de cartera',
        screen: const PortfolioScreen(),
      ),
      (
        icon: Icons.route_rounded,
        label: 'Planificación de ruta',
        screen: const RoutePlanningScreen(),
      ),
      (
        icon: Icons.badge_outlined,
        label: 'Ficha del cliente',
        screen: const PortfolioScreen(),
      ),
      (
        icon: Icons.fact_check_outlined,
        label: 'Pre-evaluación',
        screen: const PreEvaluationScreen(),
      ),
      (
        icon: Icons.post_add_rounded,
        label: 'Nueva solicitud',
        screen: const NewCreditRequestScreen(),
      ),
      (
        icon: Icons.calculate_outlined,
        label: 'Simulador',
        screen: const SimulatorScreen(),
      ),
      (
        icon: Icons.camera_alt_outlined,
        label: 'Captura de documentos',
        screen: const DocumentCaptureScreen(),
      ),
      (
        icon: Icons.query_stats_rounded,
        label: 'Consulta de buró',
        screen: const CreditBureauScreen(),
      ),
      (
        icon: Icons.send_to_mobile_rounded,
        label: 'Transmisión electrónica',
        screen: const TransmissionScreen(),
      ),
      (
        icon: Icons.timeline_rounded,
        label: 'Estado de solicitudes',
        screen: const ApplicationStatusScreen(),
      ),
      (
        icon: Icons.campaign_outlined,
        label: 'Campañas',
        screen: const CampaignsScreen(),
      ),
      (
        icon: Icons.payments_outlined,
        label: 'Cobranza',
        screen: const CollectionsScreen(),
      ),
      (
        icon: Icons.security_rounded,
        label: 'Roles y permisos',
        screen: const RolesPermissionsScreen(),
      ),
      (
        icon: Icons.bar_chart_rounded,
        label: 'Reportes',
        screen: const ReportsScreen(),
      ),
    ];

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.black),
            accountName: Text(
              profile?.nombreCompleto ?? 'Asesor SURGIR',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            accountEmail: Text(
              profile == null
                  ? 'Fuerza de Ventas'
                  : '${profile!.codigo} · ${profile!.nivel}',
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Color(0xFFFFE6E5),
              child: Icon(Icons.person, color: AppColors.brandRed),
            ),
          ),
          ...items.map(
            (item) => ListTile(
              leading: Icon(item.icon, color: AppColors.brandRed),
              title: Text(item.label),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => item.screen),
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              Navigator.pop(context);
              await AuthService().signOut();
            },
          ),
        ],
      ),
    );
  }
}
