enum EstadoLicenca { activa, aExpirar, expirada, suspensa }

class Licenca {
  final String id;
  final String? clienteId;
  final String machineId;
  final String nif;
  final String? nome;
  final String plano; // trimestral | semestral | anual | personalizado
  final DateTime validade;
  final bool activa;

  /// `true` quando a licença é uma oferta (gratuita); `false` = licença paga.
  final bool oferta;

  /// Série documental do terminal (ex.: FT-T1), definida quando a licença é
  /// gerada (após pagamento). `null` enquanto é só um pedido/convite.
  final String? serie;

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
    this.oferta = false,
    this.serie,
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

  /// Nome do plano para exibição em PT. Planos legados/desconhecidos (ex.:
  /// 'mensal') são capitalizados de forma segura.
  String get planoLabel {
    switch (plano) {
      case 'trimestral':
        return 'Trimestral';
      case 'semestral':
        return 'Semestral';
      case 'anual':
        return 'Anual';
      case 'personalizado':
        return 'Personalizado';
      default:
        return plano.isEmpty
            ? plano
            : plano[0].toUpperCase() + plano.substring(1);
    }
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
        oferta: json['oferta'] as bool? ?? false,
        serie: json['serie'] as String?,
        criadoEm: DateTime.parse(json['created_at'] as String),
      );

  /// Serialização completa (inclui `id` e `created_at`). Mantida para
  /// desserialização/round-trip em testes. **Não usar em INSERT/UPDATE** — usar
  /// [toInsertJson] / [toUpdateJson], que excluem os campos geridos pela BD.
  Map<String, dynamic> toJson() => {
        'id': id,
        'cliente_id': clienteId,
        'machine_id': machineId,
        'nif': nif,
        'nome': nome,
        'plano': plano,
        'validade': validade.toIso8601String(),
        'activa': activa,
        'oferta': oferta,
        'serie': serie,
        'created_at': criadoEm.toIso8601String(),
      };

  /// Campos para **INSERT**. Exclui `id` e `created_at` (gerados pela BD).
  /// Inclui `machine_id` (identidade do terminal, definida na criação).
  /// Nota: `user_id` (ligação ao POS para RLS) não vive no modelo — é definido
  /// à parte por `LicencasRepository.criar`.
  Map<String, dynamic> toInsertJson() => {
        'cliente_id': clienteId,
        'machine_id': machineId,
        'nif': nif,
        'nome': nome,
        'plano': plano,
        'validade': validade.toIso8601String(),
        'activa': activa,
        'oferta': oferta,
        'serie': serie,
      };

  /// Campos para **UPDATE**. Exclui `id`, `created_at` (geridos pela BD),
  /// `machine_id` (identidade imutável do terminal) e `user_id` (ligação
  /// imutável ao POS, definida só na criação). É isto que evita o erro de
  /// enviar `id`/`created_at` no UPDATE.
  Map<String, dynamic> toUpdateJson() => {
        'cliente_id': clienteId,
        'nif': nif,
        'nome': nome,
        'plano': plano,
        'validade': validade.toIso8601String(),
        'activa': activa,
        'oferta': oferta,
        'serie': serie,
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
    bool? oferta,
    String? serie,
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
        oferta: oferta ?? this.oferta,
        serie: serie ?? this.serie,
        criadoEm: criadoEm ?? this.criadoEm,
      );
}
