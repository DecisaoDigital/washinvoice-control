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
    if (onTap == null) return linha;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: linha,
      ),
    );
  }
}
