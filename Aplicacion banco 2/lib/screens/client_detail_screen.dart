import 'package:flutter/material.dart';
import 'package:fuerza_ventas_app/models/client_ficha.dart';
import 'package:fuerza_ventas_app/models/credit_application.dart';
import 'package:fuerza_ventas_app/screens/modules/client_location_map_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/new_credit_request_screen.dart';
import 'package:fuerza_ventas_app/screens/modules/solicitud_decision_sheet.dart';
import 'package:fuerza_ventas_app/services/advisor_data_service.dart';
import 'package:fuerza_ventas_app/services/client_management_service.dart';
import 'package:fuerza_ventas_app/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({
    super.key,
    required this.userId,
    this.solicitudId,
    this.solicitudExpediente,
    this.solicitudMonto,
    this.solicitudPlazo,
    this.solicitudEstado,
  });

  final String userId;
  final String? solicitudId;
  final String? solicitudExpediente;
  final double? solicitudMonto;
  final int? solicitudPlazo;
  final String? solicitudEstado;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final _data = AdvisorDataService();
  final _mgmt = ClientManagementService();
  ClientFicha? _ficha;
  bool _loading = true;
  String? _error;
  String? _solicitudEstado;
  String? _activeSolicitudId;

  static const _reviewableEstados = {'enviado', 'pendiente'};
  static const _bannerEstados = {'enviado', 'pendiente', 'en_comite'};

  CreditApplication? _pendingSolicitud(ClientFicha ficha) {
    if (widget.solicitudId != null) {
      return CreditApplication(
        id: widget.solicitudId!,
        userId: widget.userId,
        monto: widget.solicitudMonto ?? 0,
        plazoMeses: widget.solicitudPlazo ?? 0,
        cuotaMensual: 0,
        estado: _solicitudEstado ?? widget.solicitudEstado ?? 'pendiente',
      );
    }
    for (final s in ficha.solicitudes) {
      if (_bannerEstados.contains(s.estado)) return s;
    }
    return null;
  }

  Future<void> _openDecision(CreditApplication solicitud) async {
    final ok = await showSolicitudDecisionSheet(context, solicitud: solicitud);
    if (ok == true && mounted) {
      await _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _solicitudEstado = widget.solicitudEstado;
    _activeSolicitudId = widget.solicitudId;
    _load();
  }

  Future<void> _attendSolicitudIfNeeded() async {
    final id = _activeSolicitudId ?? widget.solicitudId;
    if (id == null || _solicitudEstado != 'enviado') return;
    final ok = await _mgmt.attendClientSolicitud(id);
    if (ok && mounted) {
      setState(() {
        _solicitudEstado = 'pendiente';
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ficha = await _data.fetchClientFicha(widget.userId);
      if (!mounted) return;
      setState(() {
        _ficha = ficha;
        _loading = false;
        if (ficha == null) {
          _error = 'Cliente no encontrado en tu cartera.';
        } else {
          final pending = _pendingSolicitud(ficha);
          if (pending != null) {
            _activeSolicitudId = pending.id;
            _solicitudEstado = pending.estado;
          }
        }
      });
      await _attendSolicitudIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar la ficha: $e';
      });
    }
  }

  Future<void> _call(String? telefono) async {
    if (telefono == null || telefono.isEmpty) {
      _snack('Sin teléfono registrado.');
      return;
    }
    final uri = Uri(scheme: 'tel', path: telefono);
    if (!await launchUrl(uri)) _snack('No se pudo abrir el marcador.');
  }

  Future<void> _openMaps(ClientProfileData c) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClientLocationMapScreen(
          userId: widget.userId,
          clientName: c.nombreCompleto,
          direccion: c.direccionNegocio,
          lat: c.latNegocio,
          lng: c.lngNegocio,
          distrito: c.distrito,
          editable: true,
        ),
      ),
    );
    if (mounted) _load();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Color _sbsColor(String? cal) {
    switch (cal) {
      case 'Normal':
        return Colors.green.shade700;
      case 'CPP':
        return Colors.orange.shade800;
      case 'Deficiente':
      case 'Dudoso':
      case 'Perdida':
        return Colors.red.shade700;
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ficha = _ficha;
    final pendingSolicitud =
        ficha != null ? _pendingSolicitud(ficha) : null;
    final pendingEstado =
        _solicitudEstado ?? pendingSolicitud?.estado ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(ficha?.cliente.nombreCompleto ?? 'Ficha del cliente'),
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : ficha == null
                  ? const Center(child: Text('Sin datos.'))
                  : DefaultTabController(
                      length: 4,
                      child: Column(
                        children: [
                          if (pendingSolicitud != null)
                            _PendingSolicitudBanner(
                              solicitud: pendingSolicitud,
                              estado: pendingEstado.isEmpty
                                  ? pendingSolicitud.estado
                                  : pendingEstado,
                              expediente: widget.solicitudExpediente,
                              onEvaluar: _reviewableEstados.contains(
                                pendingEstado.isEmpty
                                    ? pendingSolicitud.estado
                                    : pendingEstado,
                              )
                                  ? () => _openDecision(pendingSolicitud)
                                  : null,
                            ),
                          _HeaderActions(
                            ficha: ficha,
                            onCall: () => _call(ficha.cliente.telefono),
                            onMap: () => _openMaps(ficha.cliente),
                            onNewRequest: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const NewCreditRequestScreen(),
                                ),
                              );
                            },
                          ),
                          const TabBar(
                            isScrollable: true,
                            labelColor: AppColors.brandRed,
                            indicatorColor: AppColors.brandRed,
                            tabs: [
                              Tab(text: 'Datos'),
                              Tab(text: 'Créditos'),
                              Tab(text: 'Buró'),
                              Tab(text: 'Movimientos'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _DatosTab(ficha: ficha, sbsColor: _sbsColor),
                                _CreditosTab(ficha: ficha),
                                _BuroTab(ficha: ficha, sbsColor: _sbsColor),
                                _MovimientosTab(ficha: ficha),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.ficha,
    required this.onCall,
    required this.onMap,
    required this.onNewRequest,
  });

  final ClientFicha ficha;
  final VoidCallback onCall;
  final VoidCallback onMap;
  final VoidCallback onNewRequest;

  @override
  Widget build(BuildContext context) {
    final c = ficha.cliente;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c.nombreCompleto,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            'DNI ${c.dni}'
            '${c.distrito != null ? ' · ${c.distrito}' : ''}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActionChip(
                icon: Icons.phone_outlined,
                label: 'Llamar',
                onTap: onCall,
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.map_outlined,
                label: 'Mapa',
                onTap: onMap,
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.post_add_outlined,
                label: 'Solicitud',
                onTap: onNewRequest,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.brandRed),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: const Color(0xFFFFECEB),
    );
  }
}

