import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/instalacoes/detalhe_cliente_screen.dart';
import 'package:washinvoice_control/models/aceite_termo.dart';
import 'package:washinvoice_control/models/cliente.dart';
import 'package:washinvoice_control/models/licenca.dart';
import 'package:washinvoice_control/models/pedido_renovacao.dart';
import 'package:washinvoice_control/models/ping.dart';
import 'package:washinvoice_control/repositories/aceites_repository.dart';
import 'package:washinvoice_control/repositories/clientes_repository.dart';
import 'package:washinvoice_control/repositories/licencas_repository.dart';
import 'package:washinvoice_control/repositories/pedidos_repository.dart';
import 'package:washinvoice_control/repositories/pings_repository.dart';
import 'package:washinvoice_control/repositories/providers.dart';

/// Tasks #95 e #96 — linha IP (do ping) e linha Telefone (do cliente) no
/// DetalheClienteScreen, cada uma só quando há dado.

class _FakeLicencasRepo extends LicencasRepository {
  final Licenca licenca;
  _FakeLicencasRepo(this.licenca);
  @override
  Future<Licenca?> porMachineId(String machineId) async => licenca;
  @override
  Future<List<Licenca>> listar() async => [licenca];
}

class _FakeClientesRepo extends ClientesRepository {
  final List<Cliente> clientes;
  _FakeClientesRepo(this.clientes);
  @override
  Future<List<Cliente>> listar() async => clientes;
}

class _FakePingsRepo extends PingsRepository {
  final Ping? ping;
  _FakePingsRepo(this.ping);
  @override
  Future<List<Ping>> historico(String machineId, {int limite = 20}) async =>
      ping == null ? [] : [ping!];
  @override
  Future<List<Ping>> ultimosPorInstalacao() async =>
      ping == null ? [] : [ping!];
}

class _FakePedidosRepo extends PedidosRepository {
  @override
  Future<PedidoRenovacao?> pendentePorNif(String nif) async => null;
}

class _FakeAceitesRepo extends AceitesRepository {
  @override
  Future<AceiteTermo?> ultimoPorMachineId(String machineId) async => null;
}

Licenca _lic({String? clienteId}) => Licenca(
      id: 'lic-1',
      machineId: 'demo-1',
      clienteId: clienteId,
      nif: '500000009',
      nome: 'Lavandaria X',
      plano: 'anual',
      validade: DateTime(2030, 1, 1),
      activa: true,
      criadoEm: DateTime(2026, 1, 1),
    );

Ping _ping({String? ip}) => Ping(
      id: 'p1',
      machineId: 'demo-1',
      versao: '2.0.6',
      metodoGeo: 'ip',
      cidade: 'Porto',
      ipPublico: ip,
      criadoEm: DateTime(2026, 7, 21, 10),
    );

Future<void> _montar(
  WidgetTester tester, {
  Ping? ping,
  List<Cliente> clientes = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        licencasRepoProvider.overrideWithValue(
            _FakeLicencasRepo(_lic(clienteId: clientes.isEmpty ? null : 'c1'))),
        pingsRepoProvider.overrideWithValue(_FakePingsRepo(ping)),
        pedidosRepoProvider.overrideWithValue(_FakePedidosRepo()),
        aceitesRepoProvider.overrideWithValue(_FakeAceitesRepo()),
        clientesRepoProvider.overrideWithValue(_FakeClientesRepo(clientes)),
      ],
      child: const MaterialApp(home: DetalheClienteScreen(machineId: 'demo-1')),
    ),
  );
  await tester.pumpAndSettle();
}

Cliente _cliente({String? telemovel}) => Cliente(
      id: 'c1',
      nif: '500000009',
      nome: 'Lavandaria X',
      telemovel: telemovel,
      criadoEm: DateTime(2026, 1, 1),
    );

void main() {
  group('linha IP (card Último acesso)', () {
    // Só o valor do endereço é âncora fiável: o rótulo "IP" e o ícone wifi
    // também surgem na linha do sinal quando o método de geo é 'ip'.
    testWidgets('ping com ip_publico → mostra o endereço', (t) async {
      await _montar(t, ping: _ping(ip: '46.102.20.34'));
      expect(find.text('46.102.20.34'), findsOneWidget);
    });

    testWidgets('ping sem ip_publico → não mostra endereço nenhum', (t) async {
      await _montar(t, ping: _ping(ip: null));
      expect(find.textContaining(RegExp(r'\d+\.\d+\.\d+\.\d+')), findsNothing);
    });
  });

  group('linha Telefone (dados do cliente)', () {
    testWidgets('cliente com telemóvel → mostra a linha e o ícone', (t) async {
      await _montar(t, clientes: [_cliente(telemovel: '214000000')]);
      expect(find.text('Telefone'), findsOneWidget);
      expect(find.text('214000000'), findsOneWidget);
      expect(find.byIcon(Icons.phone), findsOneWidget);
    });

    testWidgets('cliente sem telemóvel → não mostra a linha', (t) async {
      await _montar(t, clientes: [_cliente(telemovel: null)]);
      expect(find.text('Telefone'), findsNothing);
    });
  });
}
