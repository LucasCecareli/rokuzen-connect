import 'package:flutter/material.dart';

/// Regras de responsividade. O app é pensado para celular; em telas largas
/// (computador, tablet deitado) ele se reorganiza sem esticar o conteúdo.
abstract final class Responsivo {
  /// A partir desta largura a navegação vira barra lateral.
  static const larguraBarraLateral = 900.0;

  /// Largura máxima da coluna de conteúdo das abas.
  static const larguraConteudo = 720.0;

  /// Largura máxima das folhas inferiores (formulários e detalhes).
  static const larguraFolha = 560.0;
}

bool ehTelaLarga(
  BuildContext context, {
  double limite = Responsivo.larguraBarraLateral,
}) =>
    MediaQuery.sizeOf(context).width >= limite;

/// Centraliza o conteúdo numa coluna de largura máxima (no celular não muda
/// nada, porque a tela já é mais estreita que o limite).
class ColunaCentral extends StatelessWidget {
  const ColunaCentral({
    super.key,
    required this.child,
    this.larguraMaxima = Responsivo.larguraConteudo,
  });

  final Widget child;
  final double larguraMaxima;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final largura =
            c.maxWidth < larguraMaxima ? c.maxWidth : larguraMaxima;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: largura,
            height: c.hasBoundedHeight ? c.maxHeight : null,
            child: child,
          ),
        );
      },
    );
  }
}

/// Limita a largura do conteúdo DENTRO de uma área rolável. Assim a barra de
/// rolagem fica no canto direito da janela, e o conteúdo, centralizado.
class LarguraConteudo extends StatelessWidget {
  const LarguraConteudo({
    super.key,
    required this.child,
    this.larguraMaxima = Responsivo.larguraConteudo,
  });

  final Widget child;
  final double larguraMaxima;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: larguraMaxima),
        child: child,
      ),
    );
  }
}
