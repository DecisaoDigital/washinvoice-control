class Cliente {
  final String id; // uuid
  final String nif;
  final String nome;
  final String? email;
  final String? telemovel;
  final String? notas;
  final DateTime criadoEm;

  const Cliente({
    required this.id,
    required this.nif,
    required this.nome,
    this.email,
    this.telemovel,
    this.notas,
    required this.criadoEm,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        id: json['id'] as String,
        nif: json['nif'] as String,
        nome: json['nome'] as String,
        email: json['email'] as String?,
        telemovel: json['telemovel'] as String?,
        notas: json['notas'] as String?,
        criadoEm: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nif': nif,
        'nome': nome,
        'email': email,
        'telemovel': telemovel,
        'notas': notas,
        'created_at': criadoEm.toIso8601String(),
      };

  Cliente copyWith({
    String? id,
    String? nif,
    String? nome,
    String? email,
    String? telemovel,
    String? notas,
    DateTime? criadoEm,
  }) =>
      Cliente(
        id: id ?? this.id,
        nif: nif ?? this.nif,
        nome: nome ?? this.nome,
        email: email ?? this.email,
        telemovel: telemovel ?? this.telemovel,
        notas: notas ?? this.notas,
        criadoEm: criadoEm ?? this.criadoEm,
      );
}