class _DatosTab extends StatelessWidget {
  const _DatosTab({required this.ficha, required this.sbsColor});

  final ClientFicha ficha;
  final Color Function(String?) sbsColor;

  @override
  Widget build(BuildContext context) {
    final c = ficha.cliente;
    final p = ficha.posicion;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _SectionCard(
          title: 'Datos del cliente',
          children: [
            _InfoRow('Calificación SBS', c.calificacionSbs ?? 'Normal',
                valueColor: sbsColor(c.calificacionSbs)),
            if (c.edad != null) _InfoRow('Edad', '${c.edad} años'),
            if (c.telefono != null) _InfoRow('Teléfono', c.telefono!),
            if (c.nombreNegocio != null)
              _InfoRow('Nombre negocio', c.nombreNegocio!),
            if (c.tipoNegocio != null) _InfoRow('Tipo negocio', c.tipoNegocio!),
            if (c.antiguedadNegocioMeses != null)
              _InfoRow(
                'Antigüedad negocio',
                '${c.antiguedadNegocioMeses} meses',
              ),
            if (c.tenenciaLocal != null)
              _InfoRow('Tenencia local', c.tenenciaLocal!),
            if (c.direccionNegocio != null)
              _InfoRow('Dirección', c.direccionNegocio!),
            if (c.provincia != null || c.departamento != null)
              _InfoRow(
                'Ubicación',
                '${c.distrito ?? ''}${c.provincia != null ? ', ${c.provincia}' : ''}${c.departamento != null ? ', ${c.departamento}' : ''}',
              ),
            if (c.estadoCliente != null)
              _InfoRow('Estado', c.estadoCliente!),
          ],
        ),
        const SizedBox(height: 10),
        _SectionCard(
          title: 'Posición consolidada',
          children: [
            _InfoRow(
              'Deuda total SBS',
              'S/ ${p.deudaTotal.toStringAsFixed(2)}',
            ),
            _InfoRow('Saldo en cuentas', 'S/ ${p.saldoTotal.toStringAsFixed(2)}'),
            _InfoRow('Cuentas al día', '${p.cuentasVigentes}'),
            _InfoRow('Cuentas en mora', '${p.cuentasMora}'),
            _InfoRow('Mayor mora', '${p.diasMayorMora} días'),
          ],
        ),
        if (ficha.oferta != null) ...[
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Oferta pre-aprobada',
            highlight: true,
            children: [
              _InfoRow(
                'Monto máximo',
                'S/ ${ficha.oferta!.montoMaximo.toStringAsFixed(2)}',
              ),
              _InfoRow('Plazo sugerido', '${ficha.oferta!.plazoMeses} meses'),
              _InfoRow(
                'TEA referencial',
                '${ficha.oferta!.teaReferencial.toStringAsFixed(0)}%',
              ),
              if (ficha.oferta!.scoreConfianza != null)
                _InfoRow(
                  'Score confianza',
                  '${ficha.oferta!.scoreConfianza}',
                ),
            ],
          ),
        ],
        if (ficha.fichaCampo != null) ...[
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Última visita de campo',
            children: [
              if (ficha.fichaCampo!.fechaVisita != null)
                _InfoRow(
                  'Fecha',
                  _fmtDate(ficha.fichaCampo!.fechaVisita!),
                ),
              if (ficha.fichaCampo!.asesorNombre != null)
                _InfoRow('Asesor', ficha.fichaCampo!.asesorNombre!),
              if (ficha.fichaCampo!.agencia != null)
                _InfoRow('Agencia', ficha.fichaCampo!.agencia!),
              if (ficha.fichaCampo!.scoreCampo != null)
                _InfoRow('Score campo', '${ficha.fichaCampo!.scoreCampo}'),
              if (ficha.fichaCampo!.scoreFinal != null)
                _InfoRow('Score final', '${ficha.fichaCampo!.scoreFinal}'),
              if (ficha.fichaCampo!.segmentoResultante != null)
                _InfoRow('Segmento', ficha.fichaCampo!.segmentoResultante!),
              if (ficha.fichaCampo!.recomendacionAsesor != null)
                _InfoRow('Recomendación', ficha.fichaCampo!.recomendacionAsesor!),
            ],
          ),
        ],
        if (ficha.cuentas.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Cuentas',
            children: ficha.cuentas
                .map(
                  (cuenta) => _InfoRow(
                    '${cuenta.tipo} · ${cuenta.numeroCuenta}',
                    'S/ ${cuenta.saldo.toStringAsFixed(2)}',
                  ),
                )
                .toList(),
          ),
        ],
        if (ficha.solicitudes.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Solicitudes (${ficha.solicitudes.length})',
            children: ficha.solicitudes
                .take(5)
                .map((s) => _InfoRow(
                      'S/ ${s.monto.toStringAsFixed(0)} · ${s.plazoMeses}m',
                      s.estadoLabel,
                    ))
                .toList(),
          ),
        ],
        if (ficha.documentos.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Documentos (${ficha.documentos.length})',
            children: ficha.documentos
                .take(5)
                .map((d) => _InfoRow(d.tipoLabel, d.estado))
                .toList(),
          ),
        ],
      ],
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _CreditosTab extends StatelessWidget {
  const _CreditosTab({required this.ficha});

  final ClientFicha ficha;

  @override
  Widget build(BuildContext context) {
    if (ficha.historial.isEmpty) {
      return const Center(child: Text('Sin créditos registrados.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: ficha.historial.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = ficha.historial[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.segmento,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (c.diasMora > 0)
                      Chip(
                        label: Text('Mora ${c.diasMora}d'),
                        backgroundColor: const Color(0xFFFFECEB),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _InfoRow('Producto', c.producto),
                _InfoRow('Desembolsado', 'S/ ${c.montoAprobado.toStringAsFixed(2)}'),
                _InfoRow(
                  'Saldo pendiente',
                  'S/ ${(c.saldoPendiente ?? c.montoAprobado).toStringAsFixed(2)}',
                ),
                _InfoRow('Cuotas pagadas', '${c.cuotasPagadas}/${c.plazoMeses}'),
                _InfoRow('Cuota', 'S/ ${c.cuotaMensual.toStringAsFixed(2)}'),
                _InfoRow('Plazo', '${c.plazoMeses} meses'),
                if (c.tea != null)
                  _InfoRow('TEA', '${c.tea!.toStringAsFixed(0)}%'),
                _InfoRow('Estado', c.estado),
                if (c.estadoPago != null) _InfoRow('Pago', c.estadoPago!),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BuroTab extends StatelessWidget {
  const _BuroTab({required this.ficha, required this.sbsColor});

  final ClientFicha ficha;
  final Color Function(String?) sbsColor;

  @override
  Widget build(BuildContext context) {
    final c = ficha.cliente;
    final b = ficha.buro;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _SectionCard(
          title: 'Central de Riesgos (SBS)',
          children: [
            _InfoRow(
              'Calificación',
              c.calificacionSbs ?? b?.calificacionSbs ?? 'Normal',
              valueColor: sbsColor(c.calificacionSbs ?? b?.calificacionSbs),
            ),
            _InfoRow(
              'Entidades',
              '${c.entidadesSbs ?? b?.entidadesSbs ?? 0}',
            ),
            _InfoRow(
              'Deuda total',
              'S/ ${(c.deudaTotalSbs ?? b?.deudaTotalSbs ?? 0).toStringAsFixed(2)}',
            ),
          ],
        ),
        if (b != null) ...[
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Scoring SURGIR',
            children: [
              if (b.scoreTransaccional != null)
                _InfoRow('Score transaccional', '${b.scoreTransaccional}'),
              if (b.segmentoPreliminar != null)
                _InfoRow('Segmento preliminar', b.segmentoPreliminar!),
              if (b.montoHipotesis != null)
                _InfoRow(
                  'Monto hipótesis',
                  'S/ ${b.montoHipotesis!.toStringAsFixed(2)}',
                ),
              if (b.scoreCampo != null)
                _InfoRow('Score de campo', '${b.scoreCampo}'),
              if (b.scoreFinal != null)
                _InfoRow('Score final', '${b.scoreFinal}'),
              if (b.segmentoResultante != null)
                _InfoRow('Segmento final', b.segmentoResultante!),
              if (b.recomendacionAsesor != null)
                _InfoRow('Recomendación', b.recomendacionAsesor!),
              if (b.estadoFicha != null)
                _InfoRow('Estado ficha', b.estadoFicha!),
            ],
          ),
        ],
      ],
    );
  }
}

class _MovimientosTab extends StatelessWidget {
  const _MovimientosTab({required this.ficha});

  final ClientFicha ficha;

  @override
  Widget build(BuildContext context) {
    if (ficha.transacciones.isEmpty) {
      return const Center(child: Text('Sin movimientos recientes.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: ficha.transacciones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final t = ficha.transacciones[i];
        final isCredit = t.tipo == 'credito';
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isCredit
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              child: Icon(
                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
                size: 18,
              ),
            ),
            title: Text(
              t.descripcion,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: t.fecha != null
                ? Text(_fmtDate(t.fecha!))
                : null,
            trailing: Text(
              '${isCredit ? '+' : '-'}S/ ${t.monto.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ),
        );
      },
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.highlight = false,
  });

  final String title;
  final List<Widget> children;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlight ? const Color(0xFFF6FBF7) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingSolicitudBanner extends StatelessWidget {
  const _PendingSolicitudBanner({
    required this.solicitud,
    required this.estado,
    this.expediente,
    this.onEvaluar,
  });

  final CreditApplication solicitud;
  final String estado;
  final String? expediente;
  final VoidCallback? onEvaluar;

  @override
  Widget build(BuildContext context) {
    final isComite = estado == 'en_comite';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isComite
            ? const Color(0xFFE3F2FD)
            : const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComite
              ? Colors.blue.shade200
              : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComite
                    ? Icons.groups_outlined
                    : Icons.campaign_outlined,
                color: isComite
                    ? Colors.blue.shade800
                    : Colors.orange.shade800,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isComite
                      ? 'EN COMITÉ DE CRÉDITO'
                      : 'SOLICITUD PENDIENTE DE EVALUACIÓN',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isComite
                        ? Colors.blue.shade900
                        : Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (expediente != null) Text('Expediente: $expediente'),
          Text(
            'S/ ${solicitud.monto.toStringAsFixed(2)} · ${solicitud.plazoMeses} meses · Estado: $estado',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            isComite
                ? 'El comité revisará esta solicitud. No requiere transmisión.'
                : 'Al aprobar, el monto se abona a la cuenta del cliente y aparece en Mis créditos.',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (onEvaluar != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onEvaluar,
                icon: const Icon(Icons.gavel_outlined, size: 18),
                label: const Text('Evaluar solicitud'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
