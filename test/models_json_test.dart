import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/models/cliente.dart';
import 'package:washinvoice_control/models/licenca.dart';

void main() {
  group('Licenca — toInsertJson / toUpdateJson', () {
    final l = Licenca(
      id: 'lic-1',
      clienteId: 'cli-1',
      machineId: 'demo-001',
      nif: '500000001',
      nome: 'Lavandaria Central',
      plano: 'anual',
      validade: DateTime(2027, 6, 27),
      activa: true,
      oferta: false,
      serie: 'FT-T1',
      criadoEm: DateTime(2026, 1, 1),
    );

    test('toInsertJson exclui id e created_at, inclui machine_id e campos', () {
      final j = l.toInsertJson();
      expect(j.containsKey('id'), isFalse);
      expect(j.containsKey('created_at'), isFalse);
      expect(j['machine_id'], 'demo-001');
      expect(j['nif'], '500000001');
      expect(j['plano'], 'anual');
      expect(j['activa'], true);
      expect(j['oferta'], false);
      expect(j['serie'], 'FT-T1');
    });

    test('toUpdateJson exclui id, created_at, machine_id e user_id', () {
      final j = l.toUpdateJson();
      expect(j.containsKey('id'), isFalse);
      expect(j.containsKey('created_at'), isFalse);
      expect(j.containsKey('machine_id'), isFalse); // identidade imutável
      expect(j.containsKey('user_id'), isFalse); // ligação imutável ao POS
      // Mas mantém os campos mutáveis (ex.: renovação muda validade/activa).
      expect(j['validade'], isNotNull);
      expect(j['activa'], true);
      expect(j['plano'], 'anual');
    });
  });

  group('Cliente — toInsertJson / toUpdateJson', () {
    final c = Cliente(
      id: 'cli-1',
      nif: '500000001',
      nome: 'Lavandaria Central',
      email: 'central@exemplo.pt',
      criadoEm: DateTime(2026, 1, 1),
    );

    test('toInsertJson exclui id e created_at', () {
      final j = c.toInsertJson();
      expect(j.containsKey('id'), isFalse);
      expect(j.containsKey('created_at'), isFalse);
      expect(j['nif'], '500000001');
      expect(j['nome'], 'Lavandaria Central');
    });

    test('toUpdateJson exclui id e created_at', () {
      final j = c.toUpdateJson();
      expect(j.containsKey('id'), isFalse);
      expect(j.containsKey('created_at'), isFalse);
      expect(j['nome'], 'Lavandaria Central');
    });
  });
}
