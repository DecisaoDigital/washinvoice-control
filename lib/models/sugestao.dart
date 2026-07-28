class Sugestao {
  final String id;

  /// App de onde a sugestão veio (`sugestoes.app`).
  final String app;

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
    this.app = 'pos',
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
        app: json['app'] as String? ?? 'pos',
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
        app: app,
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
