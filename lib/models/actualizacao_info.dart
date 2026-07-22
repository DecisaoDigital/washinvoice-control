/// Descreve a versão disponível quando o servidor diz que há actualização.
///
/// Devolvida pela Edge Function `versao-mais-recente` (campo
/// `actualizacao_disponivel: true`). Quando não há actualização, o serviço
/// devolve `null` em vez de uma instância desta classe.
class ActualizacaoInfo {
  final String versaoActual;
  final int buildNumber;
  final String urlDownload;
  final bool obrigatoria;
  final String? notasLancamento;

  const ActualizacaoInfo({
    required this.versaoActual,
    required this.buildNumber,
    required this.urlDownload,
    required this.obrigatoria,
    this.notasLancamento,
  });

  factory ActualizacaoInfo.fromJson(Map<String, dynamic> json) =>
      ActualizacaoInfo(
        versaoActual: json['versao_actual'] as String,
        buildNumber: json['build_number'] as int,
        urlDownload: json['url_download'] as String,
        obrigatoria: json['obrigatoria'] as bool? ?? false,
        notasLancamento: json['notas_lancamento'] as String?,
      );
}
