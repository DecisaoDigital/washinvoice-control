import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/instalacoes/card_series_widget.dart';
import 'package:washinvoice_control/models/licenca.dart';
import 'package:washinvoice_control/models/serie_comunicada.dart';
import 'package:washinvoice_control/repositories/providers.dart';
import 'package:washinvoice_control/repositories/series_repository.dart';
import 'package:washinvoice_control/services/licenca/comunicar_serie_service.dart';

/// Repo falso: devolve o que estiver em [lista] (mutável para simular o refresh
/// depois de comunicar). Não toca no Supabase.
class _FakeSeriesRepo extends SeriesRepository {
  List<SerieComunicada> lista;
  _FakeSeriesRepo(this.lista);

  @override
  Future<List<SerieComunicada>> porLicenca(String licencaId) async => lista;
}

Licenca _licencaPro() => Licenca(
      id: 'lic-1',
      machineId: 'mac-1',
      nif: '515307548',
      plano: 'anual',
      validade: DateTime.now().add(const Duration(days: 200)),
      activa: true,
      criadoEm: DateTime.now(),
      tier: Tier.pro,
      atUsername: '215555449/1', // acesso AT já configurado
    );

void main() {
  testWidgets('comunica uma série nova e ela aparece na lista com o ATCUD',
      (tester) async {
    final fakeRepo = _FakeSeriesRepo([]);

    final fakeService = ComunicarSerieService.comInvocador((body) async {
      if (body['acao'] == 'comunicar') {
        // Simula a AT a devolver o ATCUD e a série a ficar registada.
        fakeRepo.lista = [
          SerieComunicada(
            id: 's-1',
            licencaId: 'lic-1',
            machineId: 'mac-1',
            serie: body['serie'] as String,
            tipoDoc: body['tipo_doc'] as String,
            numeroInicial: 1,
            dataInicio: DateTime.utc(2026, 7, 22),
            codigoValidacao: 'X6Y2ZM12',
            ambiente: 'testes',
            criadoEm: DateTime.utc(2026, 7, 22),
          ),
        ];
        return {'ok': true, 'codigo_validacao': 'X6Y2ZM12'};
      }
      return {'ok': true};
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seriesRepoProvider.overrideWithValue(fakeRepo),
          comunicarSerieProvider.overrideWithValue(fakeService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CardSeriesFiscais(
              licenca: _licencaPro(),
              onLicencaAlterada: () {},
            ),
          ),
        ),
      ),
    );

    // Estado inicial: sem séries.
    await tester.pumpAndSettle();
    expect(find.text('Ainda sem séries comunicadas.'), findsOneWidget);

    // Abrir o modal "Nova série" (só existe o botão neste momento).
    await tester.tap(find.text('Nova série'));
    await tester.pumpAndSettle();
    expect(find.text('Comunicar à AT'), findsOneWidget);

    // Comunicar (o identificador já vem pré-preenchido <TIPO>A<ano>).
    await tester.tap(find.text('Comunicar à AT'));
    await tester.pumpAndSettle();

    // A série comunicada aparece na lista com o chip verde do ATCUD.
    expect(find.textContaining('Comunicada · X6Y2ZM12'), findsOneWidget);
    expect(find.text('Ainda sem séries comunicadas.'), findsNothing);
  });

  testWidgets('cliente Base não vê o card (auto-esconde)', (tester) async {
    final licencaBase = _licencaPro().copyWith(tier: Tier.base);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seriesRepoProvider.overrideWithValue(_FakeSeriesRepo([])),
          comunicarSerieProvider.overrideWithValue(
              ComunicarSerieService.comInvocador((_) async => {'ok': true})),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CardSeriesFiscais(
              licenca: licencaBase,
              onLicencaAlterada: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Séries fiscais'), findsNothing);
    expect(find.byType(SizedBox), findsWidgets); // devolve SizedBox.shrink()
  });
}
