import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:washinvoice_control/features/acessos/gestao_acessos_screen.dart';
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
import 'package:washinvoice_control/repositories/punho_admin_repository.dart';
import 'package:washinvoice_control/repositories/sugestoes_repository.dart';

import '../acessos/punho/fake_punho_admin_repository.dart';

final agoraAgora = DateTime.now();

Licenca licencaTeste(
  String id, {
  required DateTime validade,
  String app = 'pos',
  String? nomeComercial,
  bool activa = true,
}) => Licenca(
  id: id,
  app: app,
  machineId: 'mid-$id',
  nif: '5000000$id',
  nomeComercial: nomeComercial ?? 'Loja $id',
  plano: 'anual',
  validade: validade,
  activa: activa,
  criadoEm: DateTime(2026),
);

Ping pingTeste(
  String id, {
  String app = 'pos',
  DateTime? quando,
  String? machineId,
}) => Ping(
  id: 'p$id',
  app: app,
  machineId: machineId ?? 'novo-$id',
  criadoEm: quando ?? agoraAgora.subtract(const Duration(hours: 1)),
);

PedidoAjuda ajudaTeste(String id, {DateTime? quando, String machineId = 'mid-1'}) =>
    PedidoAjuda(
      id: id,
      machineId: machineId,
      criadoEm: quando ?? agoraAgora.subtract(const Duration(hours: 2)),
    );

PedidoRenovacao renovacaoTeste(String id, {DateTime? quando}) =>
    PedidoRenovacao(
      id: id,
      machineId: 'mid-1',
      nif: '50000001',
      planoDesejado: 'anual',
      estado: 'pendente',
      criadoEm: quando ?? agoraAgora.subtract(const Duration(hours: 3)),
    );

Sugestao sugestaoTeste(String id, {DateTime? quando}) => Sugestao(
  id: id,
  machineId: 'mid-1',
  texto: 'Queria um botão novo',
  criadoEm: quando ?? agoraAgora.subtract(const Duration(days: 1)),
);

class FakeLic extends LicencasRepository {
  FakeLic(this.lista, {this.erro});
  final List<Licenca> lista;
  final Object? erro;
  int chamadas = 0;
  @override
  Future<List<Licenca>> listar({String? app}) async {
    chamadas++;
    if (erro != null) throw erro!;
    return lista.where((l) => app == null || l.app == app).toList();
  }

  // O Resumo (Dashboard) também usa estes dois.
  @override
  Future<List<Licenca>> aExpirar({int dias = 15, String? app}) async => [];
  @override
  Future<Set<String>> machineIdsComLicenca({String? app}) async =>
      {for (final l in lista) l.machineId};
}

class FakeRen extends PedidosRepository {
  FakeRen(this.lista);
  final List<PedidoRenovacao> lista;
  @override
  Future<List<PedidoRenovacao>> pendentes({String? app}) async => lista;
  @override
  Future<PedidoRenovacao?> pendentePorNif(String nif, {String? app}) async =>
      null;
}

class FakeAjuda extends PedidosAjudaRepository {
  FakeAjuda(this.lista);
  final List<PedidoAjuda> lista;
  final resolvidos = <String>[];
  @override
  Future<List<PedidoAjuda>> listarAbertos({String? app}) async => lista;
  @override
  Future<void> marcarResolvido(String id) async => resolvidos.add(id);
}

class FakePing extends PingsRepository {
  FakePing(this.lista);
  final List<Ping> lista;
  @override
  Future<List<Ping>> ultimosPorInstalacao({String? app}) async => lista;
}

class FakeCli extends ClientesRepository {
  @override
  Future<List<Cliente>> listar() async => [];
}

class FakeSug extends SugestoesRepository {
  FakeSug(this.lista);
  final List<Sugestao> lista;
  @override
  Future<List<Sugestao>> listarPorLer({String? app}) async => lista;
}

class FakeFistComNomes extends FakeFistAdmin {
  FakeFistComNomes({super.porEstado, super.empresas, super.erro});
  @override
  Future<Map<String, NomeDoTerminalFist>> nomesPorTerminal() async => {};
}

/// Overrides para montar a fila «Agora» (e o resto que dela depende) sem
/// Supabase.
List<Override> overridesAgora({
  List<Licenca> licencas = const [],
  List<Ping> pings = const [],
  List<PedidoAjuda> ajuda = const [],
  List<PedidoRenovacao> renovacoes = const [],
  List<Sugestao> sugestoes = const [],
  List<FistPedido> fist = const [],
  bool admin = true,
  Object? erroLicencas,
  FakeFistComNomes? fakeFist,
  FakeAjuda? fakeAjuda,
}) => [
  licencasRepoProvider.overrideWithValue(FakeLic(licencas, erro: erroLicencas)),
  pingsRepoProvider.overrideWithValue(FakePing(pings)),
  pedidosAjudaRepoProvider.overrideWithValue(fakeAjuda ?? FakeAjuda(ajuda)),
  pedidosRepoProvider.overrideWithValue(FakeRen(renovacoes)),
  sugestoesRepoProvider.overrideWithValue(FakeSug(sugestoes)),
  clientesRepoProvider.overrideWithValue(FakeCli()),
  punhoAdminRepoProvider.overrideWithValue(
    fakeFist ?? FakeFistComNomes(porEstado: {'pendente': fist}),
  ),
  souAdminGlobalProvider.overrideWith((_) async => admin),
];
