import 'package:url_launcher/url_launcher.dart';

/// Acções externas partilhadas (telefone, email). Fonte única para não repetir
/// a construção de URIs `tel:`/`mailto:` em cada ecrã.
class Acoes {
  Acoes._();

  /// Abre a app de telefone com [telefone]. Remove espaços e caracteres de
  /// formatação. Devolve `false` se não houver número ou a app não abrir.
  static Future<bool> ligarPara(String? telefone) async {
    if (telefone == null || telefone.trim().isEmpty) return false;
    final limpo = telefone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (limpo.isEmpty) return false;
    return launchUrl(
      Uri(scheme: 'tel', path: limpo),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Abre a app de email para [email], com assunto opcional.
  static Future<bool> enviarEmail(String? email, {String? assunto}) async {
    if (email == null || email.trim().isEmpty) return false;
    return launchUrl(
      Uri(
        scheme: 'mailto',
        path: email.trim(),
        query: assunto == null ? null : 'subject=${Uri.encodeComponent(assunto)}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }
}
