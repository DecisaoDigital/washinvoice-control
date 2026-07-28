import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/services/actualizacao/actualizacao_service.dart';

void main() {
  group('ActualizacaoService.verificar', () {
    test('envia app:control + build local e devolve info quando há update',
        () async {
      Map<String, dynamic>? enviado;
      final s = ActualizacaoService.comInvocador(
        buildLocal: () async => 21,
        invocar: (body) async {
          enviado = body;
          return {
            'actualizacao_disponivel': true,
            'versao_actual': '1.7.1',
            'build_number': 25,
            'url_download': 'https://exemplo/apk',
            'obrigatoria': false,
          };
        },
      );

      final info = await s.verificar();

      expect(enviado!['app'], 'control');
      expect(enviado!['build_number_local'], 21);
      expect(info, isNotNull);
      expect(info!.versaoActual, '1.7.1');
      expect(info.buildNumber, 25);
      expect(info.obrigatoria, isFalse);
    });

    test('actualizacao_disponivel:false → null', () async {
      final s = ActualizacaoService.comInvocador(
        buildLocal: () async => 24,
        invocar: (_) async => {'actualizacao_disponivel': false},
      );
      expect(await s.verificar(), isNull);
    });

    test('resposta null (sem sessão / inesperada) → null', () async {
      final s = ActualizacaoService.comInvocador(
        buildLocal: () async => 24,
        invocar: (_) async => null,
      );
      expect(await s.verificar(), isNull);
    });
  });
}
