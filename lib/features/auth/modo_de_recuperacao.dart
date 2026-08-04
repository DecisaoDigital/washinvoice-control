import 'package:supabase_flutter/supabase_flutter.dart';

/// Se a app tem de pedir uma palavra-passe nova, e ate quando.
///
/// **Isto e um trinco, nao um interruptor.** Abrir o link do email de
/// recuperacao *autentica*: o `supabase_flutter` chama `getSessionFromUrl` e a
/// partir dai ha sessao. Se o encaminhamento lesse so o evento do momento,
/// bastava um `tokenRefreshed` a passar — e eles passam sozinhos, de hora a
/// hora — para o Control se abrir com a palavra-passe antiga ainda valida e
/// ninguem ter escolhido nada. Um link de email a dar entrada silenciosa e pior
/// do que o problema que se foi corrigir.
///
/// Por isso so duas coisas o soltam: a palavra-passe mudou de facto
/// ([AuthChangeEvent.userUpdated]) ou a sessao fechou-se
/// ([AuthChangeEvent.signedOut]). Tudo o resto deixa-o como esta.
bool modoDeRecuperacao(AuthChangeEvent? evento, {required bool actual}) =>
    switch (evento) {
      AuthChangeEvent.passwordRecovery => true,
      AuthChangeEvent.userUpdated || AuthChangeEvent.signedOut => false,
      _ => actual,
    };
