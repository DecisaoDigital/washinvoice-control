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

  /// Impressão digital do APK publicado.
  ///
  /// Sem ela a app não instala automaticamente — só oferece o caminho antigo,
  /// pelo browser. O `urlDownload` vem de uma coluna editável em
  /// `versoes_apps`, e uma app que se instala a si própria tem de confirmar o
  /// que está a abrir.
  final String? sha256;

  const ActualizacaoInfo({
    required this.versaoActual,
    required this.buildNumber,
    required this.urlDownload,
    required this.obrigatoria,
    this.notasLancamento,
    this.sha256,
  });

  factory ActualizacaoInfo.fromJson(Map<String, dynamic> json) =>
      ActualizacaoInfo(
        versaoActual: json['versao_actual'] as String,
        buildNumber: json['build_number'] as int,
        urlDownload: json['url_download'] as String,
        obrigatoria: json['obrigatoria'] as bool? ?? false,
        notasLancamento: json['notas_lancamento'] as String?,
        sha256: json['sha256'] as String?,
      );
}
