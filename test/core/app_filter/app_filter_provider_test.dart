import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:washinvoice_control/core/app_filter/app_filter_provider.dart';

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

  group('appFilterProvider (persistência)', () {
    test('sem preferência guardada arranca em "todas"', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(appFilterProvider.notifier).carregado;
      expect(container.read(appFilterProvider), AppFiltro.todas);
    });

    test('lê a preferência guardada no arranque', () async {
      SharedPreferences.setMockInitialValues({kPrefFiltroApp: 'punho'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(appFilterProvider.notifier).carregado;
      expect(container.read(appFilterProvider), AppFiltro.punho);
    });

    test('definir muda o estado e escreve em SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(appFilterProvider.notifier).carregado;
      await container.read(appFilterProvider.notifier).definir(AppFiltro.pos);

      expect(container.read(appFilterProvider), AppFiltro.pos);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kPrefFiltroApp), 'pos');
    });

    test('valor guardado inválido não rebenta — cai em "todas"', () async {
      // Defesa contra uma app removida do enum depois de alguém a ter escolhido.
      SharedPreferences.setMockInitialValues({kPrefFiltroApp: 'app_extinta'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(appFilterProvider.notifier).carregado;
      expect(container.read(appFilterProvider), AppFiltro.todas);
    });
  });
}
