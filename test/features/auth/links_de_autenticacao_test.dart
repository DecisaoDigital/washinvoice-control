import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:washinvoice_control/features/auth/links_de_autenticacao.dart';

/// A régua do que substituiu o observador do `supabase_flutter`.
///
/// O que falhou no telemóvel não foi a troca do código — foi ninguém a ouvir o
/// link. Estes testes olham para o lado de que isso depende: o que é
/// reconhecido, o que é entregue, e o que acontece quando corre mal.
void main() {
  group('ehCallbackDeAutenticacao', () {
    test('reconhece o código do fluxo PKCE, que é o que o Control usa', () {
      expect(
        ehCallbackDeAutenticacao(
          Uri.parse('washinvoicecontrol://auth/callback?code=36e1f2f0'),
        ),
        isTrue,
      );
    });

    test('reconhece um erro devolvido pelo Supabase', () {
      expect(
        ehCallbackDeAutenticacao(
          Uri.parse(
            'washinvoicecontrol://auth/callback'
            '?error=access_denied&error_description=expirou',
          ),
        ),
        isTrue,
      );
    });

    test('reconhece o fluxo antigo, que devolve tudo depois do cardinal', () {
      expect(
        ehCallbackDeAutenticacao(
          Uri.parse(
            'washinvoicecontrol://auth/callback#access_token=abc&type=recovery',
          ),
        ),
        isTrue,
      );
    });

    test('ignora um link que não traz resultado de autenticação nenhum', () {
      // Entregar isto ao `getSessionFromUrl` era arranjar um erro a quem só
      // abriu a app por um link qualquer.
      expect(
        ehCallbackDeAutenticacao(
          Uri.parse('washinvoicecontrol://instalacoes/42'),
        ),
        isFalse,
      );
    });
  });

  group('LinksDeAutenticacao', () {
    late StreamController<Uri> canal;
    late List<Uri> trocados;
    late List<Object> falhas;

    setUp(() {
      canal = StreamController<Uri>();
      trocados = [];
      falhas = [];
    });

    tearDown(() => canal.close());

    LinksDeAutenticacao criar({
      Future<Uri?> Function()? linkInicial,
      Future<void> Function(Uri)? trocar,
    }) => LinksDeAutenticacao(
      links: canal.stream,
      linkInicial: linkInicial,
      trocar: trocar ?? (uri) async => trocados.add(uri),
      aoFalhar: falhas.add,
    );

    test('troca o código de um link que chega com a app aberta', () async {
      await criar().escutar();

      canal.add(Uri.parse('washinvoicecontrol://auth/callback?code=abc'));
      await pumpEventQueue();

      expect(trocados, hasLength(1));
      expect(trocados.single.queryParameters['code'], 'abc');
      expect(falhas, isEmpty);
    });

    test('troca o link com que a app foi aberta de raiz', () async {
      // Arranque a frio: a app nasce por causa do link, e ele não passa pelo
      // stream — vem por `getInitialLink`.
      await criar(
        linkInicial: () async =>
            Uri.parse('washinvoicecontrol://auth/callback?code=frio'),
      ).escutar();

      expect(trocados.single.queryParameters['code'], 'frio');
    });

    test('o mesmo link duas vezes só é trocado uma', () async {
      // O código é de uso único: a segunda troca falharia sempre, e a pessoa
      // via uma mensagem de erro por cima de um ecrã que abrira bem.
      final link = Uri.parse('washinvoicecontrol://auth/callback?code=abc');
      await criar(linkInicial: () async => link).escutar();

      canal.add(link);
      await pumpEventQueue();

      expect(trocados, hasLength(1));
      expect(falhas, isEmpty);
    });

    test('deixa passar o que não é callback de autenticação', () async {
      await criar().escutar();

      canal.add(Uri.parse('washinvoicecontrol://instalacoes/42'));
      await pumpEventQueue();

      expect(trocados, isEmpty);
      expect(falhas, isEmpty);
    });

    test('uma troca falhada é contada, não engolida', () async {
      // Era exactamente isto que faltava: o observador de origem só escrevia
      // no log, e quem carregava no link via a app abrir como se nada fosse.
      await criar(
        trocar: (_) async => throw AuthException('Link expirado'),
      ).escutar();

      canal.add(Uri.parse('washinvoicecontrol://auth/callback?code=velho'));
      await pumpEventQueue();

      expect(falhas.single, isA<AuthException>());
    });

    test('depois de parar, deixa de tratar links', () async {
      final escuta = criar();
      await escuta.escutar();
      await escuta.parar();

      canal.add(Uri.parse('washinvoicecontrol://auth/callback?code=abc'));
      await pumpEventQueue();

      expect(trocados, isEmpty);
    });
  });
}
