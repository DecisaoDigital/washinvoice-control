import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/instalacoes/confirmar_apagar_licenca.dart';

/// A mesma pergunta não serve para as duas apps.
///
/// Uma licença do Punho é uma linha solta e apaga-se sem consequência. Uma do
/// POS pode ter séries e credenciais que vão junto, ou guias comunicadas à AT
/// que não deixam apagar nada. A caixa tem de mostrar essa diferença — é para
/// isso que existe.
void main() {
  Future<bool?> abrir(WidgetTester tester, Map<String, dynamic> deps) async {
    bool? resposta;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async => resposta =
                  await confirmarApagarLicenca(ctx, dependentes: deps),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return resposta;
  }

  Map<String, dynamic> punho({int series = 0, int guias = 0, int cred = 0}) => {
    'app': 'punho',
    'nome': 'Lavandaria Mare Alta',
    'machine_id': '339ed1626af8fc4729878db445dc79aa',
    'series': series,
    'guias': guias,
    'credenciais': cred,
  };

  testWidgets('licença solta: pergunta simples e deixa apagar', (tester) async {
    await abrir(tester, punho());

    expect(find.text('Apagar esta licença?'), findsOneWidget);
    expect(find.text('Apagar'), findsOneWidget);
    expect(find.textContaining('Vai junto com ela'), findsNothing);
    // O terminal volta a registar-se — quem apaga tem de saber isso, senão
    // apaga a mesma linha três vezes a perguntar-se porque volta.
    expect(find.textContaining('volta a registar-se'), findsOneWidget);
  });

  testWidgets('com guias comunicadas à AT não há botão de apagar', (
    tester,
  ) async {
    // O servidor recusa na mesma; oferecer o botão só para ele falhar é fazer
    // perder tempo a quem carrega.
    await abrir(tester, punho(guias: 4));

    expect(find.text('Esta não se apaga'), findsOneWidget);
    expect(find.text('Apagar'), findsNothing);
    expect(find.textContaining('4 guia(s)'), findsOneWidget);
    expect(find.textContaining('desactiva a licença'), findsOneWidget);
  });

  testWidgets('diz por números o que vai junto', (tester) async {
    await abrir(tester, punho(series: 2, cred: 1));

    expect(find.textContaining('2 série(s) comunicada(s)'), findsOneWidget);
    expect(find.textContaining('1 credencial(is) WSE'), findsOneWidget);
  });

  testWidgets('sem nome não mostra um vazio', (tester) async {
    await abrir(tester, {...punho(), 'nome': null});

    expect(find.text('Sem nome'), findsOneWidget);
  });

  testWidgets('cancelar responde não', (tester) async {
    await abrir(tester, punho());
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('contagens que chegam como texto também contam', (tester) async {
    // O `jsonb_build_object` devolve os counts como número, mas o Postgres
    // manda `bigint` e o cliente pode entregá-lo como String — se isso passar
    // a zero em silêncio, a caixa deixa de avisar do que interessa.
    await abrir(tester, {...punho(), 'guias': '3'});

    expect(find.text('Esta não se apaga'), findsOneWidget);
    expect(find.textContaining('3 guia(s)'), findsOneWidget);
  });
}
