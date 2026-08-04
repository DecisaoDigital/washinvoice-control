import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/auth/nova_palavra_passe_screen.dart';

/// **O caminho de volta de quem perdeu a palavra-passe do Control.**
///
/// Estava partido em dois sitios, e nenhum dava erro. O "Esqueci a
/// palavra-passe" (#240) nunca teve `redirectTo` nem esquema proprio: o link
/// caia no `site_url` global, que e o do POS (`washinvoice://`), e abria a outra
/// app. Registar o esquema sozinho seria pior — **abrir o link autentica**, e a
/// pessoa entrava no Control sem lhe ser pedida palavra-passe nenhuma. Este ecra
/// e a metade que faltava.
void main() {
  Future<void> abrir(
    WidgetTester tester, {
    Future<String?> Function(String)? aoGuardar,
    VoidCallback? aoDesistir,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NovaPalavraPasseScreen(
          aoGuardar: aoGuardar ?? (_) async => null,
          aoDesistir: aoDesistir ?? () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> escrever(
    WidgetTester tester,
    String nova,
    String repetida,
  ) async {
    await tester.enterText(find.byType(TextField).first, nova);
    await tester.enterText(find.byType(TextField).last, repetida);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
  }

  testWidgets('pede a palavra-passe nova duas vezes', (tester) async {
    await abrir(tester);

    // Duas e nao uma: um erro de dedos aqui tranca a conta na tentativa
    // seguinte, e ja nao ha segundo link para a destrancar.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Guardar'), findsOneWidget);
  });

  testWidgets('nao guarda se as duas nao forem iguais', (tester) async {
    var guardou = false;
    await abrir(
      tester,
      aoGuardar: (_) async {
        guardou = true;
        return null;
      },
    );

    await escrever(tester, 'palavra-longa-1', 'palavra-longa-2');

    expect(guardou, isFalse);
    expect(find.text('As duas nao sao iguais.'), findsOneWidget);
  });

  testWidgets('nao guarda uma palavra-passe curta', (tester) async {
    var guardou = false;
    await abrir(
      tester,
      aoGuardar: (_) async {
        guardou = true;
        return null;
      },
    );

    await escrever(tester, 'curta', 'curta');

    expect(guardou, isFalse);
    // A mesma regra do "Mudar palavra-passe" do Sobre. Duas regras diferentes
    // para a mesma coisa e a app a contradizer-se.
    expect(
      find.text('A palavra-passe deve ter pelo menos 8 caracteres.'),
      findsOneWidget,
    );
  });

  testWidgets('guarda a que serve, e diz que ficou feito', (tester) async {
    String? guardada;
    await abrir(
      tester,
      aoGuardar: (nova) async {
        guardada = nova;
        return null;
      },
    );

    await escrever(tester, 'uma-boa-palavra-passe', 'uma-boa-palavra-passe');

    expect(guardada, 'uma-boa-palavra-passe');
    expect(find.text('Palavra-passe alterada.'), findsOneWidget);
  });

  testWidgets('o erro do servidor aparece, e nao se finge que correu bem', (
    tester,
  ) async {
    await abrir(
      tester,
      aoGuardar: (_) async => 'Palavra-passe demasiado fraca.',
    );

    await escrever(tester, 'uma-boa-palavra-passe', 'uma-boa-palavra-passe');

    expect(find.text('Palavra-passe demasiado fraca.'), findsOneWidget);
    expect(find.text('Palavra-passe alterada.'), findsNothing);
  });

  testWidgets('desistir fecha a sessao que o link abriu', (tester) async {
    var desistiu = false;
    await abrir(tester, aoDesistir: () => desistiu = true);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Sair daqui sem fechar a sessao deixava a porta encostada a quem so
    // clicou num email.
    expect(desistiu, isTrue);
  });
}
