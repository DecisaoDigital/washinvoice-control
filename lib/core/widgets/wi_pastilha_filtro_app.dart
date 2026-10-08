import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_colors.dart';
import '../app_filter/app_filter_provider.dart';
import '../app_radius.dart';
import '../app_spacing.dart';

/// «a ver só: POS» — aviso visível de que o filtro de app não está em «Todas».
///
/// Tocar volta a «Todas». Some-se sozinha quando o filtro está em «Todas».
/// Existe porque uma lista filtrada que pareça completa leva a achar que não
/// há nada pendente.
class WiPastilhaFiltroApp extends ConsumerWidget {
  const WiPastilhaFiltroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(appFilterProvider);
    if (filtro == AppFiltro.todas) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: AppColors.laranja100,
          borderRadius: AppRadius.pillAll,
          child: InkWell(
            borderRadius: AppRadius.pillAll,
            onTap: () =>
                ref.read(appFilterProvider.notifier).definir(AppFiltro.todas),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'a ver só: ${filtro.etiquetaCurta}',
                      style: const TextStyle(
                        color: AppColors.laranja900,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.laranja900,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [corpo] debaixo da [WiPastilhaFiltroApp] — o envólucro que os ecrãs com
/// selector de app usam no `body`.
class WiComPastilhaApp extends StatelessWidget {
  final Widget corpo;
  const WiComPastilhaApp({super.key, required this.corpo});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const WiPastilhaFiltroApp(),
      Expanded(child: corpo),
    ],
  );
}
