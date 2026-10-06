import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/acessos/punho/punho_decidir_modal.dart';
import 'package:washinvoice_control/features/acessos/punho/punho_pedidos_screen.dart';
import 'package:washinvoice_control/repositories/providers.dart';
import 'package:washinvoice_control/repositories/punho_admin_repository.dart';

import 'fake_punho_admin_repository.dart';

Future<DecisaoFist?> _abrirRevogar(
  WidgetTester tester,
  FistPedido pedido,
) async {
  DecisaoFist? resultado;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              resultado = await showDialog<DecisaoFist>(
                context: context,
                builder: (_) => FistRevogarModal(pedido: pedido),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return resultado;
}

void main() {
  testWidgets('mostra o impacto: quem perde o acesso e quando', (tester) async {
    await _abrirRevogar(
      tester,
      pedidoFist(
        estado: 'aprovado',
        empresaId: 'e1',
        empresaNome: 'Terraplanagens Ana',
      ),
    );

    expect(find.text('Revogar acesso'), findsOneWidget);
    expect(
      find.textContaining('Ana Silva (ana@exemplo.pt) perde o acesso'),
      findsOneWidget,
    );
    expect(find.textContaining('próximo arranque'), findsOneWidget);
    expect(find.textContaining('Terraplanagens Ana'), findsOneWidget);
    expect(find.textContaining('liberta uma vaga'), findsOneWidget);
    // Deixa claro que é reversível — não é um delete.
    expect(find.textContaining('Nada é apagado'), findsOneWidget);
  });

  testWidgets('pede confirmação: cancelar não devolve decisão', (tester) async {
    await _abrirRevogar(tester, pedidoFist(estado: 'aprovado'));

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    // O diálogo fecha sem decidir nada.
    expect(find.text('Revogar acesso'), findsNothing);
  });

  testWidgets('confirmar devolve a decisão de revogar', (tester) async {
    DecisaoFist? escolhido;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                escolhido = await showDialog<DecisaoFist>(
                  context: context,
                  builder: (_) =>
                      FistRevogarModal(pedido: pedidoFist(estado: 'aprovado')),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Revogar'));
    await tester.pumpAndSettle();

    expect(escolhido!.decisao, 'revogar');
    expect(escolhido!.empresaId, isNull);
  });

  testWidgets('no ecrã, revogar só chega à RPC depois de confirmado', (
    tester,
  ) async {
    final fake = FakeFistAdmin(
      porEstado: {
        'pendente': const [],
        'aprovado': [pedidoFist(estado: 'aprovado', empresaNome: 'Empresa A')],
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [punhoAdminRepoProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: FistPedidosScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aprovados'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Revogar'));
    await tester.pumpAndSettle();
    // Diálogo aberto, nada decidido.
    expect(fake.decisoes, isEmpty);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(fake.decisoes, isEmpty);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Revogar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Revogar'));
    await tester.pumpAndSettle();

    expect(fake.decisoes, hasLength(1));
    expect(fake.decisoes.single['decisao'], 'revogar');
  });
}
