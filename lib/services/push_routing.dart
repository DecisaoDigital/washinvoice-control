import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Para onde levar o Cesar quando ele toca numa notificação.
///
/// - [agoraTerminalNovo]: separador «Agora», filtrado por «terminal novo».
/// - [agoraAjuda]: separador «Agora», filtrado por «pedido de ajuda».
/// - [pedidosFist]: «Pedidos Fist», que vive dentro de «Mais».
/// - [resumo]: o Resumo (antigo Dashboard), também dentro de «Mais».
enum DestinoPush { agoraTerminalNovo, agoraAjuda, pedidosFist, resumo }

/// Decide o destino a partir do payload `data` do push.
///
/// A chave é `data['tipo']`, escrita por quem envia o push (triggers DB e a
/// Edge Function `enviar-push`). `data['app']` **não** serve para isto: um
/// terminal novo e um pedido de acesso chegam ambos com `app: punho` e vivem
/// em tabelas — e ecrãs — diferentes. Foi essa confusão que mandou o "novo
/// terminal" para os Pedidos Fist, que estavam vazios.
///
/// Pushes antigos não trazem `tipo`. Nesse caso devolve `null`, e quem chama
/// não navega — o comportamento que a app tinha antes de haver routing. As
/// notificações que ainda estejam por abrir no telefone continuam a funcionar
/// como sempre funcionaram, em vez de irem parar a um ecrã ao calhas.
DestinoPush? destinoDoPush(Map<String, dynamic> data) {
  final tipo = (data['tipo'] as String?)?.trim().toLowerCase();
  return switch (tipo) {
    'novo_terminal' => DestinoPush.agoraTerminalNovo,
    'novo_pedido' => DestinoPush.pedidosFist,
    'pedido_ajuda' => DestinoPush.agoraAjuda,
    'inicio_actividade' => DestinoPush.resumo,
    _ => null,
  };
}

/// Destino pedido pelo último push tocado, à espera de ser executado.
///
/// Quem detecta o toque (`onMessageOpenedApp` / `getInitialMessage`, em
/// `main.dart`) escreve aqui; o `HomeShell` navega e volta a pôr a `null`.
/// O intermediário existe porque o push pode chegar antes de haver árvore de
/// navegação montada — com a app fechada, `getInitialMessage()` resolve-se
/// enquanto ainda estamos no splash.
final destinoPushProvider = StateProvider<DestinoPush?>((_) => null);
