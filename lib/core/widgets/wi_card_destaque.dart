import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radius.dart';
import '../app_spacing.dart';

/// Cartão em destaque — fundo pálido + borda esquerda de acento (4px) +
/// elevação 2. Substitui o card cinzento inerte de "Início de actividade"
/// (tokens.md §5, correcção D2).
///
/// [cor] varia o acento: azul (default), laranja (pedidos abertos), roxo
/// (sugestões). O fundo pálido deriva automaticamente do acento.
class WiCardDestaque extends StatelessWidget {
  final Widget child;
  final Color cor;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const WiCardDestaque({
    super.key,
    required this.child,
    this.cor = AppColors.azul500,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tom50(cor),
      elevation: 2,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border(left: BorderSide(color: cor, width: 4)),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
