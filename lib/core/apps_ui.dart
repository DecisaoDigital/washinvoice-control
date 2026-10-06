import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semântica de apresentação de uma app da Decisão Digital — o valor bruto da
/// coluna `app` (`pos`, `punho`) das tabelas de licenciamento.
///
/// Um só sítio para "dado `pos`/`punho`, que rótulo, que cor e que ícone": o
/// badge por linha, o selector do Dashboard e o prefixo dos pushes partilham
/// este mapeamento (mesma regra do [EstadoLicencaUi] em `estado_ui.dart`).
///
/// Cores saem dos tokens (`docs/design/tokens.md` §1) — azul de marca para o
/// POS, verde para o Fist, com os pares pastel/forte já validados para
/// contraste. Uma app desconhecida **não é erro**: pode aparecer na BD antes de
/// o Control saber dela, e nesse caso mostra-se o próprio valor a cinzento.
class AppsUi {
  AppsUi._();

  static const pos = 'pos';
  static const punho = 'punho';

  /// Apps que o Control conhece, pela ordem em que aparecem no selector.
  static const conhecidas = [pos, punho];

  /// Sigla curta, para badges por linha (pouco espaço horizontal).
  static String sigla(String app) => switch (app) {
        pos => 'POS',
        punho => 'FIST',
        _ => app.toUpperCase(),
      };

  /// Nome comercial, para o selector e cabeçalhos.
  static String nome(String app) => switch (app) {
        pos => 'WashInvoice',
        punho => 'Fist',
        _ => app,
      };

  /// Cor-base (tom 500) da app.
  static Color corBase(String app) => switch (app) {
        pos => AppColors.azul,
        punho => AppColors.verde,
        _ => AppColors.textTertiary,
      };

  /// Fundo pálido (tom 100) — para pills.
  static Color corPastel(String app) => switch (app) {
        pos => AppColors.azul100,
        punho => AppColors.verde100,
        _ => AppColors.fundo,
      };

  /// Texto forte (tom 900) — sobre [corPastel].
  static Color corForte(String app) => switch (app) {
        pos => AppColors.azul900,
        punho => AppColors.verde900,
        _ => AppColors.textSecondary,
      };

  static IconData icone(String app) => switch (app) {
        pos => Icons.point_of_sale,
        punho => Icons.pan_tool,
        _ => Icons.apps,
      };
}
