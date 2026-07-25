import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:washinvoice_control/features/dashboard/dashboard_screen.dart';
import 'package:washinvoice_control/features/instalacoes/instalacoes_por_estado_screen.dart';
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

Licenca _lic(String id, String nome, DateTime validade) => Licenca(
      id: id,
      machineId: 'm$id',
      nif: '50000000$id',
      nome: nome,
      plano: 'anual',
      validade: validade,
      activa: true,
      criadoEm: DateTime(2026),
    );

class _FakeLicencas extends LicencasRepository {
  @override
  Future<List<Licenca>> listar({String? app}) async => [
        _lic('1', 'Loja Activa', DateTime(2030)),
        _lic('2', 'Loja Expirada', DateTime(2020)),
      ];
  @override
  Future<List<Licenca>> aExpirar({int dias = 15, String? app}) async => [];
  @override
  Future<Set<String>> machineIdsComLicenca({String? app}) async => {'m1', 'm2'};
}

class _FakePedidos extends PedidosRepository {
  @override
  Future<List<PedidoRenovacao>> pendentes({String? app}) async => [];
}

class _FakePedidosAjuda extends PedidosAjudaRepository {
  @override
  Future<List<PedidoAjuda>> listarAbertos({String? app}) async => [];
  @override
  Future<List<PedidoAjuda>> listarHistorico({String? app}) async => [];
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
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'WashInvoice Control',
      packageName: 'com.washcontrol.washinvoice_control',
      version: '1.5.0',
      buildNumber: '19',
      buildSignature: '',
    );
    timeago.setLocaleMessages('pt', timeago.PtBrMessages());
  });

  testWidgets('tocar no KPI "Activas" abre a lista só das activas',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        licencasRepoProvider.overrideWithValue(_FakeLicencas()),
        pedidosRepoProvider.overrideWithValue(_FakePedidos()),
        pedidosAjudaRepoProvider.overrideWithValue(_FakePedidosAjuda()),
        pingsRepoProvider.overrideWithValue(_FakePings()),
        clientesRepoProvider.overrideWithValue(_FakeClientes()),
        sugestoesRepoProvider.overrideWithValue(_FakeSugestoes()),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activas'));
    await tester.pumpAndSettle();

    // Navegou para a lista por estado.
    expect(find.byType(InstalacoesPorEstadoScreen), findsOneWidget);
    expect(find.text('Activas (1)'), findsOneWidget);
    expect(find.text('Loja Activa'), findsOneWidget);
    expect(find.text('Loja Expirada'), findsNothing);
  });
}
