import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_theme.dart';

/// Cabeçalho de card de detalhe: ícone semântico + título (h2). Reutilizável
/// pelos ecrãs de detalhe (pedido de ajuda, sugestão, …).
class WiCardTitulo extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final Color? corIcone;

  const WiCardTitulo({
    super.key,
    required this.icone,
    required this.titulo,
    this.corIcone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icone, size: 18, color: corIcone ?? AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(titulo, style: AppText.h2),
        ],
      ),
    );
  }
}
