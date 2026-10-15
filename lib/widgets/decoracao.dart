import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';

/// Anel decorativo inspirado no ensō (o círculo do logo), usado nos cantos
/// das telas e dos cards.
class AnelEnso extends StatelessWidget {
  const AnelEnso({
    super.key,
    required this.tamanho,
    this.espessura = 12,
    this.rotacao = 210,
    this.intensidade = 1,
    this.cor = AppColors.primaria,
  });

  final double tamanho;
  final double espessura;

  /// Ângulo inicial do gradiente, em graus.
  final double rotacao;

  /// Multiplica a opacidade do traço (1 = como no protótipo).
  final double intensidade;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.square(tamanho),
        painter: _EnsoPainter(espessura, rotacao, intensidade, cor),
      ),
    );
  }
}

class _EnsoPainter extends CustomPainter {
  _EnsoPainter(this.espessura, this.rotacao, this.intensidade, this.cor);

  final double espessura;
  final double rotacao;
  final double intensidade;
  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    Color c(double a) =>
        cor.withValues(alpha: (a * intensidade).clamp(0.0, 1.0).toDouble());
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura
      ..shader = SweepGradient(
        colors: [c(0), c(0.45), c(0.3), c(0.1), c(0)],
        stops: const [0, 0.09, 0.56, 0.84, 0.92],
        // O gradiente do CSS começa no topo; o do Flutter, à direita.
        transform: GradientRotation((rotacao - 90) * math.pi / 180),
      ).createShader(rect);
    canvas.drawCircle(
      size.center(Offset.zero),
      (size.width - espessura) / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(_EnsoPainter old) =>
      old.espessura != espessura ||
      old.rotacao != rotacao ||
      old.intensidade != intensidade ||
      old.cor != cor;
}

/// Anel de progresso do dia ("2/4").
class AnelProgresso extends StatelessWidget {
  const AnelProgresso({
    super.key,
    required this.progresso,
    required this.rotulo,
    this.fundoInterno = AppColors.primariaSuave,
  });

  final double progresso;
  final String rotulo;
  final Color fundoInterno;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 72,
      child: CustomPaint(
        painter: _ProgressoPainter(progresso.clamp(0.0, 1.0).toDouble()),
        child: Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: fundoInterno,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              rotulo,
              style: AppText.s(16, peso: FontWeight.w700, altura: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressoPainter extends CustomPainter {
  _ProgressoPainter(this.progresso);
  final double progresso;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final raio = size.width / 2;
    canvas.drawCircle(
      centro,
      raio,
      Paint()..color = AppColors.primariaForte.withValues(alpha: 0.16),
    );
    if (progresso > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: raio),
        -math.pi / 2,
        2 * math.pi * progresso,
        true,
        Paint()..color = AppColors.primariaForte,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressoPainter old) => old.progresso != progresso;
}

/// Fundo listrado na diagonal (bloco do expediente e horários em conflito).
class FundoListrado extends StatelessWidget {
  const FundoListrado({
    super.key,
    required this.child,
    this.raio = 16,
    this.larguraListra = 8,
    this.borda = AppColors.listraBorda,
  });

  final Widget child;
  final double raio;
  final double larguraListra;
  final Color? borda;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(raio),
        border: borda == null ? null : Border.all(color: borda!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(raio),
        child: CustomPaint(
          painter: _ListrasPainter(larguraListra),
          child: child,
        ),
      ),
    );
  }
}

class _ListrasPainter extends CustomPainter {
  _ListrasPainter(this.largura);
  final double largura;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.listraClara);
    final paint = Paint()
      ..color = AppColors.listraEscura
      ..strokeWidth = largura
      ..style = PaintingStyle.stroke;
    // Listras a 135° (como o repeating-linear-gradient do protótipo).
    final passoHorizontal = largura * 2 * math.sqrt2;
    for (var x = 0.0; x < size.width + size.height; x += passoHorizontal) {
      canvas.drawLine(Offset(x, 0), Offset(x - size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_ListrasPainter old) => old.largura != largura;
}

/// Caixa com borda tracejada (estados vazios compactos).
class CaixaTracejada extends StatelessWidget {
  const CaixaTracejada({
    super.key,
    required this.icone,
    required this.texto,
    this.altura = 56,
    this.tamanhoTexto = 14,
  });

  final IconData icone;
  final String texto;
  final double altura;
  final double tamanhoTexto;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BordaTracejadaPainter(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: altura),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icone, size: 20, color: AppColors.textoSuave),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  texto,
                  style: AppText.s(tamanhoTexto,
                      altura: 20, cor: AppColors.textoSuave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BordaTracejadaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.linhaTempo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final caminho = Path()
      ..addRRect(RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.5),
        const Radius.circular(16),
      ));
    for (final metrica in caminho.computeMetrics()) {
      var d = 0.0;
      while (d < metrica.length) {
        canvas.drawPath(metrica.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bolinha verde pulsando (contagem regressiva e "Em andamento").
class PontoPulsante extends StatefulWidget {
  const PontoPulsante({super.key});

  @override
  State<PontoPulsante> createState() => _PontoPulsanteState();
}

class _PontoPulsanteState extends State<PontoPulsante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Transform.scale(
              scale: 1 + 1.2 * _c.value,
              child: Opacity(
                opacity: 0.55 * (1 - _c.value),
                child: const _Bolinha(),
              ),
            ),
          ),
          const _Bolinha(),
        ],
      ),
    );
  }
}

class _Bolinha extends StatelessWidget {
  const _Bolinha();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.primaria,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Bloco cinza pulsando, usado nos estados de carregamento.
class Esqueleto extends StatefulWidget {
  const Esqueleto({
    super.key,
    this.largura,
    required this.altura,
    this.raio = 8,
    this.circular = false,
  });

  final double? largura;
  final double altura;
  final double raio;
  final bool circular;

  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    lowerBound: 0.45,
    upperBound: 1,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        width: widget.largura,
        height: widget.altura,
        decoration: BoxDecoration(
          color: AppColors.skeleton,
          shape: widget.circular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius:
              widget.circular ? null : BorderRadius.circular(widget.raio),
        ),
      ),
    );
  }
}
