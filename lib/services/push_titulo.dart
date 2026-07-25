import '../core/apps_ui.dart';

/// Prefixa o título de um push com a app de origem: `[POS] Novo terminal`.
///
/// [app] vem de `message.data['app']`, escrito pela Edge Function `enviar-push`.
/// Retro-compatível: pushes antigos (sem o campo) mantêm o título tal como
/// veio — nada de `[]` vazios nem `[NULL]`.
///
/// **Só afecta o foreground.** Com a app em background ou fechada, quem desenha
/// a notificação é o sistema operativo a partir do payload `notification`, e o
/// Dart não lhe toca. Para o prefixo aparecer aí, tem de vir já no título que a
/// Edge Function envia — ver `docs/design/multi_app.md`.
String tituloComApp(String titulo, String? app) {
  final a = app?.trim();
  if (a == null || a.isEmpty) return titulo;
  return '[${AppsUi.sigla(a)}] $titulo';
}
