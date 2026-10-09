import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:washinvoice_control/features/agora/agora_modelo.dart';
import 'package:washinvoice_control/features/agora/agora_providers.dart';
import 'package:washinvoice_control/features/agora/agora_screen.dart';
import 'package:washinvoice_control/features/nav/home_shell.dart';
import 'package:washinvoice_control/services/push_routing.dart';

import '../acessos/punho/fake_punho_admin_repository.dart';
import '../agora/agora_helpers.dart';

/// **A barra de baixo e as páginas têm de ter o mesmo comprimento.**
///
/// Já houve cinco páginas para quatro botões: `currentIndex` valia 4 numa
/// barra de 0..3 e o `BottomNavigationBar` atirava `RangeError` a cada frame.
/// A app ficava pintada mas morta (Redmi, 5/8/2026).
Future<ProviderContainer> _montar(
  WidgetTester tester, {
  bool admin = true,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = agoraAgora;
  final container = ProviderContainer(
    overrides: overridesAgora(
      admin: admin,
      licencas: [licencaTeste('1', validade: h.subtract(const Duration(days: 2)))],
      pings: [pingTeste('9')],
      ajuda: [ajudaTeste('a')],
      fist: [pedidoFist()],
    ),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: HomeShell(
          paginasParaTeste: [
            AgoraScreen(),
            Center(child: Text('PAGINA_CLIENTES')),
            Center(child: Text('PAGINA_HISTORICO')),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(() {
    timeago.setLocaleMessages('pt', timeago.PtBrMessages());
    PackageInfo.setMockInitialValues(
      appName: 'Control',
      packageName: 'x',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('barra e páginas andam a par', () {
    test('mesmo comprimento, três separadores', () {
      expect(HomeShell.itens().length, HomeShell.paginas.length);
      expect(HomeShell.itens().length, 3);
    });

    test('rótulos: Agora · Clientes · Histórico', () {
      expect(HomeShell.itens().map((i) => i.label), [
        'Agora',
        'Clientes',
        'Histórico',
      ]);
    });
  });

  testWidgets('sem botão flutuante em nenhum separador', (tester) async {
    await _montar(tester);
    for (final rotulo in ['Agora', 'Clientes', 'Histórico']) {
      await tester.tap(find.text(rotulo).last);
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing, reason: rotulo);
    }
  });

  testWidgets('badge: total pendente no «Agora»', (tester) async {
    final c = await _montar(tester);
    // expirada + acesso Fist + ajuda + terminal novo = 4
    expect(c.read(agoraTotalProvider), 4);
    expect(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('navegar pelos três separadores, a tocar e a arrastar', (
    tester,
  ) async {
    await _montar(tester);
    expect(find.text('Nada pendente'), findsNothing);
    await tester.tap(find.text('Clientes'));
    await tester.pumpAndSettle();
    expect(find.text('PAGINA_CLIENTES'), findsOneWidget);
    await tester.tap(find.text('Histórico').last);
    await tester.pumpAndSettle();
    expect(find.text('PAGINA_HISTORICO'), findsOneWidget);
    // Arrastar para a direita volta a Clientes.
    await tester.fling(find.byType(PageView), const Offset(600, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.text('PAGINA_CLIENTES'), findsOneWidget);
  });

  group('push routing no shell', () {
    testWidgets('novo_terminal → Agora filtrado por terminal novo', (
      tester,
    ) async {
      final c = await _montar(tester);
      await tester.tap(find.text('Clientes'));
      await tester.pumpAndSettle();
      c.read(destinoPushProvider.notifier).state =
          DestinoPush.agoraTerminalNovo;
      await tester.pumpAndSettle();
      expect(c.read(agoraTipoFiltroProvider), TipoAgora.terminalNovo);
      expect(find.text('Activar'), findsOneWidget);
      expect(find.text('Resolvido'), findsNothing);
      expect(c.read(destinoPushProvider), isNull);
    });

    testWidgets('pedido_ajuda → Agora filtrado por ajuda', (tester) async {
      final c = await _montar(tester);
      c.read(destinoPushProvider.notifier).state = DestinoPush.agoraAjuda;
      await tester.pumpAndSettle();
      expect(c.read(agoraTipoFiltroProvider), TipoAgora.ajuda);
      expect(find.text('Resolvido'), findsOneWidget);
      expect(find.text('Activar'), findsNothing);
    });

    testWidgets('novo_pedido → Agora filtrado por acessos Fist', (
      tester,
    ) async {
      final c = await _montar(tester);
      await tester.tap(find.text('Clientes'));
      await tester.pumpAndSettle();
      c.read(destinoPushProvider.notifier).state = DestinoPush.pedidosFist;
      await tester.pumpAndSettle();
      expect(c.read(agoraTipoFiltroProvider), TipoAgora.acessoFist);
      expect(find.textContaining('Aceitar'), findsOneWidget);
    });

    testWidgets('inicio_actividade → Clientes', (tester) async {
      final c = await _montar(tester);
      c.read(destinoPushProvider.notifier).state = DestinoPush.resumo;
      await tester.pumpAndSettle();
      expect(find.text('PAGINA_CLIENTES'), findsOneWidget);
    });
  });
}
