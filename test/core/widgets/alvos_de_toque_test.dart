import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/widgets/widgets.dart';

/// **Que altura tem, na realidade, cada coisa em que se carrega.**
///
/// Achado 6.6, segunda passagem. A primeira contou `InkWell` e `IconButton` e
/// arrumou os que eram só um ícone. Ficaram de fora os que têm texto por dentro
/// — e a conclusão de que «têm texto, logo estão bem» responde à pergunta
/// errada: um rótulo resolve quem não vê, não resolve quem tem o dedo grosso.
///
/// A altura não se estima a olhar para o `padding`, porque o que decide é o
/// texto lá dentro, a densidade visual do tema e o `MaterialTapTargetSize`.
/// Mede-se. É o que isto faz: monta cada peça partilhada e pergunta ao Flutter
/// quanto ocupou.
///
/// 48 dp é o mínimo das *Material Design accessibility guidelines* e o mesmo
/// número que as *WCAG 2.2 (2.5.8 Target Size)* aceitam como suficiente.
void main() {
  const minimo = 48.0;

  /// Monta o widget sozinho, alinhado ao topo e sem esticar, e devolve a
  /// altura que ele realmente ocupou.
  ///
  /// `Align` em vez de `Center` com `Expanded`: um widget metido numa coluna
  /// que estica dava 600 dp de altura e o teste passava sempre — mediria o
  /// ecrã, não a peça.
  Future<Size> medir(WidgetTester tester, Widget peca) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 320, child: peca),
          ),
        ),
      ),
    );
    return tester.getSize(find.byWidget(peca));
  }

  Future<void> peloMenos48(
    WidgetTester tester,
    Widget peca, {
    required String nome,
  }) async {
    final tamanho = await medir(tester, peca);
    expect(
      tamanho.height,
      greaterThanOrEqualTo(minimo),
      reason: '$nome tem ${tamanho.height.toStringAsFixed(1)} dp de altura',
    );
  }

  group('as peças partilhadas, quando se pode carregar nelas', () {
    testWidgets('título de secção que abre um ecrã', (t) async {
      await peloMenos48(
        t,
        WiSeccaoTitulo(
          titulo: 'Instalações',
          icone: Icons.store_outlined,
          comChevron: true,
          onTap: () {},
        ),
        nome: 'O título de secção',
      );
    });

    testWidgets('chip de filtro', (t) async {
      await peloMenos48(
        t,
        WiChipFiltro(label: 'Todas', activo: true, onTap: () {}),
        nome: 'O chip de filtro',
      );
    });

    testWidgets('chip de filtro com seta', (t) async {
      await peloMenos48(
        t,
        WiChipFiltro(
          label: 'Todas versões',
          activo: false,
          comSeta: true,
          onTap: () {},
        ),
        nome: 'O chip de filtro com seta',
      );
    });

    testWidgets('acção de linha', (t) async {
      await peloMenos48(
        t,
        WiAccaoDeLinha(
          icone: Icons.copy,
          aoTocar: () {},
          descricao: 'Copiar o identificador',
        ),
        nome: 'A acção de linha',
      );
    });
  });

  // Controlo negativo. Quatro medições que passam à primeira são bom sinal ou
  // são uma régua avariada, e não há como saber qual sem a fazer falhar de
  // propósito.
  testWidgets('a régua sabe apanhar um alvo pequeno', (tester) async {
    final tamanho = await medir(
      tester,
      InkWell(onTap: () {}, child: const Text('minúsculo')),
    );

    expect(
      tamanho.height,
      lessThan(minimo),
      reason: 'um Text nu mede menos de 48 dp — se aqui der 48, a régua mede '
          'o ecrã e não a peça, e as outras quatro medições não valem nada',
    );
  });

  // Quem não se pode tocar não precisa de área de toque, e forçá-la seria pior:
  // espalhava o ecrã todo por causa de uma regra que ali não se aplica.
  testWidgets('sem onTap, o título de secção não engorda', (tester) async {
    final tamanho = await medir(
      tester,
      const WiSeccaoTitulo(titulo: 'Resumo', icone: Icons.info_outline),
    );

    expect(tamanho.height, lessThan(minimo));
  });
}
