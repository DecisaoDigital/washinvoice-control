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

  /// IP público do terminal no momento do ping (fornecedor de internet). Para
  /// suporte e detecção de utilizações irregulares. `null` se a obtenção falhou
  /// ou se o ping é anterior a esta funcionalidade.
  final String? ipPublico;

  /// Fotografia do estado da licença no momento do ping (`activa`, `bloqueada`…).
  final String? estadoLicenca;

  /// Fotografia: os termos estavam aceites neste terminal?
  final bool? termosAceites;

  /// O que despoletou o ping (`arranque`, `aceite_termos`, `timer_6h`, `manual`).
  final String? origem;

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
    this.ipPublico,
    this.estadoLicenca,
    this.termosAceites,
    this.origem,
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
        ipPublico: json['ip_publico'] as String?,
        estadoLicenca: json['estado_licenca'] as String?,
        termosAceites: json['termos_aceites'] as bool?,
        origem: json['origem'] as String?,
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
        'ip_publico': ipPublico,
        'estado_licenca': estadoLicenca,
        'termos_aceites': termosAceites,
        'origem': origem,
        'created_at': criadoEm.toIso8601String(),
      };
}
