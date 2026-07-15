class Ping {
  final String id;
  final String machineId;
  final String? nif;
  final String? versao;
  final double? lat;
  final double? lon;
  /// Cidade inferida por geolocalização (automática).
  final String? cidade;
  final String? metodoGeo;

  /// Nome comercial da empresa, tal como o cliente o escreveu no POS. Só é
  /// preenchido depois do Track B (POS a enviá-lo no ping) — até lá, `null`,
  /// e as colunas nem existem no Supabase.
  final String? nome;

  /// Localidade escrita pelo cliente no POS — pode divergir de [cidade], que é
  /// automática. `null` pelo mesmo motivo que [nome].
  final String? localidadeCliente;

  final DateTime criadoEm;

  const Ping({
    required this.id,
    required this.machineId,
    this.nif,
    this.versao,
    this.lat,
    this.lon,
    this.cidade,
    this.metodoGeo,
    this.nome,
    this.localidadeCliente,
    required this.criadoEm,
  });

  factory Ping.fromJson(Map<String, dynamic> json) => Ping(
        id: json['id'] as String,
        machineId: json['machine_id'] as String,
        nif: json['nif'] as String?,
        versao: json['versao'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lon: (json['lon'] as num?)?.toDouble(),
        cidade: json['cidade'] as String?,
        metodoGeo: json['metodo_geo'] as String?,
        nome: json['nome'] as String?,
        localidadeCliente: json['localidade_cliente'] as String?,
        criadoEm: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'machine_id': machineId,
        'nif': nif,
        'versao': versao,
        'lat': lat,
        'lon': lon,
        'cidade': cidade,
        'metodo_geo': metodoGeo,
        'nome': nome,
        'localidade_cliente': localidadeCliente,
        'created_at': criadoEm.toIso8601String(),
      };
}
