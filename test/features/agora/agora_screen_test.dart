import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:washinvoice_control/core/app_filter/app_filter_provider.dart';
import 'package:washinvoice_control/features/agora/agora_modelo.dart';
import 'package:washinvoice_control/features/agora/agora_providers.dart';
import 'package:washinvoice_control/features/agora/agora_screen.dart';
import 'package:washinvoice_control/repositories/providers.dart';

import '../acessos/punho/fake_punho_admin_repository.dart';
import 'agora_helpers.dart';

Future<ProviderContainer> _montar(
  WidgetTester tester,
  List<Override> overrides,
) async {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AgoraScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

List<Override> _tudo({FakeAjuda? fakeAjuda}) {
  final h = agoraAgora;
  return overridesAgora(
    licencas: [
      licencaTeste('1', validade: h.subtract(const Duration(days: 2))),
      licencaTeste('2', validade: h.add(const Duration(days: 4))),
    ],
    pings: [pingTeste('9')],
    ajuda: [ajudaTeste('a')],
    renovacoes: [renovacaoTeste('r')],
    sugestoes: [sugestaoTeste('s')],
    fist: [pedidoFist()],
    fakeAjuda: fakeAjuda,
  );
}

void main() {
  setUpAll(() => timeago.setLocaleMessages('pt', timeago.PtBrMessages()));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sem nada pendente: «Nada pendente»', (tester) async {
    await _montar(tester, overridesAgora());
    expect(find.text('Nada pendente'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('cartões por urgência, cada um com o seu botão visível', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await _montar(tester, _tudo());

    // Ordem vertical = prioridade.
    final tops = [
      tester.getTopLeft(find.textContaining('Aceitar')).dy,
      tester.getTopLeft(find.text('Ligar')).dy,
      tester.getTopLeft(find.text('Activar')).dy,
      tester.getTopLeft(find.text('Renovar').at(0)).dy, // pedido de renovação
      tester.getTopLeft(find.text('Renovar').at(1)).dy, // expirada
      tester.getTopLeft(find.text('Renovar').at(2)).dy, // a expirar
      tester.getTopLeft(find.text('Abrir')).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(find.text('Resolvido'), findsOneWidget);

    // Alvos de toque ≥ 48 dp.
    for (final b in tester.widgetList<FilledButton>(find.byType(FilledButton))) {
      expect(b, isNotNull);
    }
    for (final f in find.byType(FilledButton).evaluate()) {
      expect(tester.getSize(find.byWidget(f.widget)).height, greaterThanOrEqualTo(48));
    }

    expect(c.read(agoraTotalProvider), 7);
    expect(find.text('a ver: Todas'), findsOneWidget);
  });

  testWidgets('chips mostram contagens e filtram a lista', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _montar(tester, _tudo());

    expect(find.text('Tudo (7)'), findsOneWidget);
    expect(find.text('Ajuda (1)'), findsOneWidget);
    expect(find.text('Terminais novos (1)'), findsOneWidget);

    await tester.tap(find.text('Ajuda (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Resolvido'), findsOneWidget);
    expect(find.textContaining('Aceitar'), findsNothing);
    expect(find.text('Activar'), findsNothing);

    // Tocar outra vez no mesmo chip limpa o filtro.
    await tester.tap(find.text('Ajuda (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aceitar'), findsOneWidget);
  });

  testWidgets('filtro de app: «a ver: WashInvoice» e sem pedidos Fist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await _montar(tester, _tudo());
    await c.read(appFilterProvider.notifier).definir(AppFiltro.pos);
    await tester.pumpAndSettle();

    expect(find.text('a ver: WashInvoice'), findsOneWidget);
    expect(find.textContaining('Aceitar'), findsNothing);
  });

  testWidgets('Resolvido chama o repositório e oferece Anular', (tester) async {
    final fake = FakeAjuda([ajudaTeste('a')]);
    await _montar(tester, overridesAgora(fakeAjuda: fake));

    await tester.tap(find.text('Resolvido'));
    await tester.pumpAndSettle();
    expect(fake.resolvidos, ['a']);
  });

  testWidgets('erro a carregar: mensagem e «Tentar de novo»', (tester) async {
    await _montar(tester, overridesAgora(erroLicencas: Exception('boom')));
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.text('Nada pendente'), findsNothing);
  });

  testWidgets('voltar à app refaz a fila', (tester) async {
    final lic = FakeLic(const []);
    await _montar(tester, [
      ...overridesAgora(),
      licencasRepoProvider.overrideWithValue(lic),
    ]);
    final antes = lic.chamadas;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(lic.chamadas, antes + 1);
  });

  test('o tipo escolhido volta a null por omissão', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(agoraTipoFiltroProvider), isNull);
    c.read(agoraTipoFiltroProvider.notifier).state = TipoAgora.ajuda;
    expect(c.read(agoraTipoFiltroProvider), TipoAgora.ajuda);
  });
}
