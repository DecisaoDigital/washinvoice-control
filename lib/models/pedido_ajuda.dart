class PedidoAjuda {
  final String id;

  /// App de onde o pedido veio (`pedidos_ajuda.app`). É o que diz ao Cesar em
  /// que app ir ajudar antes sequer de abrir o detalhe.
  final String app;

  final String machineId;
  final String? nif;
  final String? clienteId;
  final DateTime criadoEm;
  final DateTime? resolvidoEm;
  final String? notas;

  const PedidoAjuda({
    required this.id,
    this.app = 'pos',
    required this.machineId,
    this.nif,
    this.clienteId,
    required this.criadoEm,
    this.resolvidoEm,
    this.notas,
  });

  bool get resolvido => resolvidoEm != null;

  /// Tempo entre criação e resolução (null se ainda aberto).
  Duration? get duracao => resolvidoEm?.difference(criadoEm);

  factory PedidoAjuda.fromJson(Map<String, dynamic> json) => PedidoAjuda(
        id: json['id'] as String,
        app: json['app'] as String? ?? 'pos',
        machineId: json['machine_id'] as String,
        nif: json['nif'] as String?,
        clienteId: json['cliente_id'] as String?,
        criadoEm: DateTime.parse(json['criado_em'] as String),
        resolvidoEm: json['resolvido_em'] == null
            ? null
            : DateTime.parse(json['resolvido_em'] as String),
        notas: json['notas'] as String?,
      );

  /// O mesmo pedido, outra vez em aberto (`resolvidoEm` a nulo — o
  /// [copyWith] não consegue pôr a nulo).
  PedidoAjuda reaberto() => PedidoAjuda(
    id: id,
    app: app,
    machineId: machineId,
    nif: nif,
    clienteId: clienteId,
    criadoEm: criadoEm,
    resolvidoEm: null,
    notas: notas,
  );

  PedidoAjuda copyWith({DateTime? resolvidoEm, String? notas}) => PedidoAjuda(
        id: id,
        app: app,
        machineId: machineId,
        nif: nif,
        clienteId: clienteId,
        criadoEm: criadoEm,
        resolvidoEm: resolvidoEm ?? this.resolvidoEm,
        notas: notas ?? this.notas,
      );
}
