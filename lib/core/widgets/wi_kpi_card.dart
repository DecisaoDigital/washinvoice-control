import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radius.dart';
import '../app_spacing.dart';

/// KPI card do Dashboard — ícone (24) + número grande (28px w500) + label (12px).
/// Fundo pastel do estado, texto forte do estado (tokens.md §8).
///
/// [cor] é a cor-base (500) do estado; fundo (tom 100) e texto (tom 900) derivam.
class WiKpiCard extends StatelessWidget {
  final IconData icone;
  final int valor;
  final String label;
  final Color cor;
  final VoidCallback? onTap;

  const WiKpiCard({
    super.key,
    required this.icone,
    required this.valor,
    required this.label,
    required this.cor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fundo = AppColors.tom100(cor);
    final forte = AppColors.tom900(cor);
    return Material(
      color: fundo,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 24, color: forte),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$valor',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: forte,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: forte,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
