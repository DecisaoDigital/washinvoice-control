import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/models/actualizacao_info.dart';

void main() {
  group('ActualizacaoInfo.fromJson', () {
    test('lê todos os campos, incluindo notas', () {
      final info = ActualizacaoInfo.fromJson({
        'actualizacao_disponivel': true,
        'versao_actual': '1.7.1',
        'build_number': 25,
        'url_download': 'https://exemplo/apk',
        'obrigatoria': true,
        'notas_lancamento': 'Corrige X.',
      });

      expect(info.versaoActual, '1.7.1');
      expect(info.buildNumber, 25);
      expect(info.urlDownload, 'https://exemplo/apk');
      expect(info.obrigatoria, isTrue);
      expect(info.notasLancamento, 'Corrige X.');
    });

    test('sem notas_lancamento → null; obrigatoria em falta → false', () {
      final info = ActualizacaoInfo.fromJson({
        'versao_actual': '1.7.0',
        'build_number': 24,
        'url_download': 'https://exemplo/apk',
      });

      expect(info.notasLancamento, isNull);
      expect(info.obrigatoria, isFalse);
    });

    test('lê o sha256 quando o catálogo o publica', () {
      final info = ActualizacaoInfo.fromJson({
        'versao_actual': '1.8.6',
        'build_number': 31,
        'url_download': 'https://exemplo/apk',
        'sha256': 'abc123',
      });

      expect(info.sha256, 'abc123');
    });

    test('uma resposta antiga sem sha256 não rebenta a leitura', () {
      // O servidor pode ser mais antigo do que a app. Falta de campo é
      // ausência de instalação automática, não erro.
      final info = ActualizacaoInfo.fromJson({
        'versao_actual': '1.7.0',
        'build_number': 24,
        'url_download': 'https://exemplo/apk',
      });

      expect(info.sha256, isNull);
    });
  });
}
