import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washinvoice_control/core/app_filter/app_filter_provider.dart';
import 'package:washinvoice_control/core/widgets/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppFiltro (semântica)', () {
    test('valorApp: todas não filtra; pos/punho dão o valor da coluna', () {
      expect(AppFiltro.todas.valorApp, isNull);
      expect(AppFiltro.pos.valorApp, 'pos');
      expect(AppFiltro.punho.valorApp, 'punho');
    });

    test('etiqueta usa o nome comercial da app', () {
      expect(AppFiltro.todas.etiqueta, 'Todas as apps');
      expect(AppFiltro.pos.etiqueta, 'WashInvoice');
      expect(AppFiltro.punho.etiqueta, 'Fist');
    });

    test('aceita: "todas" deixa passar tudo, as outras só a própria app', () {
      expect(AppFiltro.todas.aceita('pos'), isTrue);
      expect(AppFiltro.todas.aceita('punho'), isTrue);
      expect(AppFiltro.pos.aceita('pos'), isTrue);
      expect(AppFiltro.pos.aceita('punho'), isFalse);
      expect(AppFiltro.punho.aceita('pos'), isFalse);
    });
  });

  group('appFilterProvider (só em memória)', () {
    test('arranca sempre em "todas", mesmo com preferência antiga guardada',
        () async {
      // Versões anteriores guardavam o filtro entre arranques.
      SharedPreferences.setMockInitialValues({'app_filtro': 'punho'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appFilterProvider), AppFiltro.todas);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appFilterProvider), AppFiltro.todas);
    });

    test('definir muda o estado enquanto a app está aberta, sem gravar nada',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(appFilterProvider.notifier).definir(AppFiltro.pos);
      expect(container.read(appFilterProvider), AppFiltro.pos);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_filtro'), isNull);
    });

    test('um novo arranque (novo container) volta a "todas"', () async {
      final a = ProviderContainer();
      await a.read(appFilterProvider.notifier).definir(AppFiltro.punho);
      a.dispose();

      final b = ProviderContainer();
      addTearDown(b.dispose);
      expect(b.read(appFilterProvider), AppFiltro.todas);
    });
  });

  group('WiPastilhaFiltroApp', () {
    testWidgets('«Todas»: não aparece', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: WiPastilhaFiltroApp())),
        ),
      );
      expect(find.textContaining('a ver só'), findsNothing);
    });

    testWidgets('filtrado: mostra «a ver só: Fist» e tocar volta a «Todas»',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(appFilterProvider.notifier).definir(AppFiltro.punho);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: WiPastilhaFiltroApp()),
          ),
        ),
      );
      expect(find.text('a ver só: Fist'), findsOneWidget);
      expect(
        tester.getSize(find.byType(InkWell).first).height,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(find.text('a ver só: Fist'));
      await tester.pump();
      expect(container.read(appFilterProvider), AppFiltro.todas);
      expect(find.textContaining('a ver só'), findsNothing);
    });
  });
}
