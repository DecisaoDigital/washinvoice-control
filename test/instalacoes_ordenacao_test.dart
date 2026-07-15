import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/contexto_instalacoes.dart';
import 'package:washinvoice_control/features/instalacoes/instalacoes_screen.dart';
import 'package:washinvoice_control/models/licenca.dart';
import 'package:washinvoice_control/models/ping.dart';

Licenca _lic(String id, String nome, DateTime validade) => Licenca(
      id: id,
      machineId: 'm$id',
      nif: '5000000$id',
      nome: nome,
      plano: 'anual',
      validade: validade,
      activa: true,
      criadoEm: DateTime(2026),
    );

Ping _ping(String id, String? cidade, DateTime quando) => Ping(
      id: 'p$id',
      machineId: 'm$id',
      cidade: cidade,
      criadoEm: quando,
    );

void main() {
  // l1 Charlie, l2 Alpha, l3 Bravo (sem ping), l4 Delta.
  final l1 = _lic('1', 'Charlie', DateTime(2030, 3, 1));
  final l2 = _lic('2', 'Alpha', DateTime(2031, 1, 1));
  final l3 = _lic('3', 'Bravo', DateTime(2029, 12, 1));
  final l4 = _lic('4', 'Delta', DateTime(2030, 6, 1));
  final licencas = [l1, l2, l3, l4];

  final pings = [
    _ping('1', 'Lisbon', DateTime(2026, 7, 10)),
    _ping('2', 'Braga', DateTime(2026, 7, 14)),
    _ping('4', 'Aveiro', DateTime(2026, 7, 12)),
  ];
  final pingPorMachine = {for (final p in pings) p.machineId: p};
  final ctx = ContextoInstalacoes.build(
      clientes: [], licencas: licencas, pings: pings);

  List<String> ids(OrdenacaoInstalacoes o) => ordenarInstalacoes(
        licencas,
        o,
        ctx: ctx,
        pingPorMachine: pingPorMachine,
      ).map((l) => l.id).toList();

  test('último acesso: mais recente primeiro, sem ping ao fim', () {
    expect(ids(OrdenacaoInstalacoes.ultimoAcesso), ['2', '4', '1', '3']);
  });

  test('nome do cliente A→Z', () {
    expect(ids(OrdenacaoInstalacoes.nome), ['2', '3', '1', '4']);
  });

  test('validade: fim mais próximo primeiro', () {
    expect(ids(OrdenacaoInstalacoes.validade), ['3', '1', '4', '2']);
  });

  test('localidade A→Z (Lisbon→Lisboa; sem ping fica vazio, ordena primeiro)',
      () {
    expect(ids(OrdenacaoInstalacoes.localidade), ['3', '4', '2', '1']);
  });
}
