import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/localidades.dart';

void main() {
  group('Localidades.traduzir', () {
    test('EN conhecido → PT', () {
      expect(Localidades.traduzir('Lisbon'), 'Lisboa');
      expect(Localidades.traduzir('Oporto'), 'Porto');
    });

    test('já em PT / desconhecido → devolve o próprio', () {
      expect(Localidades.traduzir('Porto'), 'Porto');
      expect(Localidades.traduzir('Palmela'), 'Palmela');
    });

    test('null/vazio → string vazia', () {
      expect(Localidades.traduzir(null), '');
      expect(Localidades.traduzir('   '), '');
    });

    test('faz trim antes de traduzir', () {
      expect(Localidades.traduzir('  Lisbon  '), 'Lisboa');
    });
  });
}
