import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/models/sugestao.dart';

void main() {
  group('Sugestao (model)', () {
    test('fromJson usa defaults false para flags ausentes', () {
      final s = Sugestao.fromJson({
        'id': '1',
        'machine_id': 'm1',
        'nif': '500000009',
        'cliente_id': null,
        'texto': 'Seria útil um botão de reimpressão.',
        'criado_em': '2026-07-01T10:00:00Z',
      });
      expect(s.texto, 'Seria útil um botão de reimpressão.');
      expect(s.lida, isFalse);
      expect(s.marcada, isFalse);
      expect(s.arquivada, isFalse);
    });

    test('marcar lida', () {
      final s = _nova();
      expect(s.copyWith(lida: true).lida, isTrue);
    });

    test('marcar/desmarcar (toggle marcada)', () {
      final s = _nova();
      final marcada = s.copyWith(marcada: true);
      expect(marcada.marcada, isTrue);
      expect(marcada.copyWith(marcada: false).marcada, isFalse);
    });

    test('arquivar marca arquivada e lida', () {
      final s = _nova();
      final arquivada = s.copyWith(arquivada: true, lida: true);
      expect(arquivada.arquivada, isTrue);
      expect(arquivada.lida, isTrue);
    });
  });
}

Sugestao _nova() => Sugestao(
      id: '1',
      texto: 'texto',
      criadoEm: DateTime.utc(2026, 7, 1, 10),
    );
