import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:washinvoice_control/features/sugestoes/detalhe_sugestao_screen.dart';
import 'package:washinvoice_control/models/cliente.dart';
import 'package:washinvoice_control/models/licenca.dart';
import 'package:washinvoice_control/models/ping.dart';
import 'package:washinvoice_control/models/sugestao.dart';
import 'package:washinvoice_control/repositories/clientes_repository.dart';
import 'package:washinvoice_control/repositories/licencas_repository.dart';
import 'package:washinvoice_control/repositories/pings_repository.dart';
import 'package:washinvoice_control/repositories/providers.dart';
import 'package:washinvoice_control/repositories/sugestoes_repository.dart';

class _FakeClientes extends ClientesRepository {
  @override
  Future<List<Cliente>> listar() async => [];
}

class _FakeLicencas extends LicencasRepository {
  @override
  Future<List<Licenca>> listar({String? app}) async => [];
}

class _FakePings extends PingsRepository {
  @override
  Future<List<Ping>> ultimosPorInstalacao({String? app}) async => [];
}

class _FakeSugestoes extends SugestoesRepository {
  final List<(String, bool)> marcadas = [];
  final List<String> arquivadas = [];
  @override
  Future<void> marcarMarcada(String id, bool valor) async =>
      marcadas.add((id, valor));
  @override
  Future<void> arquivar(String id) async => arquivadas.add(id);
}

void main() {
  setUpAll(() => timeago.setLocaleMessages('pt', timeago.PtBrMessages()));

  testWidgets('DetalheSugestao mostra o texto e marca como importante',
      (tester) async {
    final fakeSug = _FakeSugestoes();
    final sugestao = Sugestao(
      id: 's1',
      machineId: 'm1',
      nif: '512345678',
      texto: 'Seria útil um botão de reimpressão de talões.',
      criadoEm: DateTime.now().subtract(const Duration(hours: 1)),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        clientesRepoProvider.overrideWithValue(_FakeClientes()),
        licencasRepoProvider.overrideWithValue(_FakeLicencas()),
        pingsRepoProvider.overrideWithValue(_FakePings()),
        sugestoesRepoProvider.overrideWithValue(fakeSug),
      ],
      child: MaterialApp(home: DetalheSugestaoScreen(sugestao: sugestao)),
    ));
    await tester.pumpAndSettle();

    // Texto integral visível.
    expect(find.textContaining('reimpressão de talões'), findsOneWidget);
    // Chip "Por ler" (lida = false).
    expect(find.text('Por ler'), findsOneWidget);

    // Marcar como importante → chama o repo.
    await tester.tap(find.text('Marcar como importante'));
    await tester.pump();
    expect(fakeSug.marcadas, [('s1', true)]);
    // O botão passa a "Desmarcar".
    expect(find.text('Desmarcar'), findsOneWidget);
  });

  testWidgets('DetalheSugestao arquiva', (tester) async {
    final fakeSug = _FakeSugestoes();
    final sugestao = Sugestao(
      id: 's2',
      machineId: 'm2',
      nif: '512345678',
      texto: 'Outra ideia.',
      criadoEm: DateTime.now(),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        clientesRepoProvider.overrideWithValue(_FakeClientes()),
        licencasRepoProvider.overrideWithValue(_FakeLicencas()),
        pingsRepoProvider.overrideWithValue(_FakePings()),
        sugestoesRepoProvider.overrideWithValue(fakeSug),
      ],
      child: MaterialApp(home: DetalheSugestaoScreen(sugestao: sugestao)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arquivar'));
    await tester.pump();
    expect(fakeSug.arquivadas, ['s2']);
  });
}
