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

/// Repositório de licenças falso: resolve por machine_id a partir de um mapa.
class _FakeLicencasRepo extends LicencasRepository {
  final Map<String, Licenca> porMaquina;
  _FakeLicencasRepo(this.porMaquina);

  @override
  Future<Licenca?> porMachineId(String machineId) async =>
      porMaquina[machineId];

  @override
  Future<List<Licenca>> listar() async => porMaquina.values.toList();
}

class _FakeClientesRepo extends ClientesRepository {
  @override
  Future<List<Cliente>> listar() async => [];
}

class _FakePingsRepo extends PingsRepository {
  @override
  Future<List<Ping>> historico(String machineId, {int limite = 20}) async => [];

  @override
  Future<List<Ping>> ultimosPorInstalacao() async => [];
}

class _FakePedidosRepo extends PedidosRepository {
  @override
  Future<PedidoRenovacao?> pendentePorNif(String nif) async => null;
}

class _FakeAceitesRepo extends AceitesRepository {
  @override
  Future<AceiteTermo?> ultimoPorMachineId(String machineId) async => null;
}

void main() {
  testWidgets(
      'DetalheClienteScreen abre a licença do machine_id certo quando há '
      'duas licenças no mesmo NIF', (tester) async {
    // Duas licenças, MESMO NIF, machine_id diferente.
    Licenca lic(String machine, String nome) => Licenca(
          id: 'lic-$machine',
          machineId: machine,
          nif: '500000009',
          nome: nome,
          plano: 'anual',
          validade: DateTime(2030, 1, 1),
          activa: true,
          criadoEm: DateTime(2026, 1, 1),
        );

    final repo = _FakeLicencasRepo({
      'demo-A': lic('demo-A', 'Cliente A'),
      'demo-B': lic('demo-B', 'Cliente B'),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          licencasRepoProvider.overrideWithValue(repo),
          pingsRepoProvider.overrideWithValue(_FakePingsRepo()),
          pedidosRepoProvider.overrideWithValue(_FakePedidosRepo()),
          aceitesRepoProvider.overrideWithValue(_FakeAceitesRepo()),
          clientesRepoProvider.overrideWithValue(_FakeClientesRepo()),
        ],
        child: const MaterialApp(
          home: DetalheClienteScreen(machineId: 'demo-B'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Carrega a B (a que se "clicou"), não a A.
    expect(find.text('Cliente B'), findsWidgets); // título AppBar
    expect(find.text('demo-B'), findsOneWidget); // linha Machine ID
    expect(find.text('Cliente A'), findsNothing);
    expect(find.text('demo-A'), findsNothing);
  });
}
