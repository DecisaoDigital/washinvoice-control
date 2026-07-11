/// Configuração estática da aplicação — fonte única de verdade para valores
/// que antes estavam espalhados/hardcoded no código dos ecrãs.
///
/// Escolha (R1): constantes Dart, **não** `--dart-define`. Suporte
/// multi-ambiente foi explicitamente considerado overkill nesta fase.
class Config {
  Config._();

  static const String nomeContacto = 'Cesar Mendes';
  static const String emailContacto = 'cesarmendes78@gmail.com';
  static const String telefoneContacto = '914 353 752';
  static const String marca = 'WashInvoice';

  /// Landing page de pagamento — vazio enquanto não existir.
  /// TODO: quando existir, actualizar aqui e reactivar a linha condicional
  /// no corpo do email de acolhimento (ver `email_acolhimento.dart`).
  static const String urlPagamento = '';
}
