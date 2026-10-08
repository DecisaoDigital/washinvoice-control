/// «Cliente · série X», o que vai no título das confirmações destrutivas para
/// dizer a *quem* se aplicam. Sem série, só o cliente.
String quemTitulo(String cliente, {String? serie}) {
  final s = serie?.trim() ?? '';
  return s.isEmpty ? cliente : '$cliente · série $s';
}
