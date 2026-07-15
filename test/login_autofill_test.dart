import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:washinvoice_control/features/auth/login_screen.dart';

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'WashInvoice Control',
      packageName: 'com.washcontrol.washinvoice_control',
      version: '1.4.1',
      buildNumber: '15',
      buildSignature: '',
    );
  });

  testWidgets('Login: campos têm autofillHints e estão num AutofillGroup',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();

    expect(find.byType(AutofillGroup), findsOneWidget);

    final campos = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(campos.length, 2);

    // Email: username + email.
    expect(campos[0].autofillHints,
        containsAll(<String>[AutofillHints.username, AutofillHints.email]));
    // Palavra-passe: password.
    expect(campos[1].autofillHints, contains(AutofillHints.password));
    expect(campos[1].obscureText, isTrue);
  });
}
