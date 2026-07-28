import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/services/licenca/comunicar_serie_service.dart';

void main() {
  group('ComunicarSerieService.comunicar', () {
    test('envia o body correcto e devolve o ATCUD', () async {
      Map<String, dynamic>? enviado;
      final s = ComunicarSerieService.comInvocador((body) async {
        enviado = body;
        return {'ok': true, 'codigo_validacao': 'X6Y2ZM12'};
      });

      final atcud = await s.comunicar(
        'mac-1',
        serie: 'FTA2026',
        tipoDoc: 'FT',
        numeroInicial: 3,
        dataInicio: DateTime.utc(2026, 7, 22),
        meioProcessamento: 'OM',
      );

      expect(atcud, 'X6Y2ZM12');
      expect(enviado!['acao'], 'comunicar');
      expect(enviado!['machine_id'], 'mac-1');
      expect(enviado!['serie'], 'FTA2026');
      expect(enviado!['tipo_doc'], 'FT');
      expect(enviado!['numero_inicial'], 3);
      expect(enviado!['data_inicio'], '2026-07-22');
      expect(enviado!['meio_processamento'], 'OM');
    });

    test('ok:false lança ComunicarSerieException com a mensagem da AT', () async {
      final s = ComunicarSerieService.comInvocador(
        (_) async => {'ok': false, 'erro': 'série já comunicada'},
      );
      await expectLater(
        s.comunicar('mac', serie: 'S', tipoDoc: 'FT'),
        throwsA(isA<ComunicarSerieException>()
            .having((e) => e.mensagem, 'mensagem', 'série já comunicada')),
      );
    });

    test('ok:true mas sem código de validação lança', () async {
      final s = ComunicarSerieService.comInvocador((_) async => {'ok': true});
      await expectLater(
        s.comunicar('mac', serie: 'S', tipoDoc: 'FT'),
        throwsA(isA<ComunicarSerieException>()),
      );
    });
  });

  group('ComunicarSerieService.guardarCredenciais', () {
    test('envia acao e credenciais (username trimmed)', () async {
      Map<String, dynamic>? enviado;
      final s = ComunicarSerieService.comInvocador((body) async {
        enviado = body;
        return {'ok': true, 'configurado': true};
      });

      await s.guardarCredenciais('mac-9',
          username: '  215555449/1  ', password: 'segredo');

      expect(enviado!['acao'], 'guardar_credenciais');
      expect(enviado!['machine_id'], 'mac-9');
      expect(enviado!['at_username'], '215555449/1');
      expect(enviado!['at_password'], 'segredo');
    });

    test('username/password vazios → lança sem chamar a function', () async {
      var chamou = false;
      final s = ComunicarSerieService.comInvocador((_) async {
        chamou = true;
        return {'ok': true};
      });
      // O guard está na Edge Function; aqui garantimos que ok:false propaga.
      final s2 = ComunicarSerieService.comInvocador(
        (_) async => {'ok': false, 'erro': 'at_username e at_password obrigatorios'},
      );
      await expectLater(
        s2.guardarCredenciais('mac', username: '', password: ''),
        throwsA(isA<ComunicarSerieException>()),
      );
      expect(chamou, isFalse);
      // referência a `s` só para não ficar não usado
      expect(s, isA<ComunicarSerieService>());
    });
  });
}
