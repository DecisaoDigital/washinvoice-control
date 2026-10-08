import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/quem_titulo.dart';

void main() {
  test('com série: cliente · série X', () {
    expect(quemTitulo('Lavandaria Sol', serie: 'A1', machineId: '8a0f8c1234'),
        'Lavandaria Sol · série A1');
  });
  test('sem série: 6 primeiros caracteres do machine_id', () {
    expect(quemTitulo('Lavandaria Sol', machineId: '8a0f8c1234'),
        'Lavandaria Sol · terminal 8a0f8c');
    expect(quemTitulo('Lavandaria Sol', serie: '  ', machineId: '8a0f8c1234'),
        'Lavandaria Sol · terminal 8a0f8c');
  });
  test('machine_id curto ou ausente', () {
    expect(quemTitulo('X', machineId: 'abc'), 'X · terminal abc');
    expect(quemTitulo('X'), 'X');
  });
}
