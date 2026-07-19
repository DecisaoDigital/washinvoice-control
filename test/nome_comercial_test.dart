import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/contexto_instalacoes.dart';
import 'package:washinvoice_control/core/exibicao.dart';
import 'package:washinvoice_control/models/cliente.dart';
import 'package:washinvoice_control/models/licenca.dart';

/// Fases 2 e 3 — nome comercial em destaque, e rótulo do sinal.

Licenca _lic({
  String machineId = 'm1',
  String nif = '500000001',
  String? nome,
  String? nomeComercial,
}) =>
    Licenca(
      id: 'lic-$machineId',
      machineId: machineId,
      nif: nif,
      nome: nome,
      nomeComercial: nomeComercial,
      plano: 'anual',
      validade: DateTime(2026, 12, 31),
      activa: true,
      criadoEm: DateTime(2026, 1, 1),
    );

Cliente _cli({
  String nif = '500000001',
  String nome = '',
  String? nomeComercial,
}) =>
    Cliente(
      id: 'cli-1',
      nif: nif,
      nome: nome,
      nomeComercial: nomeComercial,
      criadoEm: DateTime(2026, 1, 1),
    );

void main() {
  group('Licenca.fromJson lê nome_comercial', () {
    test('presente', () {
      final l = Licenca.fromJson({
        'id': 'x',
        'machine_id': 'm1',
        'nif': '500000001',
        'nome': 'Telma Sofia Unipessoal Lda',
        'nome_comercial': 'WashExpress',
        'plano': 'anual',
        'validade': '2026-12-31',
        'activa': true,
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(l.nome, 'Telma Sofia Unipessoal Lda');
      expect(l.nomeComercial, 'WashExpress');
    });

    test('ausente → null, sem rebentar', () {
      final l = Licenca.fromJson({
        'id': 'x',
        'machine_id': 'm1',
        'nif': '500000001',
        'plano': 'anual',
        'validade': '2026-12-31',
        'activa': true,
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(l.nomeComercial, isNull);
    });

    test('round-trip pelo toJson', () {
      final l = _lic(nome: 'Legal Lda', nomeComercial: 'Comercial');
      expect(Licenca.fromJson(l.toJson()).nomeComercial, 'Comercial');
    });
  });

  test('Cliente.fromJson lê nome_comercial', () {
    final c = Cliente.fromJson({
      'id': 'c1',
      'nif': '500000001',
      'nome': 'Legal Lda',
      'nome_comercial': 'Comercial',
      'created_at': '2026-01-01T00:00:00Z',
    });
    expect(c.nomeComercial, 'Comercial');
  });

  group('ContextoInstalacoes.nomeDe — comercial em destaque', () {
    String nomeCom({Licenca? lic, Cliente? cli}) {
      final ctx = ContextoInstalacoes.build(
        clientes: cli == null ? const [] : [cli],
        licencas: lic == null ? const [] : [lic],
        pings: const [],
      );
      return ctx.nomeDe(machineId: 'm1', nif: lic?.nif);
    }

    test('ambos preenchidos → mostra o comercial', () {
      expect(
        nomeCom(
          lic: _lic(nome: 'Telma Sofia Unipessoal Lda', nomeComercial: 'WashExpress'),
        ),
        'WashExpress',
      );
    });

    test('só designação social → mostra a designação', () {
      expect(nomeCom(lic: _lic(nome: 'Telma Sofia Unipessoal Lda')),
          'Telma Sofia Unipessoal Lda');
    });

    test('nenhum → cai no NIF', () {
      expect(nomeCom(lic: _lic()), 'NIF 500000001');
    });

    test('comercial do cliente ganha ao da licença', () {
      expect(
        nomeCom(
          lic: _lic(nome: 'Legal', nomeComercial: 'Antigo'),
          cli: _cli(nome: 'Legal', nomeComercial: 'Actual'),
        ),
        'Actual',
      );
    });

    test('comercial vazio não esconde a designação', () {
      expect(nomeCom(lic: _lic(nome: 'Legal Lda', nomeComercial: '   ')),
          'Legal Lda');
    });
  });

  group('Exibicao.rotuloSinal', () {
    test('gps → GPS', () => expect(Exibicao.rotuloSinal('gps'), 'GPS'));
    test('ip → IP', () => expect(Exibicao.rotuloSinal('ip'), 'IP'));
    test('nenhum → Sem sinal',
        () => expect(Exibicao.rotuloSinal('nenhum'), 'Sem sinal'));
    test('null → Sem sinal',
        () => expect(Exibicao.rotuloSinal(null), 'Sem sinal'));
    test('desconhecido → Sem sinal',
        () => expect(Exibicao.rotuloSinal('satelite'), 'Sem sinal'));

    test('é mais curto que a descrição longa (serve de etiqueta)', () {
      // O rótulo entra numa coluna de 100px; a descrição é para frases.
      expect(Exibicao.rotuloSinal('ip').length,
          lessThan(Exibicao.descricaoSinal('ip').length));
    });
  });
}
