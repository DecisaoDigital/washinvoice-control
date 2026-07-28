import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:washinvoice_control/core/widgets/wi_app_selector.dart';
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

class _FakeLicencas extends LicencasRepository {
  @override
  Future<List<Licenca>> listar({String? app}) async => [];
  @override
  Future<List<Licenca>> aExpirar({int dias = 15, String? app}) async => [];
  @override
  Future<Set<String>> machineIdsComLicenca({String? app}) async => {};
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

Widget _app() => ProviderScope(
      overrides: [
        licencasRepoProvider.overrideWithValue(_FakeLicencas()),
        pedidosRepoProvider.overrideWithValue(_FakePedidos()),
        pedidosAjudaRepoProvider.overrideWithValue(_FakePedidosAjuda()),
        pingsRepoProvider.overrideWithValue(_FakePings()),
        clientesRepoProvider.overrideWithValue(_FakeClientes()),
        sugestoesRepoProvider.overrideWithValue(_FakeSugestoes()),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    );

/// Fixa o tamanho real da superfície de teste (e não só o MediaQuery): assim
/// as constraints de layout são mesmo as do dispositivo e um overflow seria
/// apanhado, em vez de escondido pelos 800x600 por omissão.
void _ecra(WidgetTester tester, Size tamanho) {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
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

  testWidgets('telemóvel em retrato (411 dp): só o logo, ícones à direita e '
      'sem sobreposição', (tester) async {
    _ecra(tester, const Size(411, 900));

    await tester.pumpWidget(_app());
    // Nenhum RenderFlex overflow nem outra excepção de layout.
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // O logo fica; o wordmark por extenso desaparece nesta largura.
    expect(find.byIcon(Icons.local_laundry_service), findsOneWidget);
    expect(find.text('WashInvoice'), findsNothing);
    expect(find.text('CONTROL'), findsNothing);

    // Os quatro ícones continuam todos visíveis — nada foi escondido atrás de
    // um menu "...".
    for (final icone in [
      Icons.search,
      Icons.refresh,
      Icons.info_outline,
      Icons.logout,
    ]) {
      expect(find.byIcon(icone), findsOneWidget, reason: 'falta $icone');
    }

    // A lupa é o primeiro dos quatro: tem de estar já na metade direita, e não
    // encostada ao centro por o título ter comido o espaço.
    final lupa = tester.getRect(find.byIcon(Icons.search));
    expect(lupa.left, greaterThan(411 / 2));

    // O selector de app não se sobrepõe ao título.
    final logo = tester.getRect(find.byIcon(Icons.local_laundry_service));
    final selector = tester.getRect(find.byType(WiAppSelector));
    expect(selector.left, greaterThanOrEqualTo(logo.right));
  });

  testWidgets('tablet (768 dp): wordmark completo', (tester) async {
    _ecra(tester, const Size(768, 1024));

    await tester.pumpWidget(_app());
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byIcon(Icons.local_laundry_service), findsOneWidget);
    expect(find.text('WashInvoice'), findsOneWidget);
    expect(find.text('CONTROL'), findsOneWidget);

    for (final icone in [
      Icons.search,
      Icons.refresh,
      Icons.info_outline,
      Icons.logout,
    ]) {
      expect(find.byIcon(icone), findsOneWidget, reason: 'falta $icone');
    }
  });
}
