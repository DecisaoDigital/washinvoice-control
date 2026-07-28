import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_colors.dart';
import '../app_filter/app_filter_provider.dart';
import '../app_spacing.dart';
import '../apps_ui.dart';

/// Selector de app para a AppBar do Dashboard: Todas | WashInvoice | Punho.
///
/// Fechado mostra ícone + [AppFiltroExt.etiquetaCurta] a branco (a AppBar é
/// azul900). O rótulo está lá de propósito e não só o ícone: um dashboard
/// filtrado que pareça não filtrado leva a ler mal os números.
///
/// Desenhado como pastilha com fundo próprio para não se confundir com o
/// título nem com os ícones de acção da AppBar. Usado em cinco ecrãs
/// (Dashboard, Instalações, Mapa, Pedidos de ajuda, Sugestões).
///
/// Escrever no [appFilterProvider] persiste a escolha; os ecrãs recarregam ao
/// ouvir o provider.
class WiAppSelector extends ConsumerWidget {
  const WiAppSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(appFilterProvider);

    // Material (e não Container/BoxDecoration) para o fundo: o splash do
    // DropdownButton é pintado no Material ancestral mais próximo, e com um
    // Container o fundo tapava o ripple. Aqui a tinta cai por cima do fundo.
    //
    // O padding vive dentro do `selectedItemBuilder`, não à volta do botão:
    // assim toda a área visível da pastilha pertence ao DropdownButton e é
    // clicável — tocar no ícone da app ou no rótulo abre a cascata, não só a
    // seta. O mínimo de 48x48 é a regra de alvo de toque do Material.
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<AppFiltro>(
            value: filtro,
            iconEnabledColor: Colors.white,
            dropdownColor: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            focusColor: Colors.transparent,
            onChanged: (f) {
              if (f != null) ref.read(appFilterProvider.notifier).definir(f);
            },
            // Estado fechado — sobre a AppBar escura.
            selectedItemBuilder: (context) => [
              for (final f in AppFiltro.values)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icone(f), size: 18, color: Colors.white),
                      const SizedBox(width: AppSpacing.xs),
                      // Flexible + ellipsis: a AppBar do Dashboard já leva
                      // wordmark e quatro ícones, e num ecrã estreito o rótulo
                      // tem de ceder em vez de rebentar o Row.
                      Flexible(
                        child: Text(
                          f.etiquetaCurta,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            // Menu aberto — sobre fundo claro, com a cor de cada app.
            items: [
              for (final f in AppFiltro.values)
                DropdownMenuItem(
                  value: f,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icone(f), size: 18, color: _cor(f)),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          f.etiqueta,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icone(AppFiltro f) =>
      f.valorApp == null ? Icons.apps : AppsUi.icone(f.valorApp!);

  static Color _cor(AppFiltro f) =>
      f.valorApp == null ? AppColors.textSecondary : AppsUi.corBase(f.valorApp!);
}
