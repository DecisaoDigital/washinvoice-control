import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/models/licenca.dart';
import 'package:washinvoice_control/services/licenca/assinar_licenca_service.dart';
import 'package:washinvoice_control/services/licenca_emissao.dart';

/// O Control **já não assina**. A chave privada Ed25519 vive num secret do
/// Supabase e só a Edge Function `assinar-licenca` lhe toca; aqui não há chave
/// nenhuma para extrair de um APK — que era metade do problema antigo, porque a
/// chave HMAC simétrica estava nos dois binários.
///
/// O que estes testes fixam é a consequência disso: o `licenca.json` é montado
/// **exactamente** com os campos que voltaram assinados, sem recalcular nada.
/// Se o Control alterasse um valor pelo caminho, a assinatura deixava de bater
/// e o terminal recusava a licença.
void main() {
  final mid = 'a' * 64;

  LicencaAssinada assinada({
    String? serie,
    String? chaveMestre,
    String? nome = 'WashExpress',
    int versao = 2,
  }) =>
      LicencaAssinada(
        versaoAssinatura: versao,
        assinatura: 'ASSINATURA_DO_SERVIDOR',
        nif: '500000000',
        nome: nome,
        chaveMestre: chaveMestre,
        machineId: mid,
        plano: 'anual',
        validade: '2027-06-27',
        serie: serie,
      );

  group('construirLicencaJson escreve o que o servidor assinou', () {
    test('campos passam tal e qual, e a versão da assinatura vai no ficheiro',
        () {
      final j = jsonDecode(construirLicencaJson(
        assinada(serie: 'FT-T1', chaveMestre: 'TRD-ABC123XYZ89'),
      )) as Map<String, dynamic>;

      expect(j['nif'], '500000000');
      expect(j['nome'], 'WashExpress');
      expect(j['chave_mestre'], 'TRD-ABC123XYZ89');
      expect(j['machine_id'], mid);
      expect(j['plano'], 'anual');
      expect(j['validade'], '2027-06-27'); // AAAA-MM-DD, não ISO completo
      expect(j['serie'], 'FT-T1');
      expect(j['versao_termos'], '1.0');
      expect(j['assinatura'], 'ASSINATURA_DO_SERVIDOR');

      // É este campo que diz ao POS com que algoritmo verificar. Sem ele, o POS
      // assume 1 (HMAC) e recusa a licença nova.
      expect(j['versao_assinatura'], 2);
    });

    test('campos opcionais ausentes não aparecem no ficheiro', () {
      final j = jsonDecode(construirLicencaJson(assinada()))
          as Map<String, dynamic>;
      expect(j.containsKey('serie'), isFalse);
      expect(j.containsKey('chave_mestre'), isFalse);
    });

    test('a validade não é reformatada — vai como foi assinada', () {
      // Reformatar aqui era exactamente a maneira de partir a assinatura sem
      // dar por isso: `2027-06-27` e `2027-06-27T00:00:00` são bases
      // diferentes, e só uma foi assinada.
      final j = jsonDecode(construirLicencaJson(assinada()))
          as Map<String, dynamic>;
      expect(j['validade'], '2027-06-27');
    });
  });

  group('LicencaAssinada.fromJson', () {
    Map<String, dynamic> resposta({Map<String, dynamic>? campos}) => {
          'ok': true,
          'versao_assinatura': 2,
          'assinatura': 'ABC',
          'campos': campos ??
              {
                'nif': '500000000',
                'nome': 'WashExpress',
                'chave_mestre': null,
                'machine_id': 'a' * 64,
                'plano': 'anual',
                'validade': '2027-06-27',
                'serie': 'FT-T1',
              },
        };

    test('lê a resposta completa', () {
      final a = LicencaAssinada.fromJson(resposta());
      expect(a.assinatura, 'ABC');
      expect(a.versaoAssinatura, 2);
      expect(a.serie, 'FT-T1');
      expect(a.chaveMestre, isNull);
    });

    test('resposta sem assinatura rebenta em vez de gerar ficheiro sem ela', () {
      expect(
        () => LicencaAssinada.fromJson({'ok': true, 'campos': const {}}),
        throwsA(isA<AssinarLicencaException>()),
      );
    });

    test('campo obrigatório em falta rebenta', () {
      final semNif = Map<String, dynamic>.from(resposta());
      (semNif['campos'] as Map).remove('nif');
      expect(() => LicencaAssinada.fromJson(semNif),
          throwsA(isA<AssinarLicencaException>()));
    });
  });

  group('AssinarLicencaService', () {
    test('manda o terminal e a série, e devolve o que veio assinado', () async {
      Map<String, dynamic>? enviado;
      final servico = AssinarLicencaService.comInvocador((body) async {
        enviado = body;
        return {
          'ok': true,
          'versao_assinatura': 2,
          'assinatura': 'SIG',
          'campos': {
            'nif': '500000000',
            'machine_id': mid,
            'plano': 'anual',
            'validade': '2027-06-27',
            'serie': 'FT-T1',
          },
        };
      });

      final a = await servico.assinar(mid, serie: 'FT-T1');

      expect(enviado, {'machine_id': mid, 'serie': 'FT-T1'});
      expect(a.assinatura, 'SIG');
    });

    test('erro do servidor vira excepção com a mensagem dele', () async {
      final servico = AssinarLicencaService.comInvocador(
          (_) async => {'ok': false, 'erro': 'sem permissões de administrador'});
      await expectLater(
        servico.assinar(mid),
        throwsA(isA<AssinarLicencaException>().having(
            (e) => e.mensagem, 'mensagem', 'sem permissões de administrador')),
      );
    });

    test('chave de assinatura por configurar no servidor → erro claro',
        () async {
      // O caso que aparece se o secret `LICENCA_ED25519_PRIVATE_KEY` faltar.
      final servico = AssinarLicencaService.comInvocador((_) async =>
          {'ok': false, 'erro': 'chave de assinatura não configurada no servidor'});
      await expectLater(servico.assinar(mid),
          throwsA(isA<AssinarLicencaException>()));
    });
  });

  group('gerarLicencaJsonComVerificacao (colisão de série)', () {
    Future<LicencaAssinada> assinarFalso(String machineId, String serie) async =>
        assinada(serie: serie);

    test('série vazia bloqueia antes de chegar ao servidor', () async {
      var chamouAssinar = false;
      await expectLater(
        gerarLicencaJsonComVerificacao(
          machineId: mid,
          serie: '   ',
          verificarColisao: (_, __) async => null,
          assinar: (m, s) async {
            chamouAssinar = true;
            return assinada(serie: s);
          },
        ),
        throwsA(isA<StateError>()),
      );
      expect(chamouAssinar, isFalse);
    });

    test('colisão bloqueia ANTES de assinar', () async {
      // Importa a ordem: assinar grava a série na linha do terminal. Assinar
      // primeiro e verificar depois gravava a série que colide.
      var chamouAssinar = false;
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
      await expectLater(
        gerarLicencaJsonComVerificacao(
          machineId: mid,
          serie: 'FT-T1',
          verificarColisao: (_, __) async => conflito,
          assinar: (m, s) async {
            chamouAssinar = true;
            return assinada(serie: s);
          },
        ),
        throwsA(isA<StateError>()),
      );
      expect(chamouAssinar, isFalse);
    });

    test('sem colisão → assina e devolve o json', () async {
      var chamouColisao = false;
      final json = await gerarLicencaJsonComVerificacao(
        machineId: mid,
        serie: 'FT-T1',
        verificarColisao: (s, m) async {
          chamouColisao = true;
          expect(s, 'FT-T1');
          expect(m, mid); // verifica pelo machine_id certo
          return null;
        },
        assinar: assinarFalso,
      );
      expect(chamouColisao, isTrue);
      final j = jsonDecode(json) as Map<String, dynamic>;
      expect(j['serie'], 'FT-T1');
      expect(j['assinatura'], 'ASSINATURA_DO_SERVIDOR');
      expect(j['versao_assinatura'], 2);
    });
  });

  group('Licenca serde', () {
    test('round-trip do campo chave_mestre', () {
      final l = Licenca.fromJson({
        'id': 'i',
        'machine_id': mid,
        'nif': '500000000',
        'plano': 'anual',
        'validade': '2027-06-27',
        'activa': true,
        'chave_mestre': 'TRD-ABC123',
        'created_at': '2026-01-01T00:00:00.000',
      });
      expect(l.chaveMestre, 'TRD-ABC123');
      expect(l.toJson()['chave_mestre'], 'TRD-ABC123');
    });

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
  });
}
