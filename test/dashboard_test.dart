import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
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
  final List<PedidoAjuda> abertos;
  _FakePedidosAjuda(this.abertos);
  @override
  Future<List<PedidoAjuda>> listarAbertos({String? app}) async => abertos;
}

class _FakePings extends PingsRepository {
  final List<Ping> ultimos;
  _FakePings(this.ultimos);
  @override
  Future<List<Ping>> ultimosPorInstalacao({String? app}) async => ultimos;
}

class _FakeClientes extends ClientesRepository {
  @override
  Future<List<Cliente>> listar() async => [];
}

class _FakeSugestoes extends SugestoesRepository {
  @override
  Future<List<Sugestao>> listarPorLer({String? app}) async => [];
}

Widget _app({
  List<PedidoAjuda> pedidosAjuda = const [],
  List<Ping> pings = const [],
}) {
  return ProviderScope(
    overrides: [
      licencasRepoProvider.overrideWithValue(_FakeLicencas()),
      pedidosRepoProvider.overrideWithValue(_FakePedidos()),
      pedidosAjudaRepoProvider.overrideWithValue(_FakePedidosAjuda(pedidosAjuda)),
      pingsRepoProvider.overrideWithValue(_FakePings(pings)),
      clientesRepoProvider.overrideWithValue(_FakeClientes()),
      sugestoesRepoProvider.overrideWithValue(_FakeSugestoes()),
    ],
    child: const MaterialApp(home: DashboardScreen()),
  );
}

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'Control',
      packageName: 'com.washcontrol.washinvoice_control',
      version: '1.4.1',
      buildNumber: '15',
      buildSignature: '',
    );
    timeago.setLocaleMessages('pt', timeago.PtBrMessages());
  });

  testWidgets('Dashboard vazio: KPIs + "Actividade recente" vazia + rodapé, '
      'sem altura infinita', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // KPIs presentes (o bug do stretch infinito partia isto).
    expect(find.text('Activas'), findsOneWidget);
    expect(find.text('A expirar'), findsOneWidget);
    expect(find.text('Expiradas'), findsOneWidget);
    expect(find.text('Pendentes'), findsOneWidget);

    // "Actividade recente" aparece SEMPRE, com estado vazio.
    expect(find.text('Actividade recente'), findsOneWidget);
    expect(find.text('Sem actividade recente.'), findsOneWidget);

    // Rodapé com versão.
    expect(find.textContaining('v1.4.1'), findsOneWidget);

    // A altura do conteúdo do ListView é finita e razoável (o bug dava altura
    // gigantesca). Confirma que não há constraint infinita.
    final viewport = tester.getSize(find.byType(Scrollable).first);
    expect(viewport.height, lessThan(2000));
  });

  testWidgets('Dashboard com nova instalação: secção "Início de actividade (1)"',
      (tester) async {
    final ping = Ping(
      id: 'p1',
      machineId: 'maq-sem-licenca',
      nif: '512345678',
      versao: '1.4.1',
      cidade: 'Setúbal',
      criadoEm: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    await tester.pumpWidget(_app(pings: [ping]));
    await tester.pumpAndSettle();

    expect(find.text('Início de actividade (1)'), findsOneWidget);
    // "Actividade recente" continua presente.
    expect(find.text('Actividade recente'), findsOneWidget);
  });

  testWidgets('Início de actividade sem NIF mostra "Sem NIF ainda" (não "NIF —")',
      (tester) async {
    final ping = Ping(
      id: 'p2',
      machineId: 'maq-sem-nif',
      versao: '1.4.2',
      cidade: 'Lisbon',
      criadoEm: DateTime.now().subtract(const Duration(minutes: 2)),
    );
    await tester.pumpWidget(_app(pings: [ping]));
    await tester.pumpAndSettle();

    // O mesmo terminal aparece em "Início de actividade" e "Actividade recente",
    // com a MESMA etiqueta (via ctx.nomeDe) — não "NIF —" nem dois nomes diferentes.
    expect(find.text('Sem NIF ainda'), findsNWidgets(2));
    expect(find.textContaining('NIF —'), findsNothing);
    expect(find.text('Terminal sem identificação'), findsNothing);
    // Cidade traduzida no card (Lisbon → Lisboa).
    expect(find.textContaining('Lisboa'), findsWidgets);
  });

  testWidgets('Dashboard com pedido de ajuda: secção "Pedidos de ajuda (1)"',
      (tester) async {
    final pedido = PedidoAjuda(
      id: 'a1',
      machineId: 'maq-1',
      nif: '512345678',
      criadoEm: DateTime.now().subtract(const Duration(minutes: 3)),
    );
    await tester.pumpWidget(_app(pedidosAjuda: [pedido]));
    await tester.pumpAndSettle();

    expect(find.text('Pedidos de ajuda (1)'), findsOneWidget);
  });
}
