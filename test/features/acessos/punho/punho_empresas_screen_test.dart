import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/acessos/punho/punho_empresas_screen.dart';
import 'package:washinvoice_control/repositories/providers.dart';

import 'fake_punho_admin_repository.dart';

Future<void> _montar(WidgetTester tester, FakeFistAdmin fake) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [punhoAdminRepoProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: FistEmpresasScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lista as empresas com a ocupação actual', (tester) async {
    await _montar(
      tester,
      FakeFistAdmin(
        empresas: [
          empresaFist(nome: 'Terraplanagens Ana', limite: 3, ativos: 1),
          empresaFist(id: 'e2', nome: 'Empresa do Convite', limite: 2, ativos: 2),
        ],
      ),
    );

    expect(find.text('Terraplanagens Ana'), findsOneWidget);
    expect(find.text('1 / 3 colaboradores activos'), findsOneWidget);
    expect(find.text('Empresa do Convite'), findsOneWidget);
    expect(find.text('2 / 2 colaboradores activos'), findsOneWidget);
    // Só a empresa no limite mostra o aviso.
    expect(
      find.textContaining('No limite — novos colaboradores'),
      findsOneWidget,
    );
  });

  testWidgets('estado vazio quando não há empresas', (tester) async {
    await _montar(tester, FakeFistAdmin());
    expect(find.text('Ainda não há empresas Fist.'), findsOneWidget);
  });

  testWidgets('erro do servidor mostra retentativa em vez de lista vazia', (
    tester,
  ) async {
    await _montar(tester, FakeFistAdmin(erro: Exception('sem rede')));
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('editar o limite chama a RPC com o novo valor e recarrega', (
    tester,
  ) async {
    final fake = FakeFistAdmin(
      empresas: [empresaFist(id: 'e1', nome: 'Terraplanagens Ana', limite: 3, ativos: 1)],
    );
    await _montar(tester, fake);

    await tester.tap(find.text('Editar limite'));
    await tester.pumpAndSettle();

    // Pré-preenchido com o limite actual.
    expect(find.text('3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(fake.limitesDefinidos, hasLength(1));
    expect(fake.limitesDefinidos.single['empresa'], 'e1');
    expect(fake.limitesDefinidos.single['limite'], 5);
  });

  testWidgets('cancelar o diálogo não muda nada', (tester) async {
    final fake = FakeFistAdmin(empresas: [empresaFist()]);
    await _montar(tester, fake);

    await tester.tap(find.text('Editar limite'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(fake.limitesDefinidos, isEmpty);
  });

  testWidgets('limite inválido deixa Guardar desactivado', (tester) async {
    final fake = FakeFistAdmin(empresas: [empresaFist()]);
    await _montar(tester, fake);

    await tester.tap(find.text('Editar limite'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();

    final guardar = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Guardar'),
    );
    expect(guardar.onPressed, isNull);
  });
}
