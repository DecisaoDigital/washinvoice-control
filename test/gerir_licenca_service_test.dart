import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/models/licenca.dart';
import 'package:washinvoice_control/services/licenca/gerir_licenca_service.dart';

/// Fase 3 — cliente da Edge Function `gerir-licenca`: body de cada acção e
/// parse da resposta.

Map<String, dynamic> _resposta({
  String acao = 'prolongar',
  bool activa = true,
  String validade = '2026-08-21',
  String tier = 'pro',
  String plano = 'anual',
  Map<String, dynamic> prefs = const {'guias': true},
}) =>
    {
      'ok': true,
      'acao': acao,
      'machine_id': 'abc123',
      'licenca_actualizada': {
        'activa': activa,
        'validade': validade,
        'tier': tier,
        'plano': plano,
        'preferencias_features': prefs,
      },
    };

void main() {
  late List<Map<String, dynamic>> corpos;

  GerirLicencaService servicoCom(Map<String, dynamic> resposta) {
    corpos = [];
    return GerirLicencaService.comInvocador((body) async {
      corpos.add(body);
      return resposta;
    });
  }

  setUp(() => corpos = []);

  group('body enviado', () {
    test('prolongar', () async {
      final s = servicoCom(_resposta());
      await s.prolongar('abc123', 15);
      expect(corpos.single, {
        'acao': 'prolongar',
        'machine_id': 'abc123',
        'parametros': {'dias': 15},
      });
    });

    test('definir_validade envia só a data, sem hora', () async {
      final s = servicoCom(_resposta(acao: 'definir_validade'));
      await s.definirValidade('abc123', DateTime(2026, 9, 1, 14, 30));
      expect(corpos.single['acao'], 'definir_validade');
      expect(corpos.single['parametros'], {'validade': '2026-09-01'});
    });

    test('suspender / reactivar / cancelar não levam parâmetros', () async {
      for (final (metodo, esperado) in [
        ((GerirLicencaService s) => s.suspender('abc123'), 'suspender'),
        ((GerirLicencaService s) => s.reactivar('abc123'), 'reactivar'),
        ((GerirLicencaService s) => s.cancelar('abc123'), 'cancelar'),
      ]) {
        final s = servicoCom(_resposta(acao: esperado));
        await metodo(s);
        expect(corpos.single['acao'], esperado);
        expect(corpos.single['parametros'], isEmpty);
      }
    });

    test('mudar_tier envia o nome do tier', () async {
      final s = servicoCom(_resposta(acao: 'mudar_tier', tier: 'base'));
      await s.mudarTier('abc123', Tier.base);
      expect(corpos.single['acao'], 'mudar_tier');
      expect(corpos.single['parametros'], {'tier': 'base'});
    });

    test('mudar_tier recusa legado sem sair à rede', () async {
      final s = servicoCom(_resposta());
      expect(
        () => s.mudarTier('abc123', Tier.legado),
        throwsA(isA<GerirLicencaException>()),
      );
      expect(corpos, isEmpty, reason: 'não devia ter chamado a function');
    });
  });

  group('parse da resposta', () {
    test('devolve a licença actualizada', () async {
      final s = servicoCom(_resposta(
        validade: '2026-12-31',
        tier: 'pro',
        prefs: {'guias': false, 'gestao': true},
      ));
      final r = await s.prolongar('abc123', 30);
      expect(r.validade, DateTime(2026, 12, 31));
      expect(r.tier, Tier.pro);
      expect(r.activa, isTrue);
      expect(r.preferenciasFeatures, {'guias': false, 'gestao': true});
    });

    test('tier ausente → legado (não assume Base)', () async {
      final s = GerirLicencaService.comInvocador((_) async => {
            'ok': true,
            'licenca_actualizada': {
              'activa': true,
              'validade': '2026-08-01',
              'plano': 'anual',
            },
          });
      final r = await s.suspender('abc123');
      expect(r.tier, Tier.legado);
      expect(r.preferenciasFeatures, isEmpty);
    });

    test('preferências ignoram valores não-booleanos', () async {
      final s = servicoCom(_resposta(prefs: {'guias': true, 'lixo': 'sim'}));
      final r = await s.prolongar('abc123', 5);
      expect(r.preferenciasFeatures, {'guias': true});
    });
  });

  group('erros', () {
    test('ok:false lança com a mensagem do servidor', () async {
      final s = GerirLicencaService.comInvocador(
          (_) async => {'ok': false, 'erro': 'sem permissões de administrador'});
      expect(
        () => s.suspender('abc123'),
        throwsA(isA<GerirLicencaException>().having(
            (e) => e.mensagem, 'mensagem', contains('administrador'))),
      );
    });

    test('ok:true sem licenca_actualizada lança', () async {
      final s = GerirLicencaService.comInvocador((_) async => {'ok': true});
      expect(() => s.cancelar('abc123'),
          throwsA(isA<GerirLicencaException>()));
    });

    test('resposta sem validade lança em vez de inventar uma data', () async {
      final s = GerirLicencaService.comInvocador((_) async => {
            'ok': true,
            'licenca_actualizada': {'activa': false},
          });
      expect(() => s.cancelar('abc123'),
          throwsA(isA<GerirLicencaException>()));
    });
  });

  test('dias permitidos são os que a function aceita', () {
    expect(GerirLicencaService.diasPermitidos, [5, 15, 30]);
  });
}
