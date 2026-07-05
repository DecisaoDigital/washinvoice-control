import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/models/licenca.dart';
import 'package:washinvoice_control/services/licenca_assinatura.dart';
import 'package:washinvoice_control/services/licenca_emissao.dart';

/// CONSISTÊNCIA CROSS-APP — o Control tem de assinar EXACTAMENTE como a CLI
/// `tool/emitir_licenca.dart` do WashFactura. Os valores de referência abaixo
/// foram calculados pelo próprio WashFactura (assinarLicenca) para estes inputs:
///   nif=500000000, machineId='a'*64, validade=2027-06-27, plano=anual
/// Se estes testes falharem, as duas implementações divergiram → uma licença
/// gerada por uma ficaria inválida na outra.
void main() {
  final mid = 'a' * 64;
  const refSemSerie =
      'e2326d80b9542a39e10d6ff44e18f3f2b5d0f48f58b0bf70d4cafd79ea0d386b';
  const refComSerie =
      '2333817e7cb7541329d8dbfcf6af98fb7b3992799455c5462941cb5b534b4c8b';

  group('assinatura idêntica ao WashFactura', () {
    test('sem série → assinatura de referência', () {
      expect(
        assinarLicenca(
            nif: '500000000',
            machineId: mid,
            validade: '2027-06-27',
            plano: 'anual'),
        refSemSerie,
      );
    });

    test('com série FT-T1 → assinatura de referência', () {
      expect(
        assinarLicenca(
            nif: '500000000',
            machineId: mid,
            validade: '2027-06-27',
            plano: 'anual',
            serie: 'FT-T1'),
        refComSerie,
      );
    });
  });

  group('construirLicencaJson', () {
    Map<String, dynamic> gerar({String? serie}) => jsonDecode(
          construirLicencaJson(
            nif: '500000000',
            nome: 'WashExpress',
            machineId: mid,
            plano: 'anual',
            validade: DateTime(2027, 6, 27),
            serie: serie,
          ),
        ) as Map<String, dynamic>;

    test('com série: campos e assinatura de referência', () {
      final j = gerar(serie: 'FT-T1');
      expect(j['machine_id'], mid);
      expect(j['validade'], '2027-06-27'); // AAAA-MM-DD, não ISO completo
      expect(j['plano'], 'anual');
      expect(j['serie'], 'FT-T1');
      expect(j['versao_termos'], '1.0');
      expect(j['assinatura'], refComSerie);
    });

    test('retrocompatível: sem série não tem a chave e usa a assinatura antiga',
        () {
      final j = gerar();
      expect(j.containsKey('serie'), isFalse);
      expect(j['assinatura'], refSemSerie);
    });

    test('série só com espaços é tratada como ausente', () {
      final j = gerar(serie: '   ');
      expect(j.containsKey('serie'), isFalse);
      expect(j['assinatura'], refSemSerie);
    });
  });

  group('gerarLicencaJsonComVerificacao (colisão de série)', () {
    Licenca lic() => Licenca(
          id: 'id1',
          machineId: mid,
          nif: '500000000',
          nome: 'WashExpress',
          plano: 'anual',
          validade: DateTime(2027, 6, 27),
          activa: true,
          criadoEm: DateTime(2026, 1, 1),
        );

    test('série vazia bloqueia a geração', () {
      expectLater(
        gerarLicencaJsonComVerificacao(
            licenca: lic(),
            serie: '   ',
            verificarColisao: (_, __) async => null),
        throwsA(isA<StateError>()),
      );
    });

    test('colisão (mesma série, outro terminal) bloqueia a geração', () {
      final conflito = Licenca(
        id: 'id2',
        machineId: 'b' * 64,
        nif: '999999999',
        plano: 'anual',
        validade: DateTime(2027, 1, 1),
        activa: true,
        serie: 'FT-T1',
        criadoEm: DateTime(2026, 1, 1),
      );
      expectLater(
        gerarLicencaJsonComVerificacao(
            licenca: lic(),
            serie: 'FT-T1',
            verificarColisao: (_, __) async => conflito),
        throwsA(isA<StateError>()),
      );
    });

    test('sem colisão → gera o json com a série (assinatura de referência)',
        () async {
      var chamouColisao = false;
      final json = await gerarLicencaJsonComVerificacao(
        licenca: lic(),
        serie: 'FT-T1',
        verificarColisao: (s, m) async {
          chamouColisao = true;
          expect(s, 'FT-T1');
          expect(m, mid); // verifica pelo machine_id certo
          return null;
        },
      );
      expect(chamouColisao, isTrue);
      final j = jsonDecode(json) as Map<String, dynamic>;
      expect(j['serie'], 'FT-T1');
      expect(j['assinatura'], refComSerie);
    });
  });

  group('Licenca serde com serie', () {
    test('round-trip do campo serie', () {
      final l = Licenca.fromJson({
        'id': 'i',
        'machine_id': mid,
        'nif': '500000000',
        'plano': 'anual',
        'validade': '2027-06-27',
        'activa': true,
        'serie': 'FT-T1',
        'created_at': '2026-01-01T00:00:00.000',
      });
      expect(l.serie, 'FT-T1');
      expect(l.toJson()['serie'], 'FT-T1');
    });

    test('licença sem serie (antiga) → serie null', () {
      final l = Licenca.fromJson({
        'id': 'i',
        'machine_id': mid,
        'nif': '500000000',
        'plano': 'anual',
        'validade': '2027-06-27',
        'activa': true,
        'created_at': '2026-01-01T00:00:00.000',
      });
      expect(l.serie, isNull);
    });
  });
}
