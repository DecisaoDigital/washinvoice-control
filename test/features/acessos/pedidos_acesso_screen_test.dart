import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/acessos/pedidos_acesso_screen.dart';
import 'package:washinvoice_control/repositories/acessos_repository.dart';
import 'package:washinvoice_control/repositories/providers.dart';

PedidoAcesso _pedido({
  String id = 'p1',
  String nome = 'Ana Silva',
  String email = 'ana@exemplo.pt',
  String organizacao = 'Lavandaria Central',
  String? organizacaoId,
  String cargo = 'funcionario',
  String origem = 'livre',
  String estado = 'pendente',
}) =>
    PedidoAcesso.fromJson({
      'id': id,
      'nome': nome,
      'email': email,
      'organizacao_indicada': organizacao,
      'organizacao_id': organizacaoId,
      'cargo': cargo,
      'origem': origem,
      'estado': estado,
      'criado_em': '2026-07-20T10:00:00Z',
    });

OrganizacaoAcesso _org({String id = 'o1', String nome = 'Lavandaria Central', int limite = 2}) =>
    OrganizacaoAcesso.fromJson({'id': id, 'nome': nome, 'limite_utilizadores': limite});

/// Fake do repositório: regista as decisões tomadas para as podermos verificar.
class _FakeAcessos extends AcessosRepository {
  final List<PedidoAcesso> pendentes;
  final List<PedidoAcesso> aprovados;
  final List<OrganizacaoAcesso> organizacoes;
  final decisoes = <List<String?>>[];

  _FakeAcessos({
    this.pendentes = const [],
    this.aprovados = const [],
    this.organizacoes = const [],
  });

  @override
  Future<List<PedidoAcesso>> listarPendentes() async => pendentes;
  @override
  Future<List<PedidoAcesso>> listarAprovados() async => aprovados;
  @override
  Future<List<OrganizacaoAcesso>> listarOrganizacoes() async => organizacoes;
  @override
  Future<void> decidir(String id, String decisao, {String? organizacaoId}) async {
    decisoes.add([id, decisao, organizacaoId]);
  }
}

Future<void> _montar(WidgetTester tester, _FakeAcessos fake) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [acessosRepoProvider.overrideWithValue(fake)],
    child: const MaterialApp(home: PedidosAcessoScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('AcessosVista — ocupação e limites', () {
    test('conta apenas aprovados da organização', () {
      final v = AcessosVista(
        pendentes: [_pedido()],
        aprovados: [
          _pedido(id: 'a1', organizacaoId: 'o1', estado: 'aprovado'),
          _pedido(id: 'a2', organizacaoId: 'o1', estado: 'aprovado'),
          _pedido(id: 'a3', organizacaoId: 'o2', estado: 'aprovado'),
        ],
        organizacoes: [_org(limite: 3), _org(id: 'o2', nome: 'Outra', limite: 1)],
      );

      expect(v.ativos('o1'), 2);
      expect(v.ativos('o2'), 1);
      expect(v.ocupacaoTexto('o1'), '2 / 3');
      expect(v.ocupacaoTexto('o2'), '1 / 1');
    });

    test('pedido sem organização não tem ocupação nem limite atingido', () {
      final v = AcessosVista(pendentes: const [], aprovados: const [], organizacoes: [_org()]);
      expect(v.ativos(null), 0);
      expect(v.ocupacaoTexto(null), isNull);
      expect(v.limiteAtingido(null), isFalse);
    });

    test('limite atingido quando os aprovados igualam o limite', () {
      final v = AcessosVista(
        pendentes: const [],
        aprovados: [_pedido(id: 'a1', organizacaoId: 'o1', estado: 'aprovado')],
        organizacoes: [_org(limite: 1)],
      );
      expect(v.limiteAtingido('o1'), isTrue);
    });

    test('abaixo do limite não bloqueia', () {
      final v = AcessosVista(
        pendentes: const [],
        aprovados: [_pedido(id: 'a1', organizacaoId: 'o1', estado: 'aprovado')],
        organizacoes: [_org(limite: 2)],
      );
      expect(v.limiteAtingido('o1'), isFalse);
    });
  });

  group('Ecrã de acessos', () {
    testWidgets('mostra origem e ocupação de um pedido por convite', (tester) async {
      await _montar(tester, _FakeAcessos(
        pendentes: [_pedido(origem: 'convite', organizacaoId: 'o1')],
        aprovados: [_pedido(id: 'a1', organizacaoId: 'o1', estado: 'aprovado')],
        organizacoes: [_org(limite: 3)],
      ));

      expect(find.textContaining('Por convite'), findsOneWidget);
      expect(find.text('Ocupação: 1 / 3'), findsWidgets);
      // Origem por convite conserva a organização: sem selector de organização.
      expect(find.byType(DropdownButtonFormField<String?>), findsNothing);
    });

    testWidgets('pedido livre permite escolher organização e aprovar', (tester) async {
      final fake = _FakeAcessos(
        pendentes: [_pedido(origem: 'livre')],
        organizacoes: [_org(limite: 3)],
      );
      await _montar(tester, fake);

      expect(find.textContaining('Pedido livre'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);

      await tester.tap(find.text('Aprovar'));
      await tester.pumpAndSettle();

      // Sem escolha explícita, aprova com organização nula => cria uma nova.
      expect(fake.decisoes, [['p1', 'aprovado', null]]);
    });

    testWidgets('avisa quando a organização escolhida está no limite', (tester) async {
      await _montar(tester, _FakeAcessos(
        pendentes: [_pedido(origem: 'convite', organizacaoId: 'o1')],
        aprovados: [_pedido(id: 'a1', organizacaoId: 'o1', estado: 'aprovado')],
        organizacoes: [_org(limite: 1)],
      ));

      expect(find.textContaining('Limite de utilizadores atingido'), findsOneWidget);
    });

    testWidgets('recusar não associa organização', (tester) async {
      final fake = _FakeAcessos(
        pendentes: [_pedido(origem: 'livre')],
        organizacoes: [_org()],
      );
      await _montar(tester, fake);

      await tester.tap(find.text('Recusar'));
      await tester.pumpAndSettle();

      expect(fake.decisoes, [['p1', 'recusado', null]]);
    });

    testWidgets('revogar uma conta aprovada exige confirmação', (tester) async {
      final fake = _FakeAcessos(
        aprovados: [_pedido(id: 'a1', organizacaoId: 'o1', estado: 'aprovado')],
        organizacoes: [_org(limite: 2)],
      );
      await _montar(tester, fake);

      expect(find.text('Não há pedidos pendentes.'), findsOneWidget);

      await tester.tap(find.text('Revogar'));
      await tester.pumpAndSettle();
      // Diálogo aberto, nada decidido ainda.
      expect(fake.decisoes, isEmpty);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(fake.decisoes, isEmpty);

      await tester.tap(find.text('Revogar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Revogar'));
      await tester.pumpAndSettle();

      expect(fake.decisoes, [['a1', 'revogado', null]]);
    });

    testWidgets('sem pedidos nem contas mostra as duas mensagens vazias', (tester) async {
      await _montar(tester, _FakeAcessos());
      expect(find.text('Não há pedidos pendentes.'), findsOneWidget);
      expect(find.text('Ainda não há contas aprovadas.'), findsOneWidget);
    });
  });
}
