import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/acessos/punho/punho_pedidos_screen.dart';
import 'package:washinvoice_control/repositories/providers.dart';

import 'fake_punho_admin_repository.dart';

/// Monta o ecrã e devolve o container, para o teste poder mexer nos providers
/// como o HomeShell mexe.
Future<ProviderContainer> _montar(
  WidgetTester tester,
  FakeFistAdmin fake,
) async {
  final container = ProviderContainer(
    overrides: [punhoAdminRepoProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: FistPedidosScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('voltar à app recarrega a lista', (tester) async {
    // O ecrã fica montado no IndexedStack do HomeShell: se não reagir ao
    // lifecycle, o Cesar volta de ler um push e vê o que lá estava antes.
    final fake = FakeFistAdmin(
      porEstado: {
        'pendente': [pedidoFist()],
      },
    );
    await _montar(tester, fake);
    expect(fake.listagens, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(fake.listagens, 2);
  });

  testWidgets('sair da app sem voltar não recarrega', (tester) async {
    final fake = FakeFistAdmin(porEstado: {'pendente': [pedidoFist()]});
    await _montar(tester, fake);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();

    expect(fake.listagens, 1);
  });

  testWidgets('entrar no separador recarrega (ticker do HomeShell)', (
    tester,
  ) async {
    final fake = FakeFistAdmin(porEstado: {'pendente': [pedidoFist()]});
    final container = await _montar(tester, fake);
    expect(fake.listagens, 1);

    // É isto que o HomeShell faz no onTap do separador Fist.
    container.read(punhoPedidosRefreshProvider.notifier).state++;
    await tester.pumpAndSettle();

    expect(fake.listagens, 2);
  });

  testWidgets('a lista recarregada mostra os dados novos, não os velhos', (
    tester,
  ) async {
    // O sintoma que o Cesar viu: uma linha que já não existia na base.
    final porEstado = {
      'pendente': [pedidoFist(nome: 'Ana Silva')],
    };
    final fake = FakeFistAdmin(porEstado: porEstado);
    await _montar(tester, fake);
    expect(find.text('Ana Silva'), findsOneWidget);

    porEstado['pendente'] = const [];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Ana Silva'), findsNothing);
    expect(find.text('Não há pedidos pendentes.'), findsOneWidget);
  });
}
