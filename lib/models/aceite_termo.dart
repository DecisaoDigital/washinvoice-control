class AceiteTermo {
  final String id;

  /// App em que os termos foram aceites (`aceites_termos.app`).
  final String app;

  final String machineId;
  final String? nif;
  final String? versaoTermos;
  final DateTime? dataAceite;
  final String? cidade;
  final String? ip;
  final DateTime criadoEm;

  const AceiteTermo({
    required this.id,
    this.app = 'pos',
    required this.machineId,
    this.nif,
    this.versaoTermos,
    this.dataAceite,
    this.cidade,
    this.ip,
    required this.criadoEm,
  });

  factory AceiteTermo.fromJson(Map<String, dynamic> json) => AceiteTermo(
        id: json['id'] as String,
        app: json['app'] as String? ?? 'pos',
        machineId: json['machine_id'] as String,
        nif: json['nif'] as String?,
        versaoTermos: json['versao_termos'] as String?,
        dataAceite: json['data_aceite'] != null
            ? DateTime.parse(json['data_aceite'] as String)
            : null,
        cidade: json['cidade'] as String?,
        ip: json['ip'] as String?,
        criadoEm: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'app': app,
        'machine_id': machineId,
        'nif': nif,
        'versao_termos': versaoTermos,
        'data_aceite': dataAceite?.toIso8601String(),
        'cidade': cidade,
        'ip': ip,
        'created_at': criadoEm.toIso8601String(),
      };
}
