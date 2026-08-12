import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';

/// Título de secção (14px w500) com ícone opcional à esquerda e chevron
/// opcional à direita (quando a secção abre um ecrã dedicado).
class WiSeccaoTitulo extends StatelessWidget {
  final String titulo;
  final IconData? icone;
  final bool comChevron;
  final VoidCallback? onTap;

  const WiSeccaoTitulo({
    super.key,
    required this.titulo,
    this.icone,
    this.comChevron = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final linha = Row(
      children: [
        if (icone != null) ...[
          Icon(icone, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (comChevron)
          const Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
      ],
    );
    // Sem `onTap` não há alvo de toque nenhum, e forçar 48 dp aqui só afastava
    // secções que ninguém carrega. É por isso que a régua tem um teste a
    // afirmar que este caso **continua** curto.
    if (onTap == null) return linha;
    return InkWell(
      onTap: onTap,
      child: Container(
        // Media 28 dp — o título de secção que abre um ecrã era o alvo mais
        // pequeno do Control, pouco mais de metade do mínimo. O texto não muda
        // de tamanho: o que cresce é o que responde ao dedo.
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: linha,
      ),
    );
  }
}
