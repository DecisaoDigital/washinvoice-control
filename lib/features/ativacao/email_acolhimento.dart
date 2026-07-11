import '../../core/config.dart';

/// Email de acolhimento enviado a uma instalação nova. Construção pura (sem
/// UI) para ser testável. Interpola os contactos de [Config] — nunca duplicar
/// email/telefone/nome no texto.

const String assuntoAcolhimento = 'WashInvoice — Bem-vindo e próximos passos';

/// Corpo do email. O parágrafo da landing page só aparece quando
/// [Config.urlPagamento] deixar de ser vazio — sem tocar no template.
String corpoAcolhimento() {
  return 'Olá,\n\n'
      'Obrigado por instalar o WashInvoice na sua lavandaria/engomadoria.\n\n'
      'O WashInvoice é um POS pensado especificamente para o dia-a-dia deste '
      'setor — faturação certificada, controlo de caixa, entregas e '
      'indicadores que o ajudam a perceber onde ganha e onde perde dinheiro no '
      'seu negócio. Feito à medida por quem conhece as lavandarias, não uma '
      'solução genérica adaptada.\n\n'
      'Detetámos o seu interesse em instalar o nosso software de faturação. '
      'Para finalizarmos a ativação da licença basta trocarmos algumas '
      'informações consigo — pode responder diretamente a este email ou usar '
      'os contactos abaixo.\n\n'
      '${Config.urlPagamento.isNotEmpty ? 'Pode também consultar os planos disponíveis em ${Config.urlPagamento}.\n\n' : ''}'
      'Ficamos ao dispor para qualquer dúvida.\n\n'
      'Com os melhores cumprimentos,\n\n'
      '${Config.nomeContacto}\n'
      '${Config.marca}\n'
      'Email: ${Config.emailContacto}\n'
      'Telefone: ${Config.telefoneContacto}';
}
