import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/actualizacao/banner_actualizacao.dart';
import 'package:washinvoice_control/models/actualizacao_info.dart';
import 'package:washinvoice_control/repositories/providers.dart';

ActualizacaoInfo _info({required bool obrigatoria}) => ActualizacaoInfo(
      versaoActual: '1.7.1',
      buildNumber: 25,
      urlDownload: 'https://exemplo/apk',
      obrigatoria: obrigatoria,
    );

Future<ProviderContainer> _montar(
  WidgetTester tester, {
  ActualizacaoInfo? info,
  DescarregarUrl? descarregar,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  if (info != null) {
    container.read(actualizacaoDisponivelProvider.notifier).state = info;
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: BannerActualizacao(
            descarregar: descarregar ?? (_) async => true,
          ),
        ),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('sem actualização → banner não aparece', (tester) async {
    await _montar(tester);
    expect(find.text('Descarregar'), findsNothing);
    expect(find.textContaining('Nova versão'), findsNothing);
  });

  testWidgets('não obrigatória → banner com info e X', (tester) async {
    await _montar(tester, info: _info(obrigatoria: false));
    expect(find.textContaining('Nova versão 1.7.1'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.text('Descarregar'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget); // dispensável
  });

  testWidgets('obrigatória → banner vermelho sem X', (tester) async {
    await _montar(tester, info: _info(obrigatoria: true));
    expect(find.textContaining('Nova versão 1.7.1'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    expect(find.text('Descarregar'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing); // não se pode dispensar
  });

  testWidgets('carregar em Descarregar chama o launcher com o URL',
      (tester) async {
    Uri? aberto;
    await _montar(
      tester,
      info: _info(obrigatoria: false),
      descarregar: (url) async {
        aberto = url;
        return true;
      },
    );

    await tester.tap(find.text('Descarregar'));
    await tester.pump();

    expect(aberto, Uri.parse('https://exemplo/apk'));
  });

  testWidgets('X dispensa o banner (limpa o provider)', (tester) async {
    final container =
        await _montar(tester, info: _info(obrigatoria: false));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(container.read(actualizacaoDisponivelProvider), isNull);
    expect(find.text('Descarregar'), findsNothing);
  });
}
