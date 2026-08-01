import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:washinvoice_control/features/auth/login_screen.dart';

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'WashInvoice Control',
      packageName: 'com.washcontrol.washinvoice_control',
      version: '1.8.0',
      buildNumber: '25',
      buildSignature: '',
    );
  });

  // O ecrã de login rola, e na viewport de teste (800x600) o "Criar conta"
  // fica em y=637 — 37 px abaixo da margem. Sem o trazer ao ecrã, o toque não
  // acontece (fica só um aviso), o ecrã nunca passa a modo de registo e os
  // testes seguintes falham a dizer que faltam campos que nunca chegaram a ser
  // pedidos. Mesmo cuidado que o `tocarPedirAcesso` abaixo.
  Future<void> abrirCriarConta(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();
    await tester.ensureVisible(find.text('Criar conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
  }

  // Com os campos de registo visíveis o botão cai fora da viewport de teste
  // (800x600): é preciso trazê-lo para o ecrã antes de tocar.
  Future<void> tocarPedirAcesso(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Pedir acesso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedir acesso'));
    await tester.pumpAndSettle();
  }

  testWidgets('Criar conta pede nome, organização, cargo e código de convite',
      (tester) async {
    await abrirCriarConta(tester);

    // Email, palavra-passe, nome, organização e código de convite.
    expect(tester.widgetList<TextField>(find.byType(TextField)).length, 5);
    expect(find.text('NOME'), findsOneWidget);
    expect(find.text('ORGANIZAÇÃO'), findsOneWidget);
    expect(find.text('CÓDIGO DE CONVITE (OPCIONAL)'), findsOneWidget);

    // Cargo pretendido: Administrador ou Funcionário.
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('Registo valida os campos antes de chamar o Supabase',
      (tester) async {
    await abrirCriarConta(tester);

    // Sem nada preenchido: a validação local trava o pedido. Se o signUp
    // chegasse a ser chamado, rebentaria (Supabase não está inicializado
    // nos testes) — o teste falhar aqui significa que a validação caiu.
    await tocarPedirAcesso(tester);

    expect(find.textContaining('pelo menos 6 caracteres'), findsOneWidget);
  });

  testWidgets('Palavra-passe curta é recusada localmente', (tester) async {
    await abrirCriarConta(tester);

    // Ordem no modo "Criar conta": email, nome, organização, convite, password.
    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'ana@exemplo.pt');
    await tester.enterText(campos.at(1), 'Ana Silva');
    await tester.enterText(campos.at(2), 'Lavandaria Central');
    await tester.enterText(campos.at(4), '123');
    await tester.pump();

    await tocarPedirAcesso(tester);

    expect(find.textContaining('pelo menos 6 caracteres'), findsOneWidget);
  });
}
