import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/services/push_titulo.dart';

void main() {
  group('tituloComApp', () {
    test('app punho → prefixo [PUNHO]', () {
      expect(tituloComApp('Novo terminal XYZ', 'punho'),
          '[PUNHO] Novo terminal XYZ');
    });

    test('app pos → prefixo [POS]', () {
      expect(tituloComApp('Novo terminal ABC', 'pos'),
          '[POS] Novo terminal ABC');
    });

    test('sem app (push antigo) → título intacto, sem prefixo vazio', () {
      // Retro-compatibilidade: os pushes anteriores à multi-app não trazem
      // `data['app']` e não podem ficar com "[] Novo terminal".
      expect(tituloComApp('Novo terminal', null), 'Novo terminal');
      expect(tituloComApp('Novo terminal', ''), 'Novo terminal');
      expect(tituloComApp('Novo terminal', '   '), 'Novo terminal');
    });

    test('app desconhecida usa o próprio valor em maiúsculas', () {
      expect(tituloComApp('Olá', 'lavandaria'), '[LAVANDARIA] Olá');
    });
  });
}
