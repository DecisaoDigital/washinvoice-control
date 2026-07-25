import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washinvoice_control/core/app_colors.dart';
import 'package:washinvoice_control/core/app_filter/app_filter_provider.dart';
import 'package:washinvoice_control/core/widgets/widgets.dart';
import 'package:washinvoice_control/models/licenca.dart';

Widget _envolver(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('WiAppBadge', () {
    testWidgets('pos → "POS" em azul', (tester) async {
      await tester.pumpWidget(_envolver(const WiAppBadge('pos')));
      expect(find.text('POS'), findsOneWidget);

      final texto = tester.widget<Text>(find.text('POS'));
      expect(texto.style?.color, AppColors.azul900);
    });

    testWidgets('punho → "PUNHO" em verde', (tester) async {
      await tester.pumpWidget(_envolver(const WiAppBadge('punho')));
      expect(find.text('PUNHO'), findsOneWidget);

      final texto = tester.widget<Text>(find.text('PUNHO'));
      expect(texto.style?.color, AppColors.verde900);
    });

    testWidgets('app desconhecida não rebenta — mostra o valor em maiúsculas',
        (tester) async {
      await tester.pumpWidget(_envolver(const WiAppBadge('lavandaria')));
      expect(find.text('LAVANDARIA'), findsOneWidget);
    });
  });

  group('WiAppBadgeAuto', () {
    testWidgets('com filtro em "todas" mostra o badge', (tester) async {
      await tester.pumpWidget(_envolver(const WiAppBadgeAuto('punho')));
      await tester.pumpAndSettle();
      expect(find.text('PUNHO'), findsOneWidget);
    });

    testWidgets('com o filtro fixo numa app esconde-se (seria redundante)',
        (tester) async {
      SharedPreferences.setMockInitialValues({kPrefFiltroApp: 'punho'});
      await tester.pumpWidget(_envolver(const WiAppBadgeAuto('punho')));
      await tester.pumpAndSettle();
      expect(find.text('PUNHO'), findsNothing);
    });
  });

  group('WiTierBadge (#177)', () {
    testWidgets('tier pro → badge PRO azul', (tester) async {
      await tester.pumpWidget(_envolver(const WiTierBadge(Tier.pro)));
      expect(find.text('PRO'), findsOneWidget);

      final texto = tester.widget<Text>(find.text('PRO'));
      expect(texto.style?.color, AppColors.azul900);
      // Letras mais reduzidas que o nome do cliente (bodyStrong ≈ 15).
      expect(texto.style?.fontSize, lessThan(15));
    });

    testWidgets('tier base → sem badge', (tester) async {
      await tester.pumpWidget(_envolver(const WiTierBadge(Tier.base)));
      expect(find.text('PRO'), findsNothing);
    });

    testWidgets('tier legado → COM badge (comporta-se como pro)',
        (tester) async {
      // Regra do modelo: não se retiram funcionalidades a quem já as tinha.
      // Esconder o badge mostraria como Base quem tem os extras todos.
      await tester.pumpWidget(_envolver(const WiTierBadge(Tier.legado)));
      expect(find.text('PRO'), findsOneWidget);
    });
  });

  group('WiAppSelector', () {
    testWidgets('mostra a etiqueta curta e escolher uma app grava o filtro',
        (tester) async {
      late WidgetRef refCapturada;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(builder: (_, ref, __) {
              refCapturada = ref;
              return const Scaffold(
                appBar: null,
                body: Center(child: WiAppSelector()),
              );
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Todas'), findsOneWidget);

      await tester.tap(find.byType(WiAppSelector));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Punho').last);
      await tester.pumpAndSettle();

      expect(refCapturada.read(appFilterProvider), AppFiltro.punho);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kPrefFiltroApp), 'punho');
    });
  });
}
