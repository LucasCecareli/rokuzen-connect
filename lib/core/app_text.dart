import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tipografia do app (Plus Jakarta Sans).
///
/// `altura` é a altura da linha em pixels, como no protótipo
/// (ex.: font-size 28px / line-height 36px → `AppText.s(28, altura: 36)`).
abstract final class AppText {
  static TextStyle s(
    double tamanho, {
    FontWeight peso = FontWeight.w400,
    Color cor = AppColors.texto,
    double? altura,
    double espacamento = 0,
    TextDecoration? decoracao,
    bool numerosTabulares = false,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: tamanho,
      fontWeight: peso,
      color: cor,
      height: altura == null ? null : altura / tamanho,
      letterSpacing: espacamento,
      decoration: decoracao,
      decorationColor: cor,
      fontFeatures:
          numerosTabulares ? const [FontFeature.tabularFigures()] : null,
    );
  }

  // Estilos recorrentes
  static TextStyle sobretitulo([Color cor = AppColors.primariaForte]) =>
      s(12, peso: FontWeight.w700, altura: 16, espacamento: 1.2, cor: cor);

  static TextStyle tituloTela() =>
      s(28, peso: FontWeight.w700, altura: 36, espacamento: -0.4);

  static TextStyle tituloSecao() => s(18, peso: FontWeight.w700, altura: 24);
}
