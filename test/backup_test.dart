import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/csv.dart';

void main() {
  group('Csv.campo (escape)', () {
    test('campo simples fica igual', () {
      expect(Csv.campo('Lisboa'), 'Lisboa');
    });
    test('vírgula → envolve em aspas', () {
      expect(Csv.campo('a,b'), '"a,b"');
    });
    test('aspas → duplica e envolve', () {
      expect(Csv.campo('disse "olá"'), '"disse ""olá"""');
    });
    test('quebra de linha → envolve em aspas', () {
      expect(Csv.campo('linha1\nlinha2'), '"linha1\nlinha2"');
    });
    test('null → vazio', () {
      expect(Csv.campo(null), '');
    });
  });

  group('Csv.documento', () {
    test('cabeçalho + linhas com CRLF', () {
      final doc = Csv.documento(
        ['nome', 'nif'],
        [
          ['Loja, X', '500000009'],
          ['Outra', null],
        ],
      );
      expect(doc, 'nome,nif\r\n"Loja, X",500000009\r\nOutra,\r\n');
    });
  });

  group('Csv.bytes', () {
    test('começa com BOM UTF-8 e mantém acentos', () {
      final bytes = Csv.bytes('Bragança');
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bytes.sublist(3)), 'Bragança');
    });
  });
}
