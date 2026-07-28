import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/acessos/punho/punho_pedidos_screen.dart';
import 'package:washinvoice_control/repositories/providers.dart';

import 'fake_punho_admin_repository.dart';

Future<void> _montar(WidgetTester tester, FakePunhoAdmin fake) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [punhoAdminRepoProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: PunhoPedidosScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lista os pendentes com origem, cargo e organização indicada', (
    tester,
  ) async {
    await _montar(
      tester,
      FakePunhoAdmin(
        porEstado: {
          'pendente': [
            pedidoPunho(),
            pedidoPunho(
              id: 'p2',
              nome: 'Bruno Costa',
              email: 'bruno@exemplo.pt',
              organizacao: 'Empresa do Convite',
              origem: 'convite',
              perfil: 'colaborador',
              conviteEmpresaId: 'e1',
              conviteEmpresaNome: 'Empresa do Convite',
            ),
          ],
        },
        empresas: [empresaPunho()],
      ),
    );

    expect(find.text('Ana Silva'), findsOneWidget);
    expect(find.text('Bruno Costa'), findsOneWidget);
    expect(find.text('LIVRE'), findsOneWidget);
    expect(find.text('CONVITE'), findsOneWidget);
    expect(find.text('Organização indicada: Terraplanagens Ana'), findsOneWidget);
    expect(find.text('Cargo pretendido: Colaborador'), findsOneWidget);
    // Contexto do convite à vista, sem segunda ida à base.
    expect(
      find.textContaining('Convite da empresa Empresa do Convite'),
      findsOneWidget,
    );
    // Pendentes decidem-se, não se revogam.
    expect(find.widgetWithText(FilledButton, 'Decidir'), findsNWidgets(2));
    expect(find.text('Revogar'), findsNothing);
  });

  testWidgets('um pedido aprovado oferece Revogar, não Decidir', (tester) async {
    await _montar(
      tester,
      FakePunhoAdmin(
        porEstado: {
          'pendente': const [],
          'aprovado': [
            pedidoPunho(
              estado: 'aprovado',
              empresaId: 'e1',
              empresaNome: 'Terraplanagens Ana',
            ),
          ],
        },
      ),
    );

    await tester.tap(find.text('Aprovados'));
    await tester.pumpAndSettle();

    expect(find.text('Revogar'), findsOneWidget);
    expect(find.text('Decidir'), findsNothing);
    expect(find.text('Empresa: Terraplanagens Ana'), findsOneWidget);
  });

  testWidgets('um pedido recusado pode ser reaberto', (tester) async {
    await _montar(
      tester,
      FakePunhoAdmin(
        porEstado: {
          'pendente': const [],
          'recusado': [pedidoPunho(estado: 'recusado')],
        },
      ),
    );

    await tester.tap(find.text('Recusados'));
    await tester.pumpAndSettle();

    expect(find.text('Reabrir'), findsOneWidget);
  });

  testWidgets('estado vazio explica qual é o filtro activo', (tester) async {
    await _montar(tester, FakePunhoAdmin());
    expect(find.text('Não há pedidos pendentes.'), findsOneWidget);
  });

  testWidgets('erro do servidor mostra retentativa em vez de lista vazia', (
    tester,
  ) async {
    await _montar(tester, FakePunhoAdmin(erro: Exception('sem rede')));
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('aprovar um pedido livre chama a RPC e recarrega', (tester) async {
    final fake = FakePunhoAdmin(
      porEstado: {
        'pendente': [pedidoPunho()],
      },
      empresas: [empresaPunho()],
    );
    await _montar(tester, fake);

    await tester.tap(find.text('Decidir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Aprovar'));
    await tester.pumpAndSettle();

    expect(fake.decisoes, hasLength(1));
    expect(fake.decisoes.single['decisao'], 'aprovar');
    expect(fake.decisoes.single['pedido'], 'p1');
    // Sem escolha explícita, empresa nula = criar empresa nova.
    expect(fake.decisoes.single['empresa'], isNull);
  });

  testWidgets('cancelar o diálogo não decide nada', (tester) async {
    final fake = FakePunhoAdmin(
      porEstado: {
        'pendente': [pedidoPunho()],
      },
      empresas: [empresaPunho()],
    );
    await _montar(tester, fake);

    await tester.tap(find.text('Decidir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(fake.decisoes, isEmpty);
  });
}
