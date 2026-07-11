import 'package:intl/intl.dart';

class Dates {
  Dates._();

  static String data(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  static String dataHora(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);

  /// Soma [meses] a [base] com **regra de fim de mês**: mantém o mesmo dia se
  /// existir no mês de destino; senão devolve o **último dia** desse mês.
  ///
  /// Ao contrário de `DateTime(ano, mes + meses, dia)`, que transborda para o
  /// mês seguinte (ex.: 31 Jan + 1 → 2/3 Mar), esta função nunca salta de mês:
  ///   31 Jan + 1 → 28 Fev (29 em ano bissexto)
  ///   30 Mar + 1 → 30 Abr    31 Mai + 1 → 30 Jun    15 Jan + 12 → 15 Jan (+1 ano)
  ///
  /// Preserva a hora/minuto de [base]. Função pura (não depende de `now()`).
  static DateTime adicionarMeses(DateTime base, int meses) {
    final totalMeses = base.month - 1 + meses;
    final ano = base.year + (totalMeses ~/ 12);
    final mes = totalMeses % 12 + 1;
    // Dia 0 do mês seguinte = último dia do mês de destino.
    final ultimoDia = DateTime(ano, mes + 1, 0).day;
    final dia = base.day < ultimoDia ? base.day : ultimoDia;
    return DateTime(ano, mes, dia, base.hour, base.minute);
  }
}
