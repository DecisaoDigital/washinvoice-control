import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/exibicao.dart';
import 'package:washinvoice_control/models/cliente.dart';
import 'package:washinvoice_control/models/licenca.dart';
import 'package:washinvoice_control/models/ping.dart';

Licenca _lic({String? nome, String nif = '500000009', String id = 'l1'}) =>
    Licenca(
      id: id,
      machineId: 'm-$id',
      nif: nif,
      nome: nome,
      plano: 'anual',
      validade: DateTime(2030),
      activa: true,
      criadoEm: DateTime(2026),
    );

void main() {
  group('nomeExibicao', () {
    test('sem terminais múltiplos → só o nome', () {
      expect(
        Exibicao.nomeExibicao(_lic(nome: 'Lavandaria X')),
        'Lavandaria X',
      );
    });

    test('sem nome → NIF', () {
      expect(Exibicao.nomeExibicao(_lic()), 'NIF 500000009');
    });

    test('total <= 1 não acrescenta T', () {
      expect(
        Exibicao.nomeExibicao(_lic(nome: 'Loja'),
            ordemTerminal: 1, totalTerminaisCliente: 1),
        'Loja',
      );
    });

    test('2+ terminais → nome · T<ordem>', () {
      expect(
        Exibicao.nomeExibicao(_lic(nome: 'Loja'),
            ordemTerminal: 2, totalTerminaisCliente: 3),
        'Loja · T2',
      );
    });
  });

  group('sinalLocalidade', () {
    Ping ping({String? cidade}) => Ping(
          id: 'p',
          machineId: 'm',
          cidade: cidade,
          criadoEm: DateTime(2026),
        );
    Cliente cliente({String? localidade}) => Cliente(
          id: 'c',
          nif: '1',
          nome: 'C',
          localidade: localidade,
          criadoEm: DateTime(2026),
        );

    test('com cidade e localidade', () {
      expect(
        Exibicao.sinalLocalidade(
            ping(cidade: 'Setúbal'), cliente(localidade: 'Pinhal Novo')),
        'Setúbal − Pinhal Novo',
      );
    });

    test('sem ping → "?" à esquerda', () {
      expect(
        Exibicao.sinalLocalidade(null, cliente(localidade: 'Pinhal Novo')),
        '? − Pinhal Novo',
      );
    });

    test('sem localidade → "-" à direita', () {
      expect(
        Exibicao.sinalLocalidade(ping(cidade: 'Setúbal'), cliente()),
        'Setúbal − -',
      );
    });

    test('sem ping nem cliente', () {
      expect(Exibicao.sinalLocalidade(null, null), '? − -');
    });
  });

  group('ordemTerminais', () {
    test('agrupa por cliente e ordena por created_at', () {
      final a = Licenca(
          id: 'a',
          clienteId: 'cli',
          machineId: 'ma',
          nif: '1',
          plano: 'anual',
          validade: DateTime(2030),
          activa: true,
          criadoEm: DateTime(2026, 1, 1));
      final b = Licenca(
          id: 'b',
          clienteId: 'cli',
          machineId: 'mb',
          nif: '1',
          plano: 'anual',
          validade: DateTime(2030),
          activa: true,
          criadoEm: DateTime(2026, 2, 1));
      final sozinha = _lic(id: 'z');

      final ordem = Exibicao.ordemTerminais([b, a, sozinha]);
      expect(ordem['a'], (1, 2)); // criada primeiro
      expect(ordem['b'], (2, 2));
      expect(ordem['z'], (1, 1)); // sem cliente → terminal único
    });
  });
}
