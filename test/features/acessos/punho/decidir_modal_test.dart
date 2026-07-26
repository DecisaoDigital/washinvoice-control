import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/acessos/punho/punho_decidir_modal.dart';
import 'package:washinvoice_control/repositories/punho_admin_repository.dart';

import 'fake_punho_admin_repository.dart';

/// Monta o diálogo isolado e devolve o que ele decidiu.
Future<DecisaoPunho?> _abrir(
  WidgetTester tester, {
  required PunhoPedido pedido,
  List<PunhoEmpresa> empresas = const [],
}) async {
  DecisaoPunho? resultado;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              resultado = await showDialog<DecisaoPunho>(
                context: context,
                builder: (_) =>
                    PunhoDecidirModal(pedido: pedido, empresas: empresas),
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
  group('Pedido por convite — a empresa é fixa', () {
    testWidgets('não oferece escolha de empresa', (tester) async {
      await _abrir(
        tester,
        pedido: pedidoPunho(
          origem: 'convite',
          perfil: 'colaborador',
          conviteEmpresaId: 'e1',
          conviteEmpresaNome: 'Empresa do Convite',
        ),
        empresas: [empresaPunho(), empresaPunho(id: 'e2', nome: 'Outra')],
      );

      expect(find.textContaining('Empresa do Convite'), findsOneWidget);
      expect(
        find.textContaining('vem do convite e não pode ser mudada'),
        findsOneWidget,
      );
      // Nem dropdown nem escolha de limite.
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.byType(RadioListTile<bool>), findsNothing);
      expect(find.text('Limite de utilizadores'), findsNothing);
    });

    testWidgets('aprovar não envia empresa — quem manda é o servidor', (
      tester,
    ) async {
      await tester.runAsync(() async {});
      DecisaoPunho? escolhido;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  escolhido = await showDialog<DecisaoPunho>(
                    context: context,
                    builder: (_) => PunhoDecidirModal(
                      pedido: pedidoPunho(
                        origem: 'convite',
                        conviteEmpresaId: 'e1',
                        conviteEmpresaNome: 'Empresa do Convite',
                      ),
                      empresas: const [],
                    ),
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
      await tester.tap(find.widgetWithText(FilledButton, 'Aprovar'));
      await tester.pumpAndSettle();

      expect(escolhido!.decisao, 'aprovar');
      expect(escolhido!.empresaId, isNull);
    });
  });

  group('Pedido livre — criar nova ou anexar', () {
    testWidgets('por omissão propõe criar a organização indicada', (
      tester,
    ) async {
      await _abrir(
        tester,
        pedido: pedidoPunho(),
        empresas: [empresaPunho()],
      );

      expect(find.text('Criar nova "Terraplanagens Ana"'), findsOneWidget);
      expect(find.text('Anexar a empresa existente'), findsOneWidget);
      // O limite só aparece no modo "criar nova", que é o inicial.
      expect(find.text('Limite de utilizadores'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('escolher anexar mostra o dropdown com a ocupação', (
      tester,
    ) async {
      await _abrir(
        tester,
        pedido: pedidoPunho(),
        empresas: [empresaPunho(nome: 'Empresa A', limite: 3, ativos: 2)],
      );

      await tester.tap(find.text('Anexar a empresa existente'));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.text('Limite de utilizadores'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Empresa A · 2 / 3').hitTestable(), findsOneWidget);
    });

    testWidgets('sem empresa escolhida, aprovar fica desactivado', (
      tester,
    ) async {
      await _abrir(
        tester,
        pedido: pedidoPunho(),
        empresas: [empresaPunho()],
      );

      await tester.tap(find.text('Anexar a empresa existente'));
      await tester.pumpAndSettle();

      final botao = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Aprovar'),
      );
      expect(botao.onPressed, isNull);
    });

    testWidgets('avisa quando a empresa escolhida está no limite', (
      tester,
    ) async {
      await _abrir(
        tester,
        pedido: pedidoPunho(),
        empresas: [empresaPunho(nome: 'Cheia', limite: 2, ativos: 2)],
      );

      await tester.tap(find.text('Anexar a empresa existente'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cheia · 2 / 2').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('já está no limite'), findsOneWidget);
    });

    testWidgets('sem empresas existentes não deixa escolher anexar', (
      tester,
    ) async {
      await _abrir(tester, pedido: pedidoPunho(), empresas: const []);

      final opcao = tester.widget<RadioListTile<bool>>(
        find.widgetWithText(RadioListTile<bool>, 'Anexar a empresa existente'),
      );
      expect(opcao.onChanged, isNull);
    });
  });

  group('Limite de utilizadores', () {
    testWidgets('o valor escrito é o que segue na decisão', (tester) async {
      DecisaoPunho? escolhido;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  escolhido = await showDialog<DecisaoPunho>(
                    context: context,
                    builder: (_) => PunhoDecidirModal(
                      pedido: pedidoPunho(),
                      empresas: const [],
                    ),
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

      await tester.enterText(
        find.widgetWithText(TextField, 'Limite de utilizadores'),
        '7',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Aprovar'));
      await tester.pumpAndSettle();

      expect(escolhido!.limiteUtilizadores, 7);
      expect(escolhido!.empresaId, isNull);
    });

    testWidgets('lixo no campo cai em 1 em vez de rebentar', (tester) async {
      DecisaoPunho? escolhido;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  escolhido = await showDialog<DecisaoPunho>(
                    context: context,
                    builder: (_) => PunhoDecidirModal(
                      pedido: pedidoPunho(),
                      empresas: const [],
                    ),
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

      await tester.enterText(
        find.widgetWithText(TextField, 'Limite de utilizadores'),
        'zero',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Aprovar'));
      await tester.pumpAndSettle();

      expect(escolhido!.limiteUtilizadores, 1);
    });
  });

  testWidgets('recusar devolve a decisão sem empresa', (tester) async {
    DecisaoPunho? escolhido;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                escolhido = await showDialog<DecisaoPunho>(
                  context: context,
                  builder: (_) => PunhoDecidirModal(
                    pedido: pedidoPunho(),
                    empresas: const [],
                  ),
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
    await tester.tap(find.widgetWithText(OutlinedButton, 'Recusar'));
    await tester.pumpAndSettle();

    expect(escolhido!.decisao, 'recusar');
    expect(escolhido!.empresaId, isNull);
  });
}
