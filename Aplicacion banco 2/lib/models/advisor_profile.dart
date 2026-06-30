class AdvisorProfile {
  const AdvisorProfile({
    required this.codigo,
    required this.nombres,
    required this.apellidos,
    required this.nivel,
    this.zonaAsignada,
    this.totalClientes = 0,
    this.clientesEnMora = 0,
  });

  final String codigo;
  final String nombres;
  final String apellidos;
  final String nivel;
  final String? zonaAsignada;
  final int totalClientes;
  final int clientesEnMora;

  String get nombreCompleto => '$nombres $apellidos';

  factory AdvisorProfile.fromResumen(Map<String, dynamic> json) {
    return AdvisorProfile(
      codigo: json['codigo'] as String? ?? '',
      nombres: json['nombres'] as String? ?? '',
      apellidos: json['apellidos'] as String? ?? '',
      nivel: json['nivel'] as String? ?? '',
      zonaAsignada: json['zona_asignada'] as String?,
      totalClientes: json['total_clientes'] as int? ?? 0,
      clientesEnMora: json['clientes_en_mora'] as int? ?? 0,
    );
  }
}
