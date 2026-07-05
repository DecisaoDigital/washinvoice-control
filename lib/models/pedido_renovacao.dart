class PedidoRenovacao {
  final String id;
  final String machineId;
  final String nif;
  final String planoDesejado;
  final String estado; // pendente | confirmado
  final DateTime criadoEm;
  final DateTime? confirmadoAt;

  const PedidoRenovacao({
    required this.id,
    required this.machineId,
    required this.nif,
    required this.planoDesejado,
    required this.estado,
    required this.criadoEm,
    this.confirmadoAt,
  });

  factory PedidoRenovacao.fromJson(Map<String, dynamic> json) =>
      PedidoRenovacao(
        id: json['id'] as String,
        machineId: json['machine_id'] as String,
        nif: json['nif'] as String,
        planoDesejado: json['plano_desejado'] as String,
        estado: json['estado'] as String? ?? 'pendente',
        criadoEm: DateTime.parse(json['created_at'] as String),
        confirmadoAt: json['confirmado_at'] != null
            ? DateTime.parse(json['confirmado_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'machine_id': machineId,
        'nif': nif,
        'plano_desejado': planoDesejado,
        'estado': estado,
        'created_at': criadoEm.toIso8601String(),
        'confirmado_at': confirmadoAt?.toIso8601String(),
      };
}
