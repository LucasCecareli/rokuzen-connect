import 'package:flutter/material.dart';

/// Paleta do Rokuzen Connect, extraída do protótipo da ferramenta de design.
abstract final class AppColors {
  // Fundos e superfícies
  static const fundo = Color(0xFFFAF8F4);
  static const superficie = Color(0xFFFFFFFF);
  static const fundoCampo = Color(0xFFFAF8F5);
  static const fundoLogin = Color(0xFFEEF2E2);
  static const hover = Color(0xFFF6F8F0);
  static const skeleton = Color(0xFFEEEAE4);

  // Texto
  static const texto = Color(0xFF3A2E2A);
  static const textoSecundario = Color(0xFF4E4440);
  static const textoSuave = Color(0xFF6B5F5A);
  static const textoRodape = Color(0xFF6F635D);
  static const placeholder = Color(0xFF7A6E68);

  // Bordas e linhas
  static const borda = Color(0xFFECE7E0);
  static const divisor = Color(0xFFF0ECE6);
  static const contorno = Color(0xFF948880);
  static const linhaTempo = Color(0xFFD6CFC8);
  static const cinzaNo = Color(0xFFA1958E);
  static const alca = Color(0xFFC9C1B9);

  // Marca
  static const primaria = Color(0xFF8DB33A);
  static const sobrePrimaria = Color(0xFF22300C);
  static const primariaForte = Color(0xFF4A6B16);
  static const primariaEscura = Color(0xFF3D5A12);
  static const primariaSuave = Color(0xFFEEF5E1);
  static const primariaSuaveHover = Color(0xFFE3EDD0);
  static const verdeClaroSnack = Color(0xFFCDE59A);
  static const verdeIconeSnack = Color(0xFFA9CC5C);

  // Erro
  static const erro = Color(0xFFB3261E);
  static const erroFundo = Color(0xFFFBEAE7);
  static const erroTexto = Color(0xFF8C1D18);

  // "Em andamento"
  static const azul = Color(0xFF174E6E);
  static const azulSuave = Color(0xFFE3EEF5);

  // Bloco listrado do expediente
  static const listraClara = Color(0xFFF3F0EC);
  static const listraEscura = Color(0xFFECE7E1);
  static const listraBorda = Color(0xFFE2DCD5);

  // Card escuro (atendimento em andamento)
  static const textoSobreEscuro = Color(0xFFD9D1CA);
  static const textoSobreEscuro2 = Color(0xFFE8E2DC);

  /// Cor do véu atrás das folhas inferiores e diálogos.
  static Color get veu => texto.withValues(alpha: 0.36);
}
