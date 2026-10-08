import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/contexto_instalacoes.dart';
import 'package:washinvoice_control/models/licenca.dart';
import 'package:washinvoice_control/repositories/punho_admin_repository.dart';

Licenca _fist({String? nomeComercial, String nif = '000000000'}) => Licenca(
  id: 'l1',
  app: 'punho',
  machineId: '8a0f8c1234567890',
  nif: nif,
  nomeComercial: nomeComercial,
  plano: 'trial',
  validade: DateTime(2026, 1, 1),
  activa: true,
  criadoEm: DateTime(2025),
);

void main() {
  test('Fist sem nome nem empresa: «Fist · terminal xxxxxx», nunca só o NIF', () {
    final l = _fist(nif: '123456789');
    final ctx = ContextoInstalacoes.build(
      clientes: const [],
      licencas: [l],
      pings: const [],
    );
    expect(
      ctx.nomeDe(machineId: l.machineId, nif: l.nif),
      'Fist · terminal 8a0f8c',
    );
  });

  test('a empresa que o Fist conhece ganha ao fallback', () {
    final l = _fist();
    final ctx = ContextoInstalacoes.build(
      clientes: const [],
      licencas: [l],
      pings: const [],
      nomesFist: {
        l.machineId: const NomeDoTerminalFist(nome: 'DepilConcept', aprovado: true),
      },
    );
    expect(ctx.nomeDe(machineId: l.machineId), 'DepilConcept');
  });

  test('o nome comercial ganha a tudo', () {
    final l = _fist(nomeComercial: 'Loja Sol');
    final ctx = ContextoInstalacoes.build(
      clientes: const [],
      licencas: [l],
      pings: const [],
    );
    expect(ctx.nomeDe(machineId: l.machineId), 'Loja Sol');
  });
}
