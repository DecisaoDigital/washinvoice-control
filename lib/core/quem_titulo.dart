/// «Cliente · série X», o que vai no título das confirmações destrutivas para
/// dizer a *quem* se aplicam.
///
/// O terminal identifica-se sempre: pela série, quando existir; senão pelos
/// primeiros 6 caracteres do `machine_id` («terminal 8a0f8c»). Um cliente com
/// dois terminais sem série ficaria, de outro modo, com títulos iguais.
String quemTitulo(String cliente, {String? serie, String? machineId}) {
  final s = serie?.trim() ?? '';
  if (s.isNotEmpty) return '$cliente · série $s';
  final m = machineId?.trim() ?? '';
  if (m.isEmpty) return cliente;
  return '$cliente · terminal ${m.length > 6 ? m.substring(0, 6) : m}';
}
