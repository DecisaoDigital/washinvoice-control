/// Uma série de facturação comunicada (ou tentada comunicar) à AT via
/// webservice, tal como fica registada em `series_comunicadas`.
///
/// Escrita só pela Edge Function `comunicar-serie` (service_role); o Control
/// apenas lê (authenticated + is_admin). Cada linha é o retrato de **uma
/// tentativa** de comunicação: quando corre bem traz o [codigoValidacao]
/// (ATCUD-CV); quando falha traz o [erro] bruto da AT.
class SerieComunicada {
  final String id;
  final String licencaId;
  final String machineId;

  /// Identificador da série (ex.: `FTA2026`).
  final String serie;

  /// Tipo de documento (`FT`, `FR`, `FS`, `NC`, `ND`).
  final String tipoDoc;

  final int numeroInicial;
  final DateTime dataInicio;

  /// ATCUD-CV atribuído pela AT (ex.: `J6SHZMK5`). `null` quando a comunicação
  /// falhou.
  final String? codigoValidacao;

  /// Mensagem de erro bruta da AT, quando [codigoValidacao] é `null`.
  final String? erro;

  /// `testes` ou `producao`.
  final String ambiente;

  /// Quem despoletou a comunicação (email do admin, ou `teste`).
  final String? feitoPor;

  final DateTime criadoEm;

  const SerieComunicada({
    required this.id,
    required this.licencaId,
    required this.machineId,
    required this.serie,
    required this.tipoDoc,
    required this.numeroInicial,
    required this.dataInicio,
    this.codigoValidacao,
    this.erro,
    required this.ambiente,
    this.feitoPor,
    required this.criadoEm,
  });

  /// Comunicada com sucesso à AT? (tem código de validação atribuído).
  bool get comunicada =>
      codigoValidacao != null && codigoValidacao!.trim().isNotEmpty;

  factory SerieComunicada.fromJson(Map<String, dynamic> json) {
    String? limpar(Object? v) {
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    return SerieComunicada(
      id: json['id'] as String,
      licencaId: json['licenca_id'] as String,
      machineId: json['machine_id'] as String,
      serie: json['serie'] as String,
      tipoDoc: json['tipo_doc'] as String,
      numeroInicial: (json['numero_inicial'] as num?)?.toInt() ?? 1,
      dataInicio: DateTime.parse(json['data_inicio'] as String),
      codigoValidacao: limpar(json['codigo_validacao']),
      erro: limpar(json['erro']),
      ambiente: json['ambiente'] as String? ?? 'testes',
      feitoPor: limpar(json['feito_por']),
      criadoEm: DateTime.parse(json['created_at'] as String),
    );
  }
}
