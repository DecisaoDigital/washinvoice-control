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
    testWidgets('pos → "WASHINVOICE" em azul', (tester) async {
      await tester.pumpWidget(_envolver(const WiAppBadge('pos')));
      expect(find.text('WASHINVOICE'), findsOneWidget);

      final texto = tester.widget<Text>(find.text('WASHINVOICE'));
      expect(texto.style?.color, AppColors.azul900);
    });

    testWidgets('punho → "FIST" em verde', (tester) async {
      await tester.pumpWidget(_envolver(const WiAppBadge('punho')));
      expect(find.text('FIST'), findsOneWidget);

      final texto = tester.widget<Text>(find.text('FIST'));
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
      expect(find.text('FIST'), findsOneWidget);
    });

    testWidgets('com o filtro fixo numa app esconde-se (seria redundante)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appFilterProvider.overrideWith(
              (_) => AppFilterNotifier(AppFiltro.punho),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: WiAppBadgeAuto('punho')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('FIST'), findsNothing);
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
      await tester.tap(find.text('Fist').last);
      await tester.pumpAndSettle();

      expect(refCapturada.read(appFilterProvider), AppFiltro.punho);
    });

    testWidgets('a pastilha inteira abre a cascata, não só a seta',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: Center(child: WiAppSelector())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pastilha = tester.getRect(find.byType(WiAppSelector));
      // Regra de alvo de toque do Material.
      expect(pastilha.width, greaterThanOrEqualTo(48));
      expect(pastilha.height, greaterThanOrEqualTo(48));

      // Toque no ícone da app, na ponta esquerda da pastilha — longe da seta.
      await tester.tapAt(Offset(pastilha.left + 6, pastilha.center.dy));
      await tester.pumpAndSettle();

      // Cascata aberta: as etiquetas longas de todas as opções estão no ecrã.
      expect(find.text('Fist').last, findsOneWidget);
    });
  });
}
