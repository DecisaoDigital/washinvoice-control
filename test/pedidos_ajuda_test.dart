import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/models/pedido_ajuda.dart';

void main() {
  group('PedidoAjuda (model)', () {
    test('fromJson aberto → resolvido false, duracao null', () {
      final p = PedidoAjuda.fromJson({
        'id': '1',
        'machine_id': 'm1',
        'nif': '500000009',
        'cliente_id': null,
        'criado_em': '2026-07-01T10:00:00Z',
        'resolvido_em': null,
        'notas': null,
      });
      expect(p.resolvido, isFalse);
      expect(p.duracao, isNull);
    });

    test('fromJson resolvido → resolvido true, duracao correcta', () {
      final p = PedidoAjuda.fromJson({
        'id': '1',
        'machine_id': 'm1',
        'criado_em': '2026-07-01T10:00:00Z',
        'resolvido_em': '2026-07-01T12:00:00Z',
      });
      expect(p.resolvido, isTrue);
      expect(p.duracao, const Duration(hours: 2));
    });

    test('marcar resolvido inverte o estado (copyWith)', () {
      final aberto = PedidoAjuda(
        id: '1',
        machineId: 'm1',
        criadoEm: DateTime.utc(2026, 7, 1, 10),
      );
      expect(aberto.resolvido, isFalse);

      final resolvido =
          aberto.copyWith(resolvidoEm: DateTime.utc(2026, 7, 1, 11));
      expect(resolvido.resolvido, isTrue);
      expect(resolvido.duracao, const Duration(hours: 1));
    });
  });
}
