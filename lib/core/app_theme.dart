import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';

/// Escala tipográfica — ver `docs/design/tokens.md` §2. Fonte Roboto (default
/// Android). Usar estes tokens em vez de `TextStyle` avulso nos ecrãs.
class AppText {
  AppText._();

  static const display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const h1 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const h2 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static const bodyStrong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
  static const caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );
  static const mono = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontFamily: 'monospace',
    color: AppColors.textPrimary,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.fundo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.azul500,
          primary: AppColors.azul500,
          surface: AppColors.surface,
        ),
        // azul900 (#1F5F87): AppBar de marca do redesign v1.4. Texto branco
        // sobre este tom dá ~6:1 — passa WCAG AA (ver tokens.md §1.3).
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.azul900,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
        textTheme: const TextTheme(
          displayLarge: AppText.display,
          headlineMedium: AppText.h1,
          titleLarge: AppText.h2,
          bodyLarge: AppText.bodyStrong,
          bodyMedium: AppText.body,
          labelLarge: AppText.label,
          bodySmall: AppText.caption,
        ).apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
      );
}
