import 'package:flutter/material.dart';

/// Paleta de cores consistente com o WashInvoice.
///
/// Fonte de verdade: `docs/design/tokens.md` §1. Cada cor-base (500) tem escala
/// 50/100/200/700/900. Os tons *50 servem de fundo pálido de cartão; os *700 são
/// as superfícies onde texto branco passa WCAG AA (ver §1.3); os *900 são texto
/// escuro sobre fundos pálidos.
///
/// Nota: `azul900` = #1F5F87 (tom da AppBar do redesign v1.4, ver tokens.md §1.3),
/// não o #185277 antigo — reconciliação registada no tokens.md.
class AppColors {
  AppColors._();

  // Base (== escala 500).
  static const azul = Color(0xFF2B95D9);
  static const verde = Color(0xFF5CB036);
  static const roxo = Color(0xFF534AB7);
  static const laranja = Color(0xFFF97316);
  static const vermelho = Color(0xFFDC2626);

  // Azul
  static const azul50 = Color(0xFFF2F9FD);
  static const azul100 = Color(0xFFE6F2FA);
  static const azul200 = Color(0xFFBFDFF4);
  static const azul500 = azul;
  static const azul700 = Color(0xFF2277AE);
  static const azul900 = Color(0xFF1F5F87); // AppBar / superfície escura de marca

  // Verde
  static const verde50 = Color(0xFFF5FAF3);
  static const verde100 = Color(0xFFEBF6E7);
  static const verde200 = Color(0xFFCEE7C3);
  static const verde500 = verde;
  static const verde700 = Color(0xFF4A8D2B);
  static const verde900 = Color(0xFF33611E);

  // Roxo
  static const roxo50 = Color(0xFFF5F4FB);
  static const roxo100 = Color(0xFFEAE9F6);
  static const roxo200 = Color(0xFFCBC9E9);
  static const roxo500 = roxo;
  static const roxo700 = Color(0xFF423B92);
  static const roxo900 = Color(0xFF2E2965);

  // Laranja
  static const laranja50 = Color(0xFFFFF7F1);
  static const laranja100 = Color(0xFFFEEEE3);
  static const laranja200 = Color(0xFFFDD5B9);
  static const laranja500 = laranja;
  static const laranja700 = Color(0xFFC75C12);
  static const laranja900 = Color(0xFF893F0C);

  // Vermelho
  static const vermelho50 = Color(0xFFFDF2F2);
  static const vermelho100 = Color(0xFFFBE5E5);
  static const vermelho200 = Color(0xFFF4BEBE);
  static const vermelho500 = vermelho;
  static const vermelho700 = Color(0xFFB01E1E);
  static const vermelho900 = Color(0xFF791515);

  // Neutros
  static const fundo = Color(0xFFF0F0F0);
  static const surface = Colors.white;
  static const borda = Color(0xFFE2E2E0);

  static const textPrimary = Color(0xFF2C2C2A);
  static const textSecondary = Color(0xFF5F5E5A);
  static const textTertiary = Color(0xFF9E9D9B);

  // ── Mapeamento de tons a partir da cor-base (500) ──────────────────────────
  // Fonte única para "dado um acento, qual o fundo pálido / texto forte".
  // Evita cada widget re-decidir tons (regra: um só sítio para semântica de cor).

  /// Tom 50 (fundo pálido de cartão) para uma cor-base [b].
  static Color tom50(Color b) {
    if (b == verde) return verde50;
    if (b == roxo) return roxo50;
    if (b == laranja) return laranja50;
    if (b == vermelho) return vermelho50;
    return azul50;
  }

  /// Tom 100 (fundo de chip/KPI) para uma cor-base [b].
  static Color tom100(Color b) {
    if (b == verde) return verde100;
    if (b == roxo) return roxo100;
    if (b == laranja) return laranja100;
    if (b == vermelho) return vermelho100;
    return azul100;
  }

  /// Tom 900 (texto forte sobre 50/100) para uma cor-base [b].
  static Color tom900(Color b) {
    if (b == verde) return verde900;
    if (b == roxo) return roxo900;
    if (b == laranja) return laranja900;
    if (b == vermelho) return vermelho900;
    return azul900;
  }
}
