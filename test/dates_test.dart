import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:washinvoice_control/core/dates.dart';

void main() {
  group('Dates.data / dataHora — converte UTC para hora local', () {
    // Regressão do bug do card "Último acesso": `created_at` chega em UTC
    // (isUtc = true) e era formatado sem `.toLocal()`, mostrando 1h a menos
    // no verão (WEST = UTC+1). O runner do CI pode estar em qualquer timezone,
    // por isso os testes comparam contra a hora local calculada em tempo de
    // execução em vez de contra uma string fixa.
    final utc = DateTime.utc(2026, 7, 22, 10, 56);
    final offsetLocal = utc.toLocal().timeZoneOffset;

    test('dataHora formata a hora local, não a UTC', () {
      final esperado = DateFormat('dd/MM/yyyy HH:mm').format(utc.toLocal());
      expect(Dates.dataHora(utc), esperado);
    });

    test('data formata o dia local, não o UTC', () {
      final esperado = DateFormat('dd/MM/yyyy').format(utc.toLocal());
      expect(Dates.data(utc), esperado);
    });

    test('num runner com offset != 0, NÃO mostra a hora UTC crua (apanha '
        'regressão que remova o .toLocal())', () {
      if (offsetLocal == Duration.zero) {
        // Runner em UTC: local == UTC, não há nada para distinguir. Documentado.
        return;
      }
      expect(Dates.dataHora(utc), isNot('22/07/2026 10:56'));
    });

    test('idempotente: DateTime já local passa incólume', () {
      final local = DateTime(2026, 7, 22, 11, 56);
      expect(Dates.dataHora(local), '22/07/2026 11:56');
      expect(Dates.data(local), '22/07/2026');
    });

    test('exemplo do bug: UTC 10:56 em WEST (UTC+1) → 11:56', () {
      // Só assere o valor concreto quando o runner está mesmo em UTC+1,
      // que é o ambiente do Cesar (Portugal, verão).
      if (offsetLocal != const Duration(hours: 1)) return;
      expect(Dates.dataHora(utc), '22/07/2026 11:56');
    });
  });


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
