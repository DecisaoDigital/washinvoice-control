import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radius.dart';
import '../app_spacing.dart';

/// Chip pill de filtro (tokens.md §7, correcção I3).
///
/// - Activo: fundo `azul100` + borda `azul500` + texto `azul900`.
/// - Inactivo: fundo branco + borda `#9E9D9B` (textTertiary, **100%** opacidade,
///   não 40%) + texto `textSecondary`.
///
/// [comSeta] mostra um chevron para baixo (filtros que abrem menu, ex.:
/// "Todas versões").
class WiChipFiltro extends StatelessWidget {
  final String label;
  final bool activo;
  final bool comSeta;
  final VoidCallback? onTap;

  const WiChipFiltro({
    super.key,
    required this.label,
    required this.activo,
    this.comSeta = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final corBorda = activo ? AppColors.azul500 : AppColors.textTertiary;
    final corTexto = activo ? AppColors.azul900 : AppColors.textSecondary;
    final corFundo = activo ? AppColors.azul100 : AppColors.surface;

    return Material(
      color: corFundo,
      borderRadius: AppRadius.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillAll,
            border: Border.all(color: corBorda),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: corTexto,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (comSeta) ...[
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down, size: 16, color: corTexto),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
