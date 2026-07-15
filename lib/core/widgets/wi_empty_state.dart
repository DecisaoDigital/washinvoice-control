import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_theme.dart';

/// Estado vazio — ícone grande centrado + título + mensagem + acção opcional
/// (tokens.md §8).
class WiEmptyState extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? mensagem;
  final Widget? accao;

  const WiEmptyState({
    super.key,
    required this.icone,
    required this.titulo,
    this.mensagem,
    this.accao,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 56, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.lg),
            Text(titulo, textAlign: TextAlign.center, style: AppText.h2),
            if (mensagem != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                mensagem!,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (accao != null) ...[
              const SizedBox(height: AppSpacing.xl),
              accao!,
            ],
          ],
        ),
      ),
    );
  }
}
