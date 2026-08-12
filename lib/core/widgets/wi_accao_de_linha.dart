import 'package:flutter/material.dart';

import '../app_colors.dart';

/// O ícone de acção que vive no `trailing` de uma [WiLinhaKV] — copiar, ligar.
///
/// Existe porque o padrão anterior era um `Icon` de 18 dp nu dentro de um
/// `InkWell`, repetido em cinco ecrãs. Isso dá **um alvo de toque de 18 dp**,
/// pouco mais de um terço do mínimo de 48, e num ecrã de detalhe cheio de
/// linhas parecidas errar o toque é a norma, não a excepção.
///
/// Também não tinha nome nenhum: um leitor de ecrã anunciava "botão" e mais
/// nada, e havia dois ícones de copiar na mesma página — a chave mestre e o id
/// da máquina — indistinguíveis um do outro.
///
/// O ícone continua a desenhar 18 dp. O que cresce é a área que responde ao
/// dedo, com 15 dp de folga à volta.
class WiAccaoDeLinha extends StatelessWidget {
  const WiAccaoDeLinha({
    super.key,
    required this.icone,
    required this.aoTocar,
    required this.descricao,
    this.cor,
  });

  final IconData icone;
  final VoidCallback aoTocar;

  /// O que este toque faz, dito por extenso: «Copiar a chave mestre», não
  /// «copiar». É isto que um leitor de ecrã lê e o que aparece ao manter
  /// premido — e é o que distingue dois ícones iguais na mesma página.
  final String descricao;

  final Color? cor;

  /// 48, que é o mínimo do Material e das WCAG.
  ///
  /// Esteve em 40 por uma razão que parecia boa e não resistiu à régua: «48
  /// empurrava as linhas todas para longe umas das outras». Medido
  /// (`alvos_de_toque_test.dart`), a `WiLinhaKV` mede 27 dp sozinha, **48 com
  /// uma acção de 40** — o `padding` já lá punha os 8 que faltavam — e 56 com
  /// uma de 48. O custo verdadeiro são 8 dp, e só nas linhas que têm botão,
  /// não «nas linhas todas».
  static const double _lado = 48;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: descricao,
    child: InkWell(
      onTap: aoTocar,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: _lado,
        height: _lado,
        // `Center` explícito: sem ele o ícone assenta no canto que as
        // restrições soltas lhe derem, e o alvo cresce para um lado só.
        child: Center(
          child: Icon(
            icone,
            size: 18,
            color: cor ?? AppColors.textTertiary,
            semanticLabel: descricao,
          ),
        ),
      ),
    ),
  );
}
