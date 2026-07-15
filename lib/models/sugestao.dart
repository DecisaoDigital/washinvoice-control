class Sugestao {
  final String id;
  final String? machineId;
  final String? nif;
  final String? clienteId;
  final String texto;
  final DateTime criadoEm;
  final bool lida;
  final bool marcada;
  final bool arquivada;

  const Sugestao({
    required this.id,
    this.machineId,
    this.nif,
    this.clienteId,
    required this.texto,
    required this.criadoEm,
    this.lida = false,
    this.marcada = false,
    this.arquivada = false,
  });

  factory Sugestao.fromJson(Map<String, dynamic> json) => Sugestao(
        id: json['id'] as String,
        machineId: json['machine_id'] as String?,
        nif: json['nif'] as String?,
        clienteId: json['cliente_id'] as String?,
        texto: json['texto'] as String,
        criadoEm: DateTime.parse(json['criado_em'] as String),
        lida: json['lida'] as bool? ?? false,
        marcada: json['marcada'] as bool? ?? false,
        arquivada: json['arquivada'] as bool? ?? false,
      );

  Sugestao copyWith({bool? lida, bool? marcada, bool? arquivada}) => Sugestao(
        id: id,
        machineId: machineId,
        nif: nif,
        clienteId: clienteId,
        texto: texto,
        criadoEm: criadoEm,
        lida: lida ?? this.lida,
        marcada: marcada ?? this.marcada,
        arquivada: arquivada ?? this.arquivada,
      );
}
