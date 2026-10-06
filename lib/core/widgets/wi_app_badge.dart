import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_filter/app_filter_provider.dart';
import '../app_radius.dart';
import '../app_spacing.dart';
import '../apps_ui.dart';

/// Pill com a sigla da app (`POS`, `FIST`) — para identificar a origem de uma
/// linha quando o filtro está em "Todas as apps".
///
/// Mesma anatomia do [WiBadgeEstado]: fundo pastel (tom 100) + texto forte
/// (tom 900) da cor da app, cantos pill (tokens.md §1.5 / §8). Deliberadamente
/// mais discreto do que o badge de estado — a app é contexto, o estado da
/// licença é que é o sinal.
class WiAppBadge extends StatelessWidget {
  /// Valor bruto da coluna `app` (`pos` / `punho`).
  final String app;

  const WiAppBadge(this.app, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppsUi.corPastel(app),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        AppsUi.sigla(app),
        style: TextStyle(
          color: AppsUi.corForte(app),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// [WiAppBadge] que se esconde sozinho quando o [appFilterProvider] já está
/// fixo numa app.
///
/// Com o filtro em "WashInvoice", marcar cada linha com `POS` não informa nada
/// — só gasta espaço. A regra vive aqui em vez de em cada ecrã para não haver
/// listas onde alguém se esqueceu de a aplicar.
class WiAppBadgeAuto extends ConsumerWidget {
  final String app;

  /// Espaço à direita, para separar do que vem a seguir na linha.
  final double espacoDireita;

  const WiAppBadgeAuto(this.app, {super.key, this.espacoDireita = AppSpacing.sm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(appFilterProvider) != AppFiltro.todas) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(right: espacoDireita),
      child: WiAppBadge(app),
    );
  }
}
