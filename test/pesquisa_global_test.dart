import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/pesquisa/pesquisa_global_screen.dart';
import 'package:washinvoice_control/models/cliente.dart';
import 'package:washinvoice_control/models/licenca.dart';
import 'package:washinvoice_control/models/pedido_ajuda.dart';
import 'package:washinvoice_control/models/ping.dart';
import 'package:washinvoice_control/models/sugestao.dart';
import 'package:washinvoice_control/repositories/clientes_repository.dart';
import 'package:washinvoice_control/repositories/licencas_repository.dart';
import 'package:washinvoice_control/repositories/pedidos_ajuda_repository.dart';
import 'package:washinvoice_control/repositories/pings_repository.dart';
import 'package:washinvoice_control/repositories/providers.dart';
import 'package:washinvoice_control/repositories/sugestoes_repository.dart';

class _FakeClientes extends ClientesRepository {
  @override
  Future<List<Cliente>> listar() async => [
        Cliente(
            id: 'c1', nif: '512345678', nome: 'Lavandaria abc',
            criadoEm: DateTime(2026)),
        Cliente(
            id: 'c2', nif: '999999999', nome: 'Outra Loja',
            criadoEm: DateTime(2026)),
      ];
}

class _FakeLicencas extends LicencasRepository {
  @override
  Future<List<Licenca>> listar({String? app}) async => [];
}

class _FakePings extends PingsRepository {
  @override
  Future<List<Ping>> ultimosPorInstalacao({String? app}) async => [];
}

class _FakePedidosAjuda extends PedidosAjudaRepository {
  @override
  Future<List<PedidoAjuda>> listarAbertos({String? app}) async => [];
  @override
  Future<List<PedidoAjuda>> listarHistorico({String? app}) async => [];
}

class _FakeSugestoes extends SugestoesRepository {
  @override
  Future<List<Sugestao>> listarPorLer({String? app}) async => [];
  @override
  Future<List<Sugestao>> listarArquivo({String? app}) async => [];
}

void main() {
  Widget app() => ProviderScope(
        overrides: [
          clientesRepoProvider.overrideWithValue(_FakeClientes()),
          licencasRepoProvider.overrideWithValue(_FakeLicencas()),
          pingsRepoProvider.overrideWithValue(_FakePings()),
          pedidosAjudaRepoProvider.overrideWithValue(_FakePedidosAjuda()),
          sugestoesRepoProvider.overrideWithValue(_FakeSugestoes()),
        ],
        child: const MaterialApp(home: PesquisaGlobalScreen()),
      );

  testWidgets('estado inicial pede para escrever', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('Escreve para procurar'), findsOneWidget);
  });

  testWidgets('procurar "abc" agrupa em Clientes (1)', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'abc');
    // Passa o debounce (250ms).
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Clientes (1)'), findsOneWidget);
    expect(find.text('Lavandaria abc'), findsOneWidget);
    expect(find.text('Outra Loja'), findsNothing);
  });

  testWidgets('sem resultados mostra mensagem', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nada encontrado'), findsOneWidget);
  });
}
