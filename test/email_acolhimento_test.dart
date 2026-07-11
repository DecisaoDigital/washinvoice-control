import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/config.dart';
import 'package:washinvoice_control/features/ativacao/email_acolhimento.dart';

void main() {
  group('Email de acolhimento', () {
    test('assunto é o de boas-vindas', () {
      expect(assuntoAcolhimento, contains('Bem-vindo e próximos passos'));
    });

    test('corpo interpola os contactos (não hardcoded)', () {
      final corpo = corpoAcolhimento();
      expect(corpo, contains(Config.emailContacto));
      expect(corpo, contains(Config.telefoneContacto));
      expect(corpo, contains(Config.nomeContacto));
    });

    test('corpo já não fala de pagamento (texto legado removido)', () {
      final corpo = corpoAcolhimento().toLowerCase();
      expect(corpo, isNot(contains('iban')));
      expect(corpo, isNot(contains('instruções de pagamento')));
    });

    test('sem landing page: parágrafo condicional ausente e sem placeholder',
        () {
      final corpo = corpoAcolhimento();
      // urlPagamento vazio → o parágrafo não entra e não fica o literal.
      expect(Config.urlPagamento, isEmpty);
      expect(corpo, isNot(contains(r'${Config.urlPagamento}')));
      expect(corpo, isNot(contains('planos disponíveis em')));
    });
  });
}
