import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:washinvoice_control/features/auth/modo_de_recuperacao.dart';

/// O trinco que impede o link do email de dar entrada silenciosa no Control.
///
/// Em duas linhas: abrir o link de recuperacao *autentica*, e sem este trinco a
/// pessoa entrava sem lhe ser pedida palavra-passe nenhuma — a antiga
/// continuava a valer, ela julgava te-la mudado, e no dia seguinte nao entrava.
void main() {
  test('o link de recuperacao fecha o trinco', () {
    expect(
      modoDeRecuperacao(AuthChangeEvent.passwordRecovery, actual: false),
      isTrue,
    );
  });

  test('um token renovado nao o abre', () {
    // E este que faz a diferenca toda: os `tokenRefreshed` passam sozinhos, de
    // hora a hora. Ler so o evento do momento dava entrada a quem estivesse
    // parado no ecra da palavra-passe nova quando um deles passasse.
    expect(
      modoDeRecuperacao(AuthChangeEvent.tokenRefreshed, actual: true),
      isTrue,
    );
    expect(modoDeRecuperacao(AuthChangeEvent.signedIn, actual: true), isTrue);
    expect(modoDeRecuperacao(null, actual: true), isTrue);
  });

  test('a palavra-passe mudada abre-o', () {
    expect(
      modoDeRecuperacao(AuthChangeEvent.userUpdated, actual: true),
      isFalse,
    );
  });

  test('desistir tambem — a sessao fecha-se e nao fica nada encostado', () {
    expect(modoDeRecuperacao(AuthChangeEvent.signedOut, actual: true), isFalse);
  });

  test('quem nao veio por link nenhum nao e incomodado', () {
    for (final evento in AuthChangeEvent.values) {
      if (evento == AuthChangeEvent.passwordRecovery) continue;
      expect(
        modoDeRecuperacao(evento, actual: false),
        isFalse,
        reason: '$evento nao pode acender o modo de recuperacao sozinho',
      );
    }
  });
}
