import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/auth/acesso_pendente_screen.dart';

void main() {
  Future<void> montar(WidgetTester tester, String estado) => tester.pumpWidget(
        MaterialApp(home: AcessoPendenteScreen(estado: estado)),
      );

  testWidgets('pendente: pedido em análise', (tester) async {
    await montar(tester, 'pendente');
    expect(find.text('Pedido em análise'), findsOneWidget);
    expect(find.textContaining('confirmação manual'), findsOneWidget);
    expect(find.text('Terminar sessão'), findsOneWidget);
  });

  testWidgets('recusado: acesso indisponível', (tester) async {
    await montar(tester, 'recusado');
    expect(find.text('Acesso indisponível'), findsOneWidget);
    expect(find.text('Terminar sessão'), findsOneWidget);
  });

  testWidgets('revogado: acesso indisponível', (tester) async {
    await montar(tester, 'revogado');
    expect(find.text('Acesso indisponível'), findsOneWidget);
  });
}
