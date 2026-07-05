import 'package:intl/intl.dart';

class Dates {
  Dates._();

  static String data(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  static String dataHora(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);
}
