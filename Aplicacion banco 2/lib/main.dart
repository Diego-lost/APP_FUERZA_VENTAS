import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/core/supabase/supabase_bootstrap.dart';
import 'package:fuerza_ventas_app/models/advisor_profile.dart';
import 'package:fuerza_ventas_app/models/portfolio_client.dart';
import 'package:fuerza_ventas_app/screens/modules/application_status_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/campaigns_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/cartera_dia_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/collections_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/credit_bureau_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/document_capture_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/new_credit_request_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/pre_evaluation_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/reports_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/roles_permissions_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/register_client_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/route_planning_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/simulator_screen.dart';
import 'package:fuerza_ventas_app/screens/client_detail_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/transmission_screen.dart';
import 'package:fuerza_ventas_app/widgets/app_drawer.dart';
import 'package:fuerza_ventas_app/models/route_stop.dart';
import 'package:fuerza_ventas_app/services/advisor_data_service.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/services/auth_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';
import 'package:fuerza_ventas_app/widgets/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.init();
  runApp(const FuerzaVentasApp());
}

class AppAssets {
  static const String surgirLogo = 'assets/images/surgir_logo.png';
}

class FuerzaVentasApp extends StatelessWidget {
  const FuerzaVentasApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandRed,
      brightness: Brightness.light,
      primary: AppColors.brandRed,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.ink,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fuerza de Ventas',
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: AppColors.softBg,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.ink,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.brandRed, width: 1.4),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AuthGate()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: SurgirLogo(height: 120),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.showConfigWarning = false});

  final bool showConfigWarning;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codigoController = TextEditingController(text: 'AG-001-01');
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCodigo();
  }

  Future<void> _loadRememberedCodigo() async {
    final codigo = await AuthService().getRememberedCodigo();
    if (codigo != null && mounted) {
      _codigoController.text = codigo;
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      _showError('Ingresa tu código de asesor.');
      return;
    }

    if (!SupabaseBootstrap.isReady) {
      _showError('Configura el archivo .env con tu proyecto Supabase.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService().signInWithCodigo(
        codigo: codigo,
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('No se pudo iniciar sesión. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  const _SurgirLogoHeader(),
                  const SizedBox(height: 20),
                  if (widget.showConfigWarning) const SupabaseConfigBanner(),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Bienvenido',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Ingresa con tu código de asesor',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _codigoController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Código de asesor',
                              hintText: 'AG-001-01',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brandRed,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _loading ? null : _onSubmit,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(_loading ? 'Ingresando...' : 'Ingresar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Prueba: AG-001-01 · Contraseña: Asesor2026!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _data = AdvisorDataService();
  final _mgmt = ClientManagementService();
  AdvisorProfile? _profile;
  List<RouteStop> _carteraDia = [];
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
      final results = await Future.wait([
        _data.fetchResumen(),
        _mgmt.fetchRouteDay(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as AdvisorProfile?;
        _carteraDia = results[1] as List<RouteStop>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar tu cartera.';
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final modules = <SalesModule>[
      SalesModule(
        title: 'Registrar nuevo cliente',
        subtitle: 'Alta con DNI nuevo en tu cartera',
        icon: Icons.person_add_rounded,
        onTap: (context) => _openRegisterClient(context),
      ),
      SalesModule(
        title: 'Cartera del día',
        subtitle: 'Visitas pendientes y registro en campo',
        icon: Icons.work_outline_rounded,
        onTap: (context) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CarteraDiaScreen(),
            ),
          );
        },
      ),
      SalesModule(
        title: 'Lista de cartera',
        subtitle: 'Todos tus clientes asignados',
        icon: Icons.list_alt_rounded,
        onTap: (context) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PortfolioScreen(),
            ),
          );
        },
      ),
      const SalesModule(
        title: 'Planificacion de ruta',
        subtitle: 'Mapa de visitas del dia',
        icon: Icons.route_rounded,
        onTap: _openRoutePlanning,
      ),
      SalesModule(
        title: 'Ficha del cliente',
        subtitle: 'Historial crediticio y datos generales',
        icon: Icons.badge_outlined,
        onTap: (context) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PortfolioScreen(),
            ),
          );
        },
      ),
      const SalesModule(
        title: 'Nueva solicitud de credito',
        subtitle: 'Captura de datos en campo (offline-first)',
        icon: Icons.post_add_rounded,
        onTap: _openNewCreditRequest,
      ),
      const SalesModule(
        title: 'Captura de documentos',
        subtitle: 'Foto de DNI y documentos legales',
        icon: Icons.camera_alt_outlined,
        onTap: _openDocumentCapture,
      ),
      const SalesModule(
        title: 'Consulta de buro de credito',
        subtitle: 'Verificacion crediticia en campo',
        icon: Icons.query_stats_rounded,
        onTap: _openCreditBureau,
      ),
      const SalesModule(
        title: 'Transmision electronica',
        subtitle: 'Envio de solicitud al sistema central',
        icon: Icons.send_to_mobile_rounded,
        onTap: _openTransmission,
      ),
      const SalesModule(
        title: 'Estado de solicitudes',
        subtitle: 'Enviado > comite > aprobado > desembolsado',
        icon: Icons.timeline_rounded,
        onTap: _openApplicationStatus,
      ),
      const SalesModule(
        title: 'Pre-evaluacion',
        subtitle: 'Capacidad de pago del prospecto',
        icon: Icons.fact_check_outlined,
        onTap: _openPreEvaluation,
      ),
      const SalesModule(
        title: 'Simulador de credito',
        subtitle: 'Calcula cuota y costo financiero',
        icon: Icons.calculate_outlined,
        onTap: _openSimulator,
      ),
      const SalesModule(
        title: 'Cobranza del dia',
        subtitle: 'Clientes en mora de tu cartera',
        icon: Icons.payments_outlined,
        onTap: _openCollections,
      ),
      const SalesModule(
        title: 'Campanas activas',
        subtitle: 'Renovaciones y ampliaciones',
        icon: Icons.campaign_outlined,
        onTap: _openCampaigns,
      ),
      const SalesModule(
        title: 'Roles y permisos (RBAC)',
        subtitle: 'Matriz de acceso JWT + perfiles',
        icon: Icons.security_rounded,
        onTap: _openRolesPermissions,
      ),
      const SalesModule(
        title: 'Reportes del mes',
        subtitle: 'Solicitudes y colocacion',
        icon: Icons.bar_chart_rounded,
        onTap: _openReports,
      ),
    ];

    final profile = _profile;
    final visitasPendientes = _carteraDia.length;
    final montoCartera = _carteraDia.fold<double>(
      0,
      (sum, s) => sum + (s.solicitudMonto ?? 0),
    );
    final proximaVisita = _carteraDia.isEmpty
        ? null
        : (_carteraDia.toList()
              ..sort((a, b) => b.prioridad.compareTo(a.prioridad)))
            .first;
    final summary = profile == null
        ? 'Cargando resumen de cartera...'
        : 'Tienes ${profile.totalClientes} clientes en cartera'
            '${profile.clientesEnMora > 0 ? ' y ${profile.clientesEnMora} en mora' : ''}.';

    return Scaffold(
      drawer: AppDrawer(profile: profile),
      appBar: AppBar(
        toolbarHeight: 78,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SurgirLogo(height: 36),
            const SizedBox(height: 4),
            Text(
              profile == null
                  ? 'Panel de Fuerza de Ventas'
                  : '${profile.nombreCompleto} · ${profile.codigo}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFFFE6E5),
              child: Icon(Icons.person, color: AppColors.brandRed),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.today_rounded, color: AppColors.brandRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _loading
                        ? const Text('Cargando cartera...')
                        : Text(
                            summary,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ),
            if (profile?.zonaAsignada != null) ...[
              const SizedBox(height: 8),
              Text(
                'Zona: ${profile!.zonaAsignada} · Nivel: ${profile.nivel}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
            if (!_loading && _carteraDia.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _DashboardKpi(
                      icon: Icons.map_outlined,
                      label: 'Visitas pendientes',
                      value: '$visitasPendientes',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DashboardKpi(
                      icon: Icons.payments_outlined,
                      label: 'Monto solicitudes',
                      value: 'S/ ${montoCartera.toStringAsFixed(0)}',
                    ),
                  ),
                ],
              ),
            ],
            if (proximaVisita != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CarteraDiaScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.flag_rounded, color: Colors.amber.shade900),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Próxima visita prioritaria',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${proximaVisita.nombreCompleto} · ${proximaVisita.tipoGestionLabel}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Modulos clave',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                itemCount: modules.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.03,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (_, index) {
                  final item = modules[index];
                  return _ModuleCard(
                    module: item,
                    onTap: () {
                      if (item.onTap != null) {
                        item.onTap!(context);
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ModuleDetailScreen(module: item),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _data = AdvisorDataService();
  List<PortfolioClient> _clients = [];
  bool _loading = true;
  String? _error;
  String _filter = 'todos';
  String _search = '';

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
      final clients = await _data.fetchPortfolio();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la cartera.';
        _loading = false;
      });
    }
  }

  List<PortfolioClient> get _visible {
    var list = _clients;
    if (_filter == 'mora') {
      list = list.where((c) => c.diasMora > 0).toList();
    } else if (_filter == 'al_dia') {
      list = list.where((c) => c.diasMora == 0).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (c) =>
                c.nombreCompleto.toLowerCase().contains(q) ||
                c.dni.contains(q) ||
                (c.distrito?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return list;
  }

  Future<void> _openNewClient() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RegisterClientScreen()),
    );
    if (created == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartera de clientes'),
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
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v.trim()),
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nombre, DNI o distrito',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Row(
                        children: [
                          _PortfolioFilterChip(
                            label: 'Todos',
                            selected: _filter == 'todos',
                            onTap: () => setState(() => _filter = 'todos'),
                          ),
                          _PortfolioFilterChip(
                            label: 'En mora',
                            selected: _filter == 'mora',
                            onTap: () => setState(() => _filter = 'mora'),
                          ),
                          _PortfolioFilterChip(
                            label: 'Al día',
                            selected: _filter == 'al_dia',
                            onTap: () => setState(() => _filter = 'al_dia'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _clients.isEmpty
                                          ? 'Aún no tienes clientes en cartera.\n'
                                              'Registra uno nuevo con un DNI distinto.'
                                          : 'No hay clientes con ese filtro.',
                                      textAlign: TextAlign.center,
                                    ),
                                    if (_clients.isEmpty) ...[
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                        onPressed: _openNewClient,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.brandRed,
                                        ),
                                        icon: const Icon(Icons.person_add_rounded),
                                        label: const Text('Registrar nuevo cliente'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(14),
                              itemCount: visible.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, index) {
                                final client = visible[index];
                        return Card(
                          child: ListTile(
                            title: Text(
                              client.nombreCompleto,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'DNI ${client.dni}'
                              '${client.distrito != null ? ' · ${client.distrito}' : ''}'
                              '${client.telefono != null ? '\n${client.telefono}' : ''}'
                              '\nS/ ${(client.saldoCuenta ?? 0).toStringAsFixed(2)} saldo cuenta',
                            ),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (client.diasMora > 0)
                                  Chip(
                                    label: Text('Mora ${client.diasMora}d'),
                                    backgroundColor: const Color(0xFFFFECEB),
                                  )
                                else
                                  Text(
                                    client.prioridadLabel,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ClientDetailScreen(
                                    userId: client.userId,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewClient,
        backgroundColor: AppColors.brandRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Nuevo cliente'),
      ),
    );
  }
}

class _DashboardKpi extends StatelessWidget {
  const _DashboardKpi({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.brandRed, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PortfolioFilterChip extends StatelessWidget {
  const _PortfolioFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFFFFECEB),
        checkmarkColor: AppColors.brandRed,
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onTap});

  final SalesModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(module.icon, color: AppColors.brandRed),
              ),
              const SizedBox(height: 10),
              Text(
                module.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  module.subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.8,
                    height: 1.22,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Text(
                    'Abrir',
                    style: TextStyle(
                      color: AppColors.brandRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.brandRed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModuleDetailScreen extends StatelessWidget {
  const ModuleDetailScreen({super.key, required this.module});

  final SalesModule module;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(module.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(module.icon, color: AppColors.brandRed),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        module.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  module.subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD4D1)),
                  ),
                  child: const Text(
                    'Este módulo aún no tiene pantalla dedicada. '
                    'Usa Cartera o Ficha del cliente.',
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

class SurgirLogo extends StatelessWidget {
  const SurgirLogo({super.key, this.height = 72});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.surgirLogo,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      errorBuilder: (context, error, stackTrace) => Text(
        'SURGIR',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.brandRed,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _SurgirLogoHeader extends StatelessWidget {
  const _SurgirLogoHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandRed.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const SurgirLogo(height: 88),
          const SizedBox(height: 14),
          Text(
            'Fuerza de Ventas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gestion diaria de oficiales de credito',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFB0B7C3),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class SalesModule {
  const SalesModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final void Function(BuildContext context)? onTap;
}

void _openRegisterClient(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const RegisterClientScreen()),
  );
}

void _openRoutePlanning(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const RoutePlanningScreen()),
  );
}

void _openNewCreditRequest(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const NewCreditRequestScreen()),
  );
}

void _openDocumentCapture(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const DocumentCaptureScreen()),
  );
}

void _openCreditBureau(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const CreditBureauScreen()),
  );
}

void _openTransmission(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const TransmissionScreen()),
  );
}

void _openApplicationStatus(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ApplicationStatusScreen()),
  );
}

void _openPreEvaluation(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const PreEvaluationScreen()),
  );
}

void _openSimulator(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const SimulatorScreen()),
  );
}

void _openCollections(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const CollectionsScreen()),
  );
}

void _openCampaigns(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const CampaignsScreen()),
  );
}

void _openReports(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ReportsScreen()),
  );
}

void _openRolesPermissions(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const RolesPermissionsScreen()),
  );
}
