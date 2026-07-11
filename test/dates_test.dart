import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/dates.dart';

void main() {
  group('Dates.adicionarMeses — regra de fim de mês', () {
    test('31 Jan + 1 mês → 28 Fev (ano não bissexto)', () {
      final r = Dates.adicionarMeses(DateTime(2023, 1, 31), 1);
      expect(r, DateTime(2023, 2, 28));
    });

    test('31 Jan + 1 mês → 29 Fev (ano bissexto)', () {
      final r = Dates.adicionarMeses(DateTime(2024, 1, 31), 1);
      expect(r, DateTime(2024, 2, 29));
    });

    test('30 Mar + 1 mês → 30 Abr (dia existe)', () {
      final r = Dates.adicionarMeses(DateTime(2024, 3, 30), 1);
      expect(r, DateTime(2024, 4, 30));
    });

    test('31 Mai + 1 mês → 30 Jun', () {
      final r = Dates.adicionarMeses(DateTime(2024, 5, 31), 1);
      expect(r, DateTime(2024, 6, 30));
    });

    test('15 Jan + 12 meses → 15 Jan do ano seguinte', () {
      final r = Dates.adicionarMeses(DateTime(2024, 1, 15), 12);
      expect(r, DateTime(2025, 1, 15));
    });

    test('31 Dez + 2 meses → 28 Fev (cruza ano + fim de mês)', () {
      final r = Dates.adicionarMeses(DateTime(2024, 12, 31), 2);
      expect(r, DateTime(2025, 2, 28));
    });

    test('não transborda para o mês seguinte (não repete o bug antigo)', () {
      // O código antigo DateTime(2024,2,31) dava 2 de Março. Aqui nunca.
      final r = Dates.adicionarMeses(DateTime(2024, 1, 31), 1);
      expect(r.month, 2);
    });

    test('preserva hora e minuto', () {
      final r = Dates.adicionarMeses(DateTime(2024, 1, 31, 14, 30), 1);
      expect(r, DateTime(2024, 2, 29, 14, 30));
    });
  });
}
