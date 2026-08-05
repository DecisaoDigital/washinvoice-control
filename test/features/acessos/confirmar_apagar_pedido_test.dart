import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/acessos/confirmar_apagar_pedido.dart';

/// A régua da única acção destas listas que não se desfaz.
void main() {
  Future<bool?> abrir(WidgetTester tester, String estado) async {
    bool? resposta;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  resposta = await confirmarApagarPedido(
                    ctx,
                    quem: 'Ana Dias',
                    email: 'ana@exemplo.pt',
                    estado: estado,
                  ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return resposta;
  }

  testWidgets('diz de quem é o pedido antes de perguntar', (tester) async {
    await abrir(tester, 'pendente');

    // Numa lista de linhas iguais, "Apagar?" sem nome é um convite a enganos.
    expect(find.text('Ana Dias'), findsOneWidget);
    expect(find.text('ana@exemplo.pt'), findsOneWidget);
    expect(find.textContaining('não há como o trazer de volta'), findsOneWidget);
  });

  testWidgets('num pedido aprovado avisa que a pessoa perde a entrada', (
    tester,
  ) async {
    await abrir(tester, 'aprovado');

    expect(find.textContaining('tira-lhe a entrada'), findsOneWidget);
  });

  testWidgets('num pedido pendente não inventa esse aviso', (tester) async {
    await abrir(tester, 'pendente');

    expect(find.textContaining('tira-lhe a entrada'), findsNothing);
  });

  testWidgets('cancelar responde não', (tester) async {
    await abrir(tester, 'pendente');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('fechar por fora conta como não apagar', (tester) async {
    // O `showDialog` devolve null quando se toca fora; se isso virasse `true`
    // por descuido, um toque distraído apagava.
    await abrir(tester, 'pendente');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}
