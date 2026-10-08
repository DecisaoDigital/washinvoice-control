import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/services/push_routing.dart';

void main() {
  group('destinoDoPush', () {
    test('novo_terminal vai ao «Agora» filtrado por terminal novo', () {
      // O bug de 2026-07-28: a linha foi para `licencas` e o Cesar aterrou
      // numa lista de pedidos vazia.
      expect(
        destinoDoPush({'tipo': 'novo_terminal', 'app': 'punho'}),
        DestinoPush.agoraTerminalNovo,
      );
    });

    test('novo_pedido vai aos Pedidos Fist', () {
      expect(
        destinoDoPush({'tipo': 'novo_pedido', 'app': 'punho'}),
        DestinoPush.pedidosFist,
      );
    });

    test('pedido_ajuda vai ao «Agora» filtrado por ajuda', () {
      expect(
        destinoDoPush({'tipo': 'pedido_ajuda'}),
        DestinoPush.agoraAjuda,
      );
    });

    test('inicio_actividade vai ao Resumo', () {
      expect(
        destinoDoPush({'tipo': 'inicio_actividade'}),
        DestinoPush.resumo,
      );
    });

    test('a mesma app com tipos diferentes dá destinos diferentes', () {
      // A razão de ser desta função: `app` sozinho não chega para decidir.
      final terminal = destinoDoPush({'tipo': 'novo_terminal', 'app': 'punho'});
      final pedido = destinoDoPush({'tipo': 'novo_pedido', 'app': 'punho'});
      expect(terminal, isNot(pedido));
    });

    test('push antigo sem tipo não navega', () {
      // Retro-compatibilidade: notificações ainda por abrir no telefone do
      // Cesar continuam a comportar-se como antes.
      expect(destinoDoPush({'app': 'punho'}), isNull);
      expect(destinoDoPush(const {}), isNull);
    });

    test('tipo desconhecido não navega, em vez de ir ao calhas', () {
      expect(destinoDoPush({'tipo': 'coisa_nova_do_futuro'}), isNull);
    });

    test('tipo tolera espaços e maiúsculas', () {
      expect(
        destinoDoPush({'tipo': '  Novo_Terminal '}),
        DestinoPush.agoraTerminalNovo,
      );
    });
  });
}
