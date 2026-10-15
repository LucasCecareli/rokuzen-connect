import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get tema {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaria,
        primary: AppColors.primariaForte,
        onPrimary: Colors.white,
        surface: AppColors.superficie,
        onSurface: AppColors.texto,
        error: AppColors.erro,
      ),
      scaffoldBackgroundColor: AppColors.fundo,
    );
    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.texto,
        displayColor: AppColors.texto,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primariaForte,
        selectionColor: AppColors.primaria.withValues(alpha: 0.3),
        selectionHandleColor: AppColors.primariaForte,
      ),
      splashColor: AppColors.primaria.withValues(alpha: 0.12),
      highlightColor: AppColors.primaria.withValues(alpha: 0.06),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.superficie,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
