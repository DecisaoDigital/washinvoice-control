import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:washinvoice_control/features/acessos/punho/punho_pedidos_screen.dart';
import 'package:washinvoice_control/features/agora/agora_modelo.dart';
import 'package:washinvoice_control/features/agora/agora_providers.dart';
import 'package:washinvoice_control/features/agora/agora_screen.dart';
import 'package:washinvoice_control/features/dashboard/dashboard_screen.dart';
import 'package:washinvoice_control/features/nav/home_shell.dart';
import 'package:washinvoice_control/features/nav/mais_screen.dart';
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
            MaisScreen(),
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

    test('rótulos: Agora · Clientes · Mais', () {
      expect(HomeShell.itens().map((i) => i.label), [
        'Agora',
        'Clientes',
        'Mais',
      ]);
    });
  });

  testWidgets('sem botão flutuante em nenhum separador', (tester) async {
    await _montar(tester);
    for (final rotulo in ['Agora', 'Clientes', 'Mais']) {
      await tester.tap(find.text(rotulo).last);
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing, reason: rotulo);
    }
  });

  testWidgets('badges: total no «Agora», pedidos Fist no «Mais»', (
    tester,
  ) async {
    final c = await _montar(tester);
    // expirada + acesso Fist + ajuda + terminal novo = 4
    expect(c.read(agoraTotalProvider), 4);
    expect(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('4')), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('1')), findsOneWidget);
  });

  testWidgets('navegar pelos três separadores', (tester) async {
    await _montar(tester);
    expect(find.text('Nada pendente'), findsNothing);
    await tester.tap(find.text('Clientes'));
    await tester.pumpAndSettle();
    expect(find.text('PAGINA_CLIENTES'), findsOneWidget);
    await tester.tap(find.text('Mais').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mais_resumo')), findsOneWidget);
  });

  testWidgets('«Mais» lista as entradas; Pedidos Fist só ao admin', (
    tester,
  ) async {
    await _montar(tester);
    await tester.tap(find.text('Mais').last);
    await tester.pumpAndSettle();
    for (final k in [
      'resumo', 'pedidosFist', 'acessos', 'mapa', 'sugestoes',
      'pedidosAjuda', 'sobre',
    ]) {
      expect(find.byKey(ValueKey('mais_$k')), findsOneWidget, reason: k);
    }
  });

  testWidgets('«Mais» sem Pedidos Fist para quem não é admin global', (
    tester,
  ) async {
    await _montar(tester, admin: false);
    await tester.tap(find.text('Mais').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mais_pedidosFist')), findsNothing);
    expect(find.byKey(const ValueKey('mais_resumo')), findsOneWidget);
  });

  testWidgets('«Pedidos Fist» em Mais abre o ecrã por cima', (tester) async {
    await _montar(tester);
    await tester.tap(find.text('Mais').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mais_pedidosFist')));
    await tester.pumpAndSettle();
    expect(find.byType(FistPedidosScreen), findsOneWidget);
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

    testWidgets('novo_pedido → Pedidos Fist dentro de Mais (admin)', (
      tester,
    ) async {
      final c = await _montar(tester);
      c.read(destinoPushProvider.notifier).state = DestinoPush.pedidosFist;
      await tester.pumpAndSettle();
      expect(find.byType(FistPedidosScreen), findsOneWidget);
    });

    testWidgets('novo_pedido sem ser admin: fica no Agora, sem erro', (
      tester,
    ) async {
      final c = await _montar(tester, admin: false);
      await tester.tap(find.text('Clientes'));
      await tester.pumpAndSettle();
      c.read(destinoPushProvider.notifier).state = DestinoPush.pedidosFist;
      await tester.pumpAndSettle();
      expect(find.byType(FistPedidosScreen), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.byType(AgoraScreen), findsOneWidget);
    });

    testWidgets('inicio_actividade → Resumo dentro de Mais', (tester) async {
      final c = await _montar(tester);
      c.read(destinoPushProvider.notifier).state = DestinoPush.resumo;
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });
}
