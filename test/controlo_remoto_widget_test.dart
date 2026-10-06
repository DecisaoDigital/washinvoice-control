import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/instalacoes/controlo_remoto_widgets.dart';
import 'package:washinvoice_control/models/licenca.dart';

/// Fase 4 — cards de controlo remoto e de preferências read-only.

Licenca _licenca({
  bool activa = true,
  Tier tier = Tier.pro,
  Map<String, bool> prefs = const {},
  String plano = 'anual',
  String app = 'pos',
}) =>
    Licenca(
      id: 'lic-1',
      app: app,
      machineId: 'abc123',
      nif: '500000001',
      nome: 'Lavandaria Sol',
      plano: plano,
      validade: DateTime(2026, 12, 31),
      activa: activa,
      criadoEm: DateTime(2026, 1, 1),
      tier: tier,
      preferenciasFeatures: prefs,
    );

Future<void> _montarControlo(
  WidgetTester tester,
  Licenca l, {
  bool ocupado = false,
  void Function(int)? onDarDias,
  VoidCallback? onSuspender,
  VoidCallback? onReactivar,
  VoidCallback? onCancelar,
  void Function(Tier)? onMudarTier,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: CardControloRemoto(
          licenca: l,
          ocupado: ocupado,
          onDarDias: onDarDias ?? (_) {},
          onSuspender: onSuspender ?? () {},
          onReactivar: onReactivar ?? () {},
          onCancelar: onCancelar ?? () {},
          onMudarTier: onMudarTier ?? (_) {},
          onVerHistorial: () {},
        ),
      ),
    ),
  ));
  // Com `ocupado` há um LinearProgressIndicator a animar em ciclo: o
  // `pumpAndSettle` nunca estabilizaria.
  if (ocupado) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  group('CardControloRemoto', () {
    testWidgets('numa licença paga os botões somam, e dizem-no', (tester) async {
      await _montarControlo(tester, _licenca());
      expect(find.text('+5 dias'), findsOneWidget);
      expect(find.text('+15 dias'), findsOneWidget);
      expect(find.text('+30 dias'), findsOneWidget);
    });

    testWidgets('num trial do Fist os botões perdem o sinal de mais',
        (tester) async {
      // O `+` prometia uma soma. Ali não há soma nenhuma: o número é a janela
      // toda, a contar de hoje — regra do César, 5/8/2026.
      await _montarControlo(
          tester, _licenca(plano: 'trial', app: 'punho'));

      expect(find.text('5 dias'), findsOneWidget);
      expect(find.text('30 dias'), findsOneWidget);
      expect(find.text('+5 dias'), findsNothing);
    });

    testWidgets('um trial do POS continua com o +', (tester) async {
      // «só para o punho, não quero mexer no pos» — 5/8/2026. O POS tem
      // trials auto-criados na mesma, e neles somar continua a ser o certo.
      await _montarControlo(tester, _licenca(plano: 'trial', app: 'pos'));

      expect(find.text('+5 dias'), findsOneWidget);
      expect(find.text('5 dias'), findsNothing);
    });

    testWidgets('cada botão dispara a acção com os dias certos',
        (tester) async {
      final chamadas = <int>[];
      await _montarControlo(tester, _licenca(),
          onDarDias: chamadas.add);

      await tester.tap(find.text('+15 dias'));
      await tester.pump();
      expect(chamadas, [15]);
    });

    testWidgets('licença activa mostra Suspender, não Reactivar',
        (tester) async {
      await _montarControlo(tester, _licenca(activa: true));
      expect(find.text('Suspender'), findsOneWidget);
      expect(find.text('Reactivar'), findsNothing);
    });

    testWidgets('licença suspensa mostra Reactivar, não Suspender',
        (tester) async {
      await _montarControlo(tester, _licenca(activa: false));
      expect(find.text('Reactivar'), findsOneWidget);
      expect(find.text('Suspender'), findsNothing);
    });

    testWidgets('ocupado trava todos os botões de acção', (tester) async {
      final chamadas = <int>[];
      await _montarControlo(tester, _licenca(),
          ocupado: true, onDarDias: chamadas.add);

      await tester.tap(find.text('+5 dias'));
      await tester.pump();
      expect(chamadas, isEmpty,
          reason: 'duplo-clique não pode prolongar duas vezes');
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('Pro oferece descer para Base', (tester) async {
      final mudancas = <Tier>[];
      await _montarControlo(tester, _licenca(tier: Tier.pro),
          onMudarTier: mudancas.add);

      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('Mudar para Base'), findsOneWidget);

      await tester.tap(find.text('Mudar para Base'));
      await tester.pump();
      expect(mudancas, [Tier.base]);
    });

    testWidgets('Base oferece subir para Pro', (tester) async {
      final mudancas = <Tier>[];
      await _montarControlo(tester, _licenca(tier: Tier.base),
          onMudarTier: mudancas.add);

      expect(find.text('Base'), findsOneWidget);
      expect(find.text('Mudar para Pro'), findsOneWidget);

      await tester.tap(find.text('Mudar para Pro'));
      await tester.pump();
      expect(mudancas, [Tier.pro]);
    });

    testWidgets('Legado oferece subir para Pro (não fica sem botão)',
        (tester) async {
      await _montarControlo(tester, _licenca(tier: Tier.legado));
      expect(find.text('Legado'), findsOneWidget);
      expect(find.text('Mudar para Pro'), findsOneWidget);
    });
  });

  group('CardPreferencias (read-only)', () {
    Future<void> montar(WidgetTester tester, Licenca l) async {
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: CardPreferencias(licenca: l))));
      await tester.pumpAndSettle();
    }

    testWidgets('lista as três features', (tester) async {
      await montar(tester, _licenca());
      expect(find.text('Guias de Transporte'), findsOneWidget);
      expect(find.text('Gestão'), findsOneWidget);
      expect(find.text('Gráficos'), findsOneWidget);
    });

    testWidgets('Pro com JSONB vazio → todas ligadas', (tester) async {
      await montar(tester, _licenca(tier: Tier.pro, prefs: const {}));
      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
    });

    testWidgets('Pro respeita a preferência desligada', (tester) async {
      await montar(
          tester, _licenca(tier: Tier.pro, prefs: const {'guias': false}));
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    });

    testWidgets('Base → todas escondidas, mesmo com preferências a true',
        (tester) async {
      await montar(
          tester,
          _licenca(tier: Tier.base, prefs: const {
            'guias': true,
            'gestao': true,
            'graficos': true,
          }));
      expect(find.byIcon(Icons.remove_circle_outline), findsNWidgets(3));
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('Base explica porquê', (tester) async {
      await montar(tester, _licenca(tier: Tier.base));
      expect(find.textContaining('plano Base'), findsOneWidget);
    });

    testWidgets('Pro remete para o admin do POS', (tester) async {
      await montar(tester, _licenca(tier: Tier.pro));
      expect(find.textContaining('contacta o cliente'), findsOneWidget);
    });
  });

  group('Licenca.featureVisivel', () {
    test('tier dá o direito, preferência só desliga', () {
      final pro = _licenca(tier: Tier.pro, prefs: const {'guias': false});
      expect(pro.featureVisivel('guias'), isFalse);
      expect(pro.featureVisivel('gestao'), isTrue, reason: 'ausente = ligada');

      final base = _licenca(tier: Tier.base, prefs: const {'guias': true});
      expect(base.featureVisivel('guias'), isFalse,
          reason: 'Base não desbloqueia por preferência forjada');

      final legado = _licenca(tier: Tier.legado, prefs: const {});
      expect(legado.featureVisivel('guias'), isTrue,
          reason: 'legado comporta-se como Pro');
    });
  });

  group('Tier', () {
    test('parse tolera nulos e desconhecidos', () {
      expect(TierInfo.parse('base'), Tier.base);
      expect(TierInfo.parse('PRO'), Tier.pro);
      expect(TierInfo.parse(null), Tier.legado);
      expect(TierInfo.parse('mensal'), Tier.legado);
    });

    test('temExtras', () {
      expect(Tier.base.temExtras, isFalse);
      expect(Tier.pro.temExtras, isTrue);
      expect(Tier.legado.temExtras, isTrue);
    });
  });
}
