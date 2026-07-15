import 'package:flutter/widgets.dart';

/// Raios de canto — ver `docs/design/tokens.md` §4.
///
/// Regra: inputs e cards usam [md] (12); nunca 8px avulso. Só filtros, badges e
/// CTAs principais usam [pill].
class AppRadius {
  AppRadius._();

  static const double sm = 8; // chips pequenos, inputs secundários
  static const double md = 12; // cards, inputs
  static const double pill = 999; // botões de filtro, badges, CTA principal

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}
