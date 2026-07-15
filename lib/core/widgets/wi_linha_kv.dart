import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_theme.dart';

/// Linha rótulo→valor: rótulo (width 100, label/textSecondary) + valor
/// (body-strong, opcionalmente monospace). [trailing] serve p.ex. o ícone
/// copiar do Machine ID.
class WiLinhaKV extends StatelessWidget {
  final String rotulo;
  final String valor;
  final bool mono;
  final Widget? trailing;
  final Color? corValor;

  const WiLinhaKV({
    super.key,
    required this.rotulo,
    required this.valor,
    this.mono = false,
    this.trailing,
    this.corValor,
  });

  @override
  Widget build(BuildContext context) {
    final estiloValor = (mono ? AppText.mono : AppText.bodyStrong)
        .copyWith(color: corValor ?? AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(rotulo, style: AppText.label),
          ),
          Expanded(
            child: Text(
              valor,
              style: estiloValor,
              overflow: mono ? TextOverflow.ellipsis : TextOverflow.clip,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
