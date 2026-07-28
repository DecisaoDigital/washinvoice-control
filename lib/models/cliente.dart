class Cliente {
  final String id; // uuid
  final String nif;
  /// Designação social (nome legal). Vem do POS via `sincronizar-empresa`.
  final String nome;

  /// Nome comercial — como a loja é conhecida (ex.: "WashExpress"). Distinto
  /// de [nome], que é o legal. `null` enquanto o POS não sincronizar.
  final String? nomeComercial;

  final String? email;
  final String? telemovel;
  final String? notas;

  /// Localidade humana da loja, preenchida pelo admin (ex.: "Pinhal Novo").
  /// Distinta da `cidade` automática do ping. Coluna `clientes.localidade`.
  final String? localidade;

  final DateTime criadoEm;

  const Cliente({
    required this.id,
    required this.nif,
    required this.nome,
    this.nomeComercial,
    this.email,
    this.telemovel,
    this.notas,
    this.localidade,
    required this.criadoEm,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        id: json['id'] as String,
        nif: json['nif'] as String,
        nome: json['nome'] as String,
        nomeComercial: json['nome_comercial'] as String?,
        email: json['email'] as String?,
        telemovel: json['telemovel'] as String?,
        notas: json['notas'] as String?,
        localidade: json['localidade'] as String?,
        criadoEm: DateTime.parse(json['created_at'] as String),
      );

  /// Serialização completa (inclui `id` e `created_at`). Para round-trip/testes.
  /// **Não usar em INSERT/UPDATE** — usar [toInsertJson] / [toUpdateJson].
  Map<String, dynamic> toJson() => {
        'id': id,
        'nif': nif,
        'nome': nome,
        'nome_comercial': nomeComercial,
        'email': email,
        'telemovel': telemovel,
        'notas': notas,
        'localidade': localidade,
        'created_at': criadoEm.toIso8601String(),
      };

  /// Campos para **INSERT**. Exclui `id` e `created_at` (gerados pela BD).
  Map<String, dynamic> toInsertJson() => {
        'nif': nif,
        'nome': nome,
        'nome_comercial': nomeComercial,
        'email': email,
        'telemovel': telemovel,
        'notas': notas,
        'localidade': localidade,
      };

  /// Campos para **UPDATE**. Exclui `id` e `created_at` (geridos pela BD) —
  /// evita o erro de os enviar no UPDATE.
  Map<String, dynamic> toUpdateJson() => {
        'nif': nif,
        'nome': nome,
        'nome_comercial': nomeComercial,
        'email': email,
        'telemovel': telemovel,
        'notas': notas,
        'localidade': localidade,
      };

  Cliente copyWith({
    String? id,
    String? nif,
    String? nome,
    String? nomeComercial,
    String? email,
    String? telemovel,
    String? notas,
    String? localidade,
    DateTime? criadoEm,
  }) =>
      Cliente(
        id: id ?? this.id,
        nif: nif ?? this.nif,
        nome: nome ?? this.nome,
        nomeComercial: nomeComercial ?? this.nomeComercial,
        email: email ?? this.email,
        telemovel: telemovel ?? this.telemovel,
        notas: notas ?? this.notas,
        localidade: localidade ?? this.localidade,
        criadoEm: criadoEm ?? this.criadoEm,
      );
}
