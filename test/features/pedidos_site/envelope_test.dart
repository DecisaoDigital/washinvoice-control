import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/pedidos_site/envelope_pedidos_site.dart';
import 'package:washinvoice_control/repositories/pedidos_site_repository.dart';
import 'package:washinvoice_control/repositories/providers.dart';
import 'package:washinvoice_control/services/push_titulo.dart';

Widget _app(List<PedidoSiteAviso> avisos) => ProviderScope(
      overrides: [
        pedidosSitePorVerProvider.overrideWith((_) async => avisos),
      ],
      child: const MaterialApp(
        home: Scaffold(body: Center(child: EnvelopePedidosSite())),
      ),
    );

void main() {
  testWidgets('sem pedidos: sem contador', (t) async {
    await t.pumpWidget(_app(const []));
    await t.pumpAndSettle();
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('com pedidos: contador e lista de refs', (t) async {
    final agora = DateTime.now();
    await t.pumpWidget(_app([
      PedidoSiteAviso(ref: 'ABCDE2', criadoEm: agora),
      PedidoSiteAviso(ref: 'FGHJK3', criadoEm: agora),
    ]));
    await t.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    expect(find.text('ABCDE2'), findsOneWidget);
    expect(find.text('Marcar como vista'), findsNWidgets(2));
  });

  test('push do site não leva segundo prefixo', () {
    expect(tituloComApp('✉ Novo pedido ABCDE2', 'decisaodigital'),
        '✉ Novo pedido ABCDE2');
    expect(tituloComApp('x', 'pos'), startsWith('['));
  });
}
