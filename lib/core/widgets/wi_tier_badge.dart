import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radius.dart';
import '../../models/licenca.dart';

/// Badge "PRO" a colocar **antes** do nome do cliente (task #177).
///
/// Aparece quando a licença tem direito às funcionalidades extra — ou seja
/// [Tier.pro] **e** [Tier.legado]. O legado entra de propósito: o modelo diz
/// que se comporta como Pro ("não se retiram funcionalidades a quem já as
/// tinha"), portanto esconder-lhe o badge mostraria como Base quem tem tudo.
/// Só o [Tier.base] fica sem badge.
///
/// Letras menores que o nome (10px contra os 15-16px dos títulos de linha) —
/// é um qualificador, não compete com o nome.
class WiTierBadge extends StatelessWidget {
  final Tier tier;

  const WiTierBadge(this.tier, {super.key});

  @override
  Widget build(BuildContext context) {
    if (!tier.temExtras) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: AppColors.azul100,
        borderRadius: AppRadius.pillAll,
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: AppColors.azul900,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
