import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/erros.dart';

/// A régua da mensagem que chega antes do ecrã.
///
/// O link de recuperação vindo do email arranca a app e, se falhar, falha
/// durante o arranque — antes de haver `ScaffoldMessenger` a quem pedir um
/// SnackBar. Era assim que a app abria calada depois de se carregar num link
/// caducado.
void main() {
  testWidgets('mensagem lançada antes de haver ecrã espera por ele', (
    tester,
  ) async {
    mostrarMensagem('Esse link já não serve.');

    // Só agora é que a interface existe — como no arranque a frio.
    await tester.pumpWidget(
      MaterialApp(scaffoldMessengerKey: messengerKey, home: const Scaffold()),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(find.text('Esse link já não serve.'), findsOneWidget);
  });

  testWidgets('com ecrã montado, aparece de imediato', (tester) async {
    await tester.pumpWidget(
      MaterialApp(scaffoldMessengerKey: messengerKey, home: const Scaffold()),
    );

    mostrarMensagem('Gravado.');
    await tester.pump();

    expect(find.text('Gravado.'), findsOneWidget);
  });

  testWidgets('desiste ao fim das tentativas, sem ficar a tentar para sempre', (
    tester,
  ) async {
    mostrarMensagem('perdida', tentativas: 2);

    // Passa muito mais tempo do que as duas tentativas cobrem.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(
      MaterialApp(scaffoldMessengerKey: messengerKey, home: const Scaffold()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('perdida'), findsNothing);
  });
}
