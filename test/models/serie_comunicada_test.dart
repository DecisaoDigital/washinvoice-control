import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/models/serie_comunicada.dart';

void main() {
  group('SerieComunicada.fromJson', () {
    test('série comunicada com sucesso traz o ATCUD e comunicada=true', () {
      final s = SerieComunicada.fromJson({
        'id': 'uuid-1',
        'licenca_id': 'lic-1',
        'machine_id': 'mac-1',
        'serie': 'FTA2026',
        'tipo_doc': 'FT',
        'numero_inicial': 1,
        'data_inicio': '2026-07-22',
        'codigo_validacao': 'J6SHZMK5',
        'erro': null,
        'ambiente': 'testes',
        'feito_por': 'cesar@x.pt',
        'created_at': '2026-07-22T10:00:00.000Z',
      });

      expect(s.serie, 'FTA2026');
      expect(s.tipoDoc, 'FT');
      expect(s.codigoValidacao, 'J6SHZMK5');
      expect(s.erro, isNull);
      expect(s.comunicada, isTrue);
      expect(s.numeroInicial, 1);
      expect(s.ambiente, 'testes');
    });

    test('série com erro (sem código) → comunicada=false', () {
      final s = SerieComunicada.fromJson({
        'id': 'uuid-2',
        'licenca_id': 'lic-1',
        'machine_id': 'mac-1',
        'serie': 'NCA2026',
        'tipo_doc': 'NC',
        'numero_inicial': 1,
        'data_inicio': '2026-07-22',
        'codigo_validacao': null,
        'erro': 'Internal Error',
        'ambiente': 'testes',
        'created_at': '2026-07-22T10:00:00.000Z',
      });

      expect(s.comunicada, isFalse);
      expect(s.erro, 'Internal Error');
      expect(s.codigoValidacao, isNull);
      expect(s.feitoPor, isNull);
    });

    test('strings vazias/espaços são normalizadas para null', () {
      final s = SerieComunicada.fromJson({
        'id': 'uuid-3',
        'licenca_id': 'lic-1',
        'machine_id': 'mac-1',
        'serie': 'FSA2026',
        'tipo_doc': 'FS',
        'numero_inicial': 5,
        'data_inicio': '2026-07-22',
        'codigo_validacao': '   ',
        'erro': '',
        'ambiente': 'testes',
        'created_at': '2026-07-22T10:00:00.000Z',
      });

      expect(s.codigoValidacao, isNull);
      expect(s.erro, isNull);
      expect(s.comunicada, isFalse);
      expect(s.numeroInicial, 5);
    });
  });
}
