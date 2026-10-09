import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_filter/app_filter_provider.dart';
import '../app_spacing.dart';
import 'wi_chip_filtro.dart';

/// A barra de apps: uma etiqueta por cada app que o Cesar controla (Todas,
/// WashInvoice, Fist) e que faz de filtro de app. Substitui o selector
/// «Todas ▾» da AppBar. O Fist OP faz parte do Fist.
///
/// Quebra em mais linhas em vez de deslizar de lado, para se verem todas.
class WiBarraApps extends ConsumerWidget {
  const WiBarraApps({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(appFilterProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          for (final f in AppFiltro.values)
            WiChipFiltro(
              label: f.etiquetaCurta,
              activo: f == filtro,
              onTap: () => ref.read(appFilterProvider.notifier).definir(f),
            ),
        ],
      ),
    );
  }
}
