import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/core/supabase/supabase_bootstrap.dart';
import 'package:fuerza_ventas_app/services/auth_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';

class RolesPermissionsScreen extends StatefulWidget {
  const RolesPermissionsScreen({super.key});

  @override
  State<RolesPermissionsScreen> createState() => _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState extends State<RolesPermissionsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await SupabaseBootstrap.client.rpc('asesor_obtener_perfil_rbac');
      final map = Map<String, dynamic>.from(raw as Map);
      if (!mounted) return;
      if (map['ok'] != true) {
        setState(() {
          _error = map['error'] == 'no_auth'
              ? 'No autenticado (401).'
              : 'Acceso denegado (403).';
          _loading = false;
        });
        return;
      }
      setState(() {
        _data = map;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo cargar RBAC. Ejecuta 17_seguridad_asesores_rbac.sql en Supabase.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roles y permisos (RBAC)'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final data = _data!;
    final permisos = Map<String, dynamic>.from(data['permisos'] as Map);
    final matriz = (data['matriz'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['nombres']} ${data['apellidos']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Código ${data['codigo']} · Perfil: ${data['perfil']}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sesión JWT validada por Supabase Auth. '
                  'Token almacenado en flutter_secure_storage.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Tus permisos',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        ...permisos.entries.map(
          (e) => _PermisoTile(
            label: _labelPermiso(e.key),
            permitido: e.value == true,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Matriz de roles (backend)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        ...matriz.map((row) {
          final r = Map<String, dynamic>.from(row as Map);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                r['rol'] as String? ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Reportes: ${r['reportes'] == true ? 'Sí' : 'No'} · '
                'Admin: ${r['admin'] == true ? 'Sí' : 'No'}',
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final token = await AuthService().getStoredToken();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  token != null
                      ? 'JWT en secure storage (${token.length} caracteres).'
                      : 'Sin token en secure storage (sesión Supabase activa).',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: const Icon(Icons.security_rounded),
          label: const Text('Verificar JWT en secure storage'),
        ),
      ],
    );
  }

  String _labelPermiso(String key) {
    switch (key) {
      case 'cartera_clientes':
        return 'Ver cartera de clientes';
      case 'originar_credito':
        return 'Originar solicitudes de crédito';
      case 'consulta_buro':
        return 'Consulta de buró';
      case 'transmision_expediente':
        return 'Transmisión de expediente';
      case 'reportes_productividad':
        return 'Reportes de productividad (supervisor)';
      case 'administracion':
        return 'Administración del sistema';
      default:
        return key;
    }
  }
}

class _PermisoTile extends StatelessWidget {
  const _PermisoTile({required this.label, required this.permitido});

  final String label;
  final bool permitido;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        permitido ? Icons.check_circle : Icons.cancel_outlined,
        color: permitido ? Colors.green : Colors.red.shade300,
      ),
      title: Text(label),
      trailing: Text(
        permitido ? 'Permitido' : 'Denegado',
        style: TextStyle(
          color: permitido ? Colors.green.shade700 : Colors.red.shade400,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
