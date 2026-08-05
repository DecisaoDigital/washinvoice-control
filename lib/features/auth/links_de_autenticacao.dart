import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// **O link do email, tratado à mão — porque o automático não chega cá.**
///
/// O `supabase_flutter` traz um observador de deep links próprio
/// (`detectSessionInUri`, ligado por omissão): subscreve o `app_links` e chama
/// o `getSessionFromUrl` sozinho. No Punho funciona. No Control, não.
///
/// A 5 de Agosto de 2026, no Redmi, com o percurso todo feito à mão: o pedido
/// saiu com o esquema certo (`/recover` com `referer:
/// washinvoicecontrol://auth/callback`, 200), o email chegou em segundos, o
/// link abriu o Control e não o POS, e o plugin registou no logcat
/// `Handled intent: washinvoicecontrol://auth/callback?code=36e1f2f0-…`.
/// A partir daí, nada: nem sessão, nem erro, nem mensagem. No servidor, a linha
/// do `auth.flow_state` ficou por consumir e o `last_sign_in_at` não mexeu —
/// prova de que o pedido de troca nunca chegou a sair do telemóvel.
///
/// Que o problema é a **entrega** e não a troca provou-se com um link só de
/// erro (`?error=access_denied&error_description=…`), que rebenta dentro do
/// `getSessionFromUrl` sem tocar em rede nem em armazenamento: o Punho
/// respondeu com mensagem, o Control ficou mudo. A frio e a quente.
///
/// Por isso aqui não se confia no observador de origem — fica desligado no
/// `main`, e é este objecto que escuta. Ganha-se de caminho o que faltava: uma
/// falha passa a ter mensagem, em vez de se perder num log que ninguém lê.
/// Ver [ehCallbackDeAutenticacao].
class LinksDeAutenticacao {
  LinksDeAutenticacao({
    required Stream<Uri> links,
    required void Function(Object erro) aoFalhar,
    Future<Uri?> Function()? linkInicial,
    Future<void> Function(Uri uri)? trocar,
  }) : _links = links,
       _aoFalhar = aoFalhar,
       _linkInicial = linkInicial,
       _trocar = trocar ?? _trocarNoSupabase;

  final Stream<Uri> _links;
  final void Function(Object erro) _aoFalhar;
  final Future<Uri?> Function()? _linkInicial;
  final Future<void> Function(Uri uri) _trocar;

  StreamSubscription<Uri>? _subscricao;

  /// Os links já trocados, para não os trocar duas vezes.
  ///
  /// O arranque a frio é o caso: o `app_links` entrega o link inicial pelo
  /// stream *e* por [linkInicial], e a segunda troca do mesmo código falha
  /// sempre — o código é de uso único. Sem isto, quem recuperasse a
  /// palavra-passe com a app fechada via a mensagem de erro por cima do ecrã
  /// que acabara de abrir bem.
  final _jaTratados = <String>{};

  /// Começa a escutar. O link inicial é lido **depois** de a subscrição estar
  /// de pé, para não haver janela em que um link chegue sem ninguém à escuta.
  Future<void> escutar() async {
    _subscricao = _links.listen(_tratar, onError: _aoFalhar);
    final inicial = await _linkInicial?.call();
    if (inicial != null) await _tratar(inicial);
  }

  Future<void> parar() async {
    await _subscricao?.cancel();
    _subscricao = null;
  }

  Future<void> _tratar(Uri uri) async {
    // Fica rasto de cada link recebido. Foi só com ele que se percebeu, a 5
    // de Agosto de 2026, que o observador de origem não entregava nada — do
    // lado de fora as duas avarias são iguais: a app abre e não acontece nada.
    debugPrint('[links] chegou: $uri');
    if (!ehCallbackDeAutenticacao(uri)) return;
    if (!_jaTratados.add(uri.toString())) return;
    try {
      await _trocar(uri);
    } catch (erro) {
      _aoFalhar(erro);
    }
  }

  static Future<void> _trocarNoSupabase(Uri uri) async {
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
  }
}

/// Um link só nos diz respeito se trouxer o resultado de uma autenticação.
///
/// A app pode receber deep links por outras razões; entregar todos ao
/// `getSessionFromUrl` era pedir erros a quem não fez nada de errado. Os
/// parâmetros são procurados na query **e** no fragmento porque o fluxo
/// implícito devolve-os depois do `#` — hoje o Control só usa PKCE (`code`),
/// mas um link antigo, guardado num email de Janeiro, ainda pode chegar assim.
bool ehCallbackDeAutenticacao(Uri uri) {
  final doFragmento = Uri.splitQueryString(uri.fragment);
  bool tem(String chave) =>
      uri.queryParameters.containsKey(chave) || doFragmento.containsKey(chave);
  return tem('code') ||
      tem('access_token') ||
      tem('error') ||
      tem('error_code') ||
      tem('error_description');
}
