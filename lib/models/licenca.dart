enum EstadoLicenca { activa, aExpirar, expirada, suspensa }

class Licenca {
  final String id;
  final String? clienteId;
  final String machineId;
  final String nif;
  final String? nome;
  final String plano; // mensal | trimestral | anual
  final DateTime validade;
  final bool activa;
  final DateTime criadoEm;

  const Licenca({
    required this.id,
    this.clienteId,
    required this.machineId,
    required this.nif,
    this.nome,
    required this.plano,
    required this.validade,
    required this.activa,
    required this.criadoEm,
  });

  bool get expirada => DateTime.now().isAfter(validade);

  bool get aExpirar =>
      !expirada && validade.difference(DateTime.now()).inDays <= 15;

  EstadoLicenca get estado {
    if (!activa) return EstadoLicenca.suspensa;
    if (expirada) return EstadoLicenca.expirada;
    if (aExpirar) return EstadoLicenca.aExpirar;
    return EstadoLicenca.activa;
  }

  factory Licenca.fromJson(Map<String, dynamic> json) => Licenca(
        id: json['id'] as String,
        clienteId: json['cliente_id'] as String?,
        machineId: json['machine_id'] as String,
        nif: json['nif'] as String,
        nome: json['nome'] as String?,
        plano: json['plano'] as String,
        validade: DateTime.parse(json['validade'] as String),
        activa: json['activa'] as bool? ?? true,
        criadoEm: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cliente_id': clienteId,
        'machine_id': machineId,
        'nif': nif,
        'nome': nome,
        'plano': plano,
        'validade': validade.toIso8601String(),
        'activa': activa,
        'created_at': criadoEm.toIso8601String(),
      };

  Licenca copyWith({
    String? id,
    String? clienteId,
    String? machineId,
    String? nif,
    String? nome,
    String? plano,
    DateTime? validade,
    bool? activa,
    DateTime? criadoEm,
  }) =>
      Licenca(
        id: id ?? this.id,
        clienteId: clienteId ?? this.clienteId,
        machineId: machineId ?? this.machineId,
        nif: nif ?? this.nif,
        nome: nome ?? this.nome,
        plano: plano ?? this.plano,
        validade: validade ?? this.validade,
        activa: activa ?? this.activa,
        criadoEm: criadoEm ?? this.criadoEm,
      );
}
