enum EstadoLicenca { activa, aExpirar, expirada, suspensa }

/// Nível comercial da licença. **Não confundir com `plano`**, que é a *duração*
/// e entra na base da assinatura HMAC do `licenca.json` do POS.
enum Tier {
  base,
  pro,

  /// Licença anterior ao modelo Base/Pro. Comporta-se como [pro] — não se
  /// retiram funcionalidades a quem já as tinha.
  legado,
}

extension TierInfo on Tier {
  static Tier parse(String? valor) => switch (valor?.trim().toLowerCase()) {
        'base' => Tier.base,
        'pro' => Tier.pro,
        _ => Tier.legado,
      };

  String get rotulo => switch (this) {
        Tier.base => 'Base',
        Tier.pro => 'Pro',
        Tier.legado => 'Legado',
      };

  /// Tem direito às funcionalidades extra?
  bool get temExtras => this != Tier.base;
}

class Licenca {
  final String id;
  final String? clienteId;
  final String machineId;
  final String nif;
  /// Designação social (nome legal). Vem do POS via `sincronizar-empresa`.
  final String? nome;

  /// Nome comercial — como a loja é conhecida. `null` enquanto o POS não
  /// sincronizar. É este que se mostra em destaque: é por ele que o Cesar
  /// reconhece o cliente, não pela denominação legal.
  final String? nomeComercial;

  final String plano; // trimestral | semestral | anual | personalizado
  final DateTime validade;
  final bool activa;

  /// `true` quando a licença é uma oferta (gratuita); `false` = licença paga.
  final bool oferta;

  /// Série documental do terminal (ex.: FT-T1), definida quando a licença é
  /// gerada (após pagamento). `null` enquanto é só um pedido/convite.
  final String? serie;

  final DateTime criadoEm;

  /// Nível comercial (`licencas.tier`). Só a Edge Function `gerir-licenca` o
  /// escreve — por isso está fora de [toUpdateJson].
  final Tier tier;

  /// Preferências de features do admin do POS (`licencas.preferencias_features`).
  /// **Read-only no Control**: quem as altera é o admin no POS. Chave ausente =
  /// ligada por omissão.
  final Map<String, bool> preferenciasFeatures;

  const Licenca({
    required this.id,
    this.clienteId,
    required this.machineId,
    required this.nif,
    this.nome,
    this.nomeComercial,
    required this.plano,
    required this.validade,
    required this.activa,
    this.oferta = false,
    this.serie,
    required this.criadoEm,
    this.tier = Tier.legado,
    this.preferenciasFeatures = const {},
  });

  /// A feature está visível neste terminal? Mesma regra do `featureVisivel` do
  /// POS: o tier dá o direito, a preferência só desliga. Um terminal Base com
  /// a preferência a `true` continua sem a funcionalidade.
  bool featureVisivel(String chave) {
    if (!tier.temExtras) return false;
    return preferenciasFeatures[chave] ?? true;
  }

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
        nomeComercial: json['nome_comercial'] as String?,
        plano: json['plano'] as String,
        validade: DateTime.parse(json['validade'] as String),
        activa: json['activa'] as bool? ?? true,
        oferta: json['oferta'] as bool? ?? false,
        serie: json['serie'] as String?,
        criadoEm: DateTime.parse(json['created_at'] as String),
        tier: TierInfo.parse(json['tier'] as String?),
        preferenciasFeatures: _prefsFromJson(json['preferencias_features']),
      );

  /// JSONB → mapa de bools, ignorando chaves com tipos inesperados.
  static Map<String, bool> _prefsFromJson(Object? valor) {
    if (valor is! Map) return const {};
    return {
      for (final e in valor.entries)
        if (e.key is String && e.value is bool) e.key as String: e.value as bool,
    };
  }

  /// Serialização completa (inclui `id` e `created_at`). Mantida para
  /// desserialização/round-trip em testes. **Não usar em INSERT/UPDATE** — usar
  /// [toInsertJson] / [toUpdateJson], que excluem os campos geridos pela BD.
  Map<String, dynamic> toJson() => {
        'id': id,
        'cliente_id': clienteId,
        'machine_id': machineId,
        'nif': nif,
        'nome': nome,
        'nome_comercial': nomeComercial,
        'plano': plano,
        'validade': validade.toIso8601String(),
        'activa': activa,
        'oferta': oferta,
        'serie': serie,
        'created_at': criadoEm.toIso8601String(),
        'tier': tier == Tier.legado ? null : tier.name,
        'preferencias_features': preferenciasFeatures,
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
        'nome_comercial': nomeComercial,
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
  ///
  /// **`tier` e `preferencias_features` também estão excluídos de propósito**:
  /// `tier` só se muda pela Edge Function `gerir-licenca` (para haver auditoria
  /// de quem promoveu quem), e as preferências pertencem ao admin do POS — o
  /// Control só as lê.
  Map<String, dynamic> toUpdateJson() => {
        'cliente_id': clienteId,
        'nif': nif,
        'nome': nome,
        'nome_comercial': nomeComercial,
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
    String? nomeComercial,
    String? plano,
    DateTime? validade,
    bool? activa,
    bool? oferta,
    String? serie,
    DateTime? criadoEm,
    Tier? tier,
    Map<String, bool>? preferenciasFeatures,
  }) =>
      Licenca(
        id: id ?? this.id,
        clienteId: clienteId ?? this.clienteId,
        machineId: machineId ?? this.machineId,
        nif: nif ?? this.nif,
        nome: nome ?? this.nome,
        nomeComercial: nomeComercial ?? this.nomeComercial,
        plano: plano ?? this.plano,
        validade: validade ?? this.validade,
        activa: activa ?? this.activa,
        oferta: oferta ?? this.oferta,
        serie: serie ?? this.serie,
        criadoEm: criadoEm ?? this.criadoEm,
        tier: tier ?? this.tier,
        preferenciasFeatures:
            preferenciasFeatures ?? this.preferenciasFeatures,
      );
}
