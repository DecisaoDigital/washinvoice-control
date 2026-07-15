import 'package:flutter/material.dart';

/// Paleta de cores consistente com o WashInvoice.
class AppColors {
  AppColors._();

  static const azul = Color(0xFF2B95D9);
  static const verde = Color(0xFF5CB036);
  static const roxo = Color(0xFF534AB7);
  static const laranja = Color(0xFFF97316);
  static const vermelho = Color(0xFFDC2626);

  // Escalas derivadas — ver docs/design/tokens.md §1.2. Os tons *50 servem de
  // fundo pálido de cartão; os *700 são as únicas superfícies onde texto branco
  // passa WCAG AA (ver §1.3).
  static const azul50 = Color(0xFFF2F9FD);
  static const azul100 = Color(0xFFE6F2FA);
  static const azul700 = Color(0xFF2277AE);
  static const verde50 = Color(0xFFF5FAF3);
  static const verde100 = Color(0xFFEBF6E7);
  static const roxo50 = Color(0xFFF5F4FB);
  static const roxo100 = Color(0xFFEAE9F6);
  static const laranja50 = Color(0xFFFFF7F1);
  static const laranja100 = Color(0xFFFEEEE3);
  static const vermelho50 = Color(0xFFFDF2F2);
  static const vermelho100 = Color(0xFFFBE5E5);

  static const fundo = Color(0xFFF0F0F0);
  static const surface = Colors.white;
  static const borda = Color(0xFFE2E2E0);

  static const textPrimary = Color(0xFF2C2C2A);
  static const textSecondary = Color(0xFF5F5E5A);
  static const textTertiary = Color(0xFF9E9D9B);
}
