import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/acessos/punho/punho_editar_limite_modal.dart';

import 'fake_punho_admin_repository.dart';

Future<NovoLimite?> Function() _abrir(WidgetTester tester, int limite) {
  NovoLimite? resultado;
  return () async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultado = await showDialog<NovoLimite>(
                  context: context,
                  builder: (_) => FistEditarLimiteModal(
                    empresa: empresaFist(limite: limite),
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
    return resultado;
  };
}

void main() {
  testWidgets('os packs sobem e descem de 3 em 3', (tester) async {
    await _abrir(tester, 3)();
    await tester.tap(find.text('+ 1 pack'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '6'), findsOneWidget);
    await tester.tap(find.text('− 1 pack'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '3'), findsOneWidget);
  });

  testWidgets('avisa quando o limite não é múltiplo de 3 e continua a subir de 3 em 3',
      (tester) async {
    await _abrir(tester, 5)();
    expect(find.textContaining('Não é múltiplo de 3'), findsOneWidget);
    await tester.tap(find.text('+ 1 pack'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '8'), findsOneWidget);
  });
}
