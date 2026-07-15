import 'dart:convert';
import 'dart:typed_data';

/// Geração de CSV compatível com Excel (UTF-8 com BOM, separador vírgula,
/// terminador de linha CRLF, escape de aspas/vírgulas/quebras de linha).
class Csv {
  Csv._();

  /// Escapa um campo: envolve em aspas se contiver `,`, `"`, `\n` ou `\r`;
  /// duplica as aspas interiores. `null` → campo vazio.
  static String campo(Object? valor) {
    final s = valor?.toString() ?? '';
    if (s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// Documento CSV (cabeçalho + linhas) como texto.
  static String documento(List<String> cabecalho, List<List<Object?>> linhas) {
    final buffer = StringBuffer();
    buffer.write(cabecalho.map(campo).join(','));
    buffer.write('\r\n');
    for (final linha in linhas) {
      buffer.write(linha.map(campo).join(','));
      buffer.write('\r\n');
    }
    return buffer.toString();
  }

  /// Bytes UTF-8 com BOM (para o Excel abrir os acentos correctamente).
  static Uint8List bytes(String documentoCsv) {
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(documentoCsv)]);
  }
}
