import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:washinvoice_control/core/erros.dart';
import 'package:washinvoice_control/features/agora/agora_screen.dart';
import 'package:washinvoice_control/features/instalacoes/renovar_licenca.dart';
import 'package:washinvoice_control/repositories/providers.dart';
import 'package:washinvoice_control/services/licenca/gerir_licenca_service.dart';

import '../agora/agora_helpers.dart';

void main() {
  setUpAll(() => timeago.setLocaleMessages('pt', timeago.PtBrMessages()));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final hoje = DateTime(2026, 10, 8, 15);

  group('validadeRenovada', () {
    test('expirada: conta de HOJE, não da validade antiga', () {
      final l = licencaTeste('1', validade: DateTime(2026, 6, 1));
      expect(validadeRenovada(l, OpcaoRenovacao.dias30, hoje: hoje),
          DateTime(2026, 11, 7));
      expect(validadeRenovada(l, OpcaoRenovacao.meses3, hoje: hoje),
          DateTime(2027, 1, 8));
      expect(validadeRenovada(l, OpcaoRenovacao.ano1, hoje: hoje),
          DateTime(2027, 10, 8));
    });

    test('a expirar: soma à validade actual', () {
      final l = licencaTeste('1', validade: DateTime(2026, 10, 12, 20));
      expect(validadeRenovada(l, OpcaoRenovacao.dias30, hoje: hoje),
          DateTime(2026, 11, 11));
    });
  });

  testWidgets('Renovar no cartão: sheet, definir_validade, Anular repõe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final corpos = <Map<String, dynamic>>[];
    final servico = GerirLicencaService.comInvocador((b) async {
      corpos.add(b);
      return {
        'ok': true,
        'licenca_actualizada': {
          'activa': true,
          'validade': (b['parametros'] as Map)['validade'],
          'tier': 'pro',
          'plano': 'anual',
        },
      };
    });
    final expirou = DateTime.now().subtract(const Duration(days: 60));
    final container = ProviderContainer(
      overrides: [
        ...overridesAgora(licencas: [licencaTeste('1', validade: expirou)]),
        gerirLicencaProvider.overrideWithValue(servico),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          scaffoldMessengerKey: messengerKey,
          home: const AgoraScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Renovar'));
    await tester.pumpAndSettle();
    for (final t in ['+30 dias', '+3 meses', '+1 ano', 'Outra data']) {
      expect(find.text(t), findsOneWidget);
    }

    await tester.tap(find.text('+30 dias'));
    await tester.pumpAndSettle();
    expect(corpos, hasLength(1));
    expect(corpos[0]['acao'], 'definir_validade');
    expect(corpos[0]['machine_id'], 'mid-1');
    final n = DateTime.now();
    final esperado = DateTime(n.year, n.month, n.day + 30);
    expect(
      (corpos[0]['parametros'] as Map)['validade'],
      esperado.toIso8601String().substring(0, 10),
    );

    await tester.tap(find.text('Anular'));
    await tester.pumpAndSettle();
    expect(corpos, hasLength(2));
    expect(corpos[1]['acao'], 'definir_validade');
    expect(
      (corpos[1]['parametros'] as Map)['validade'],
      expirou.toIso8601String().substring(0, 10),
    );
  });
}
