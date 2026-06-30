import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/core/supabase/supabase_bootstrap.dart';
import 'package:fuerza_ventas_app/core/supabase/supabase_config.dart';
import 'package:fuerza_ventas_app/main.dart';
import 'package:fuerza_ventas_app/services/auth_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SupabaseBootstrap.isReady) {
      return const LoginScreen(showConfigWarning: true);
    }

    final auth = AuthService();

    return StreamBuilder(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;
        if (session != null) {
          return const DashboardScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class SupabaseConfigBanner extends StatelessWidget {
  const SupabaseConfigBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (SupabaseConfig.isConfigured &&
        SupabaseConfig.hasValidAnonKeyFormat &&
        SupabaseBootstrap.isReady) {
      return const SizedBox.shrink();
    }

    final issues = SupabaseConfig.configurationIssues;
    final message = issues.isEmpty
        ? 'Copia .env.example a .env con tu Project URL y anon key. '
            'Ejecuta 10_fuerza_ventas_auth.sql en Supabase.'
        : issues.join('\n');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.ink,
            ),
      ),
    );
  }
}
