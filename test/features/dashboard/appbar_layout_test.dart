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
      appName: 'Control',
      packageName: 'com.washcontrol.washinvoice_control',
      version: '1.8.0',
      buildNumber: '25',
      buildSignature: '',
    );
    timeago.setLocaleMessages('pt', timeago.PtBrMessages());
  });

  /// A AppBar já não muda de forma com a largura — a linha 1 (marca) tem
  /// sempre o mesmo conteúdo, ao contrário do wordmark antigo que desaparecia
  /// abaixo dos 600 dp. Corre o mesmo teste em telemóvel estreito e em tablet
  /// para confirmar que não há regressão de layout em nenhum dos extremos.
  for (final caso in [('telemóvel estreito (360 dp)', 360.0), ('tablet (768 dp)', 768.0)]) {
    testWidgets(
      '${caso.$1}: linha 1 = ícone + CONTROL, linha 2 = selector e ícones, sem sobreposição',
      (tester) async {
        _ecra(tester, Size(caso.$2, 900));

        await tester.pumpWidget(_app());
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Linha 1: marca sempre por extenso, "i" deixou de ser um ícone à
        // parte — é a linha toda.
        expect(find.byIcon(Icons.local_laundry_service), findsOneWidget);
        expect(find.text('CONTROL'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsNothing);
        expect(find.byIcon(Icons.logout), findsNothing);

        // Linha 2: selector à esquerda, pesquisa e recarregar à direita.
        expect(find.byType(WiAppSelector), findsOneWidget);
        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        final logo = tester.getRect(find.byIcon(Icons.local_laundry_service));
        final selector = tester.getRect(find.byType(WiAppSelector));
        final lupa = tester.getRect(find.byIcon(Icons.search));

        // O selector fica na segunda linha, abaixo da marca — não ao lado.
        expect(selector.top, greaterThanOrEqualTo(logo.bottom));
        // A lupa fica à direita do selector, na mesma linha.
        expect(lupa.left, greaterThan(selector.right));
      },
    );
  }

  testWidgets('linha 1 é um InkWell tocável (abre o ecrã Sobre)',
      (tester) async {
    // Não navega de facto: SobreScreen acede a Supabase.instance
    // directamente no build (sobre_screen.dart:170), sem proteção para
    // ambiente de teste — pré-existente, alheio a esta alteração. Este
    // teste só tranca que a linha 1 continua a ser um alvo de toque válido,
    // sem chegar a montar o ecrã de destino.
    _ecra(tester, const Size(411, 900));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final area = find.ancestor(
      of: find.text('CONTROL'),
      matching: find.byType(InkWell),
    );
    expect(area, findsOneWidget);
    final inkWell = tester.widget<InkWell>(area);
    expect(inkWell.onTap, isNotNull);
  });
}
