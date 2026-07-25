import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:washinvoice_control/core/app_filter/app_filter_provider.dart';
import 'package:washinvoice_control/features/dashboard/dashboard_screen.dart';
import 'package:washinvoice_control/models/cliente.dart';
import 'package:washinvoice_control/models/licenca.dart';
import 'package:washinvoice_control/models/pedido_ajuda.dart';
import 'package:washinvoice_control/models/pedido_renovacao.dart';
import 'package:washinvoice_control/models/ping.dart';
import 'package:washinvoice_control/models/sugestao.dart';
import 'package:washinvoice_control/repositories/clientes_repository.dart';
import 'package:washinvoice_control/repositories/licencas_repository.dart';
import 'package:washinvoice_control/repositories/pedidos_ajuda_repository.dart';
import 'package:washinvoice_control/repositories/pedidos_repository.dart';
import 'package:washinvoice_control/repositories/pings_repository.dart';
import 'package:washinvoice_control/repositories/providers.dart';
import 'package:washinvoice_control/repositories/sugestoes_repository.dart';

Licenca _licenca(String id, String app, {Tier tier = Tier.base}) => Licenca(
      id: id,
      app: app,
      machineId: 'maq-$id',
      nif: '5$id',
      nome: 'Cliente $id',
      plano: 'anual',
      validade: DateTime.now().add(const Duration(days: 300)),
      activa: true,
      criadoEm: DateTime.now(),
      tier: tier,
    );

/// Repositório que responde ao filtro como o Supabase responderia (e regista
/// que valor de `app` recebeu, para se verificar que o ecrã o passa mesmo).
class _FakeLicencas extends LicencasRepository {
  final List<Licenca> todas;
  final List<String?> appsPedidas = [];
  _FakeLicencas(this.todas);

  @override
  Future<List<Licenca>> listar({String? app}) async {
    appsPedidas.add(app);
    return todas.where((l) => app == null || l.app == app).toList();
  }

  @override
  Future<List<Licenca>> aExpirar({int dias = 15, String? app}) async => [];

  @override
  Future<Set<String>> machineIdsComLicenca({String? app}) async =>
      todas.where((l) => app == null || l.app == app).map((l) => l.machineId).toSet();
}

class _FakePedidos extends PedidosRepository {
  @override
  Future<List<PedidoRenovacao>> pendentes({String? app}) async => [];
}

class _FakePedidosAjuda extends PedidosAjudaRepository {
  @override
  Future<List<PedidoAjuda>> listarAbertos({String? app}) async => [];
}

class _FakePings extends PingsRepository {
  @override
  Future<List<Ping>> ultimosPorInstalacao({String? app}) async => [];
}

class _FakeClientes extends ClientesRepository {
  @override
  Future<List<Cliente>> listar() async => [];
}

class _FakeSugestoes extends SugestoesRepository {
  @override
  Future<List<Sugestao>> listarPorLer({String? app}) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'WashInvoice Control',
      packageName: 'com.washcontrol.washinvoice_control',
      version: '1.8.0',
      buildNumber: '25',
      buildSignature: '',
    );
    timeago.setLocaleMessages('pt', timeago.PtBrMessages());
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(_FakeLicencas, ProviderContainer)> montar(
    WidgetTester tester,
    List<Licenca> licencas,
  ) async {
    final fake = _FakeLicencas(licencas);
    final container = ProviderContainer(overrides: [
      licencasRepoProvider.overrideWithValue(fake),
      pedidosRepoProvider.overrideWithValue(_FakePedidos()),
      pedidosAjudaRepoProvider.overrideWithValue(_FakePedidosAjuda()),
      pingsRepoProvider.overrideWithValue(_FakePings()),
      clientesRepoProvider.overrideWithValue(_FakeClientes()),
      sugestoesRepoProvider.overrideWithValue(_FakeSugestoes()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pumpAndSettle();
    return (fake, container);
  }

  testWidgets('filtro "todas": lista as duas apps e mostra o breakdown',
      (tester) async {
    final (fake, _) = await montar(tester, [
      _licenca('1', 'pos'),
      _licenca('2', 'pos'),
      _licenca('3', 'punho'),
    ]);

    // Sem filtro, o repositório é chamado sem `app`.
    expect(fake.appsPedidas.last, isNull);

    // Breakdown por app aparece só quando há mais do que uma app.
    expect(find.text('WashInvoice: 2'), findsOneWidget);
    expect(find.text('Punho: 1'), findsOneWidget);

    // O selector mostra o estado actual.
    expect(find.text('Todas'), findsOneWidget);
  });

  testWidgets('mudar o filtro para Punho recarrega e passa app=punho',
      (tester) async {
    final (fake, container) = await montar(tester, [
      _licenca('1', 'pos'),
      _licenca('3', 'punho'),
    ]);
    expect(fake.appsPedidas.last, isNull);

    await container.read(appFilterProvider.notifier).definir(AppFiltro.punho);
    await tester.pumpAndSettle();

    // O ecrã reagiu à mudança e voltou a pedir, agora só a app escolhida.
    expect(fake.appsPedidas.last, 'punho');

    // Com uma só app o breakdown desaparece — os KPIs já são dessa app.
    expect(find.text('Punho: 1'), findsNothing);
    expect(find.text('Punho'), findsOneWidget); // etiqueta curta do selector
  });

  testWidgets('breakdown não aparece quando só há uma app', (tester) async {
    await montar(tester, [_licenca('1', 'pos'), _licenca('2', 'pos')]);
    expect(find.textContaining('WashInvoice:'), findsNothing);
  });
}
