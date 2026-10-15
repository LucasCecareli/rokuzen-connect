import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/formatadores.dart';
import '../data/models/modelos.dart';
import 'componentes.dart';

/// Estilo do traço vertical que liga os itens da linha do tempo.
class EstiloLinha {
  const EstiloLinha({required this.cor, this.tracejada = false});
  final Color cor;
  final bool tracejada;
}

const linhaContinua = EstiloLinha(cor: AppColors.primaria);
const linhaTracejada = EstiloLinha(cor: AppColors.linhaTempo, tracejada: true);

class _TrechoLinha extends StatelessWidget {
  const _TrechoLinha(this.estilo);
  final EstiloLinha? estilo;

  @override
  Widget build(BuildContext context) {
    if (estilo == null) return const SizedBox(width: 24);
    return CustomPaint(
      painter: _TrechoPainter(estilo!),
      child: const SizedBox(width: 24),
    );
  }
}

class _TrechoPainter extends CustomPainter {
  _TrechoPainter(this.estilo);
  final EstiloLinha estilo;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = estilo.cor
      ..strokeWidth = 2;
    final x = size.width / 2;
    if (!estilo.tracejada) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      return;
    }
    for (var y = 0.0; y < size.height; y += 8) {
      final fim = (y + 4).clamp(0.0, size.height).toDouble();
      canvas.drawLine(Offset(x, y), Offset(x, fim), paint);
    }
  }

  @override
  bool shouldRepaint(_TrechoPainter old) =>
      old.estilo.cor != estilo.cor || old.estilo.tracejada != estilo.tracejada;
}

/// Linha horizontal tracejada (marcador "AGORA").
class LinhaTracejadaHorizontal extends StatelessWidget {
  const LinhaTracejadaHorizontal({super.key, this.cor = AppColors.primaria});
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HorizontalPainter(cor),
      child: const SizedBox(height: 1, width: double.infinity),
    );
  }
}

class _HorizontalPainter extends CustomPainter {
  _HorizontalPainter(this.cor);
  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cor
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + 3, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_HorizontalPainter old) => old.cor != cor;
}

/// Círculo de 24px da linha do tempo.
class NoLinha extends StatelessWidget {
  const NoLinha({
    super.key,
    required this.fundo,
    required this.borda,
    this.icone,
    this.corIcone = Colors.white,
    this.brilho,
    this.alvo = false,
  });

  final Color fundo;
  final Color borda;
  final IconData? icone;
  final Color corIcone;

  /// Cor do halo de 4px ao redor (próximo atendimento / em andamento).
  final Color? brilho;

  /// Estilo "alvo": anel com ponto no centro (próximo atendimento).
  final bool alvo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: alvo ? Colors.white : fundo,
        shape: BoxShape.circle,
        border: Border.all(color: borda, width: 2),
        boxShadow: brilho == null
            ? null
            : [BoxShadow(color: brilho!, spreadRadius: 4)],
      ),
      alignment: Alignment.center,
      child: alvo
          ? Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: fundo, shape: BoxShape.circle),
            )
          : icone == null
              ? null
              : Icon(icone, size: 14, color: corIcone),
    );
  }
}

/// Um item da linha do tempo: coluna de horário (opcional), nó com traços
/// e conteúdo.
///
/// Os traços ficam numa camada por trás (Stack), esticados até o fim do
/// item, para ligarem um nó ao próximo.
class ItemLinhaDoTempo extends StatelessWidget {
  const ItemLinhaDoTempo({
    super.key,
    this.hora,
    this.topoHora = 0,
    required this.no,
    this.topoNo = 20,
    this.alturaNo = 24,
    this.acima,
    this.abaixo,
    required this.conteudo,
    this.espacoAbaixo = 8,
    this.opacidade = 1,
  });

  final Widget? hora;
  final double topoHora;
  final Widget no;
  final double topoNo;
  final double alturaNo;
  final EstiloLinha? acima;
  final EstiloLinha? abaixo;
  final Widget conteudo;
  final double espacoAbaixo;
  final double opacidade;

  @override
  Widget build(BuildContext context) {
    final inicioColunaNo = hora == null ? 0.0 : 48.0 + 12.0;
    final item = Stack(
      children: [
        Positioned(
          left: inicioColunaNo,
          top: 0,
          bottom: 0,
          width: 24,
          child: Column(
            children: [
              SizedBox(height: topoNo, child: _TrechoLinha(acima)),
              SizedBox(height: alturaNo),
              Expanded(child: _TrechoLinha(abaixo)),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hora != null) ...[
              SizedBox(
                width: 48,
                child: Padding(
                  padding: EdgeInsets.only(top: topoHora),
                  child: Align(alignment: Alignment.topRight, child: hora),
                ),
              ),
              const SizedBox(width: 12),
            ],
            SizedBox(
              width: 24,
              child: Padding(
                padding: EdgeInsets.only(top: topoNo),
                child: SizedBox(height: alturaNo, child: Center(child: no)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: espacoAbaixo),
                child: conteudo,
              ),
            ),
          ],
        ),
      ],
    );
    return opacidade == 1 ? item : Opacity(opacity: opacidade, child: item);
  }
}

/// Marcador "AGORA" da linha do tempo.
class MarcadorAgora extends StatelessWidget {
  const MarcadorAgora({super.key, required this.horario, this.linha});
  final String horario;
  final EstiloLinha? linha;

  @override
  Widget build(BuildContext context) {
    final estilo = AppText.s(12,
        peso: FontWeight.w700, altura: 16, cor: AppColors.primariaForte);
    return ItemLinhaDoTempo(
      hora: Text(horario, style: estilo),
      topoNo: 4,
      alturaNo: 8,
      acima: linha,
      abaixo: linha,
      no: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.primariaForte,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaria.withValues(alpha: 0.25),
              spreadRadius: 4,
            ),
          ],
        ),
      ),
      conteudo: SizedBox(
        height: 16,
        child: Row(
          children: [
            Text('AGORA', style: estilo),
            const SizedBox(width: 8),
            const Expanded(child: LinhaTracejadaHorizontal()),
          ],
        ),
      ),
    );
  }
}

/// Linha do dia com os atendimentos (Início e Agenda › Dia).
///
/// Quando [agora] é informado, o dia é hoje: destaca o próximo atendimento e
/// mostra o marcador "AGORA".
class LinhaDoDia extends StatelessWidget {
  const LinhaDoDia({
    super.key,
    required this.atendimentos,
    required this.aoAbrir,
    this.agora,
    this.mostrarFim = false,
  });

  final List<Atendimento> atendimentos;
  final ValueChanged<Atendimento> aoAbrir;
  final DateTime? agora;
  final bool mostrarFim;

  @override
  Widget build(BuildContext context) {
    final lista = atendimentos;
    final ehHoje = agora != null;
    Atendimento? ativo;
    Atendimento? proximo;
    if (ehHoje) {
      for (final a in lista) {
        if (a.status == StatusAtendimento.andamento) {
          ativo = a;
          break;
        }
      }
      if (ativo == null) {
        for (final a in lista) {
          if (a.status == StatusAtendimento.confirmado ||
              a.status == StatusAtendimento.pendente) {
            proximo = a;
            break;
          }
        }
      } else {
        proximo = ativo;
      }
    }

    bool passou(Atendimento? a) =>
        a != null &&
        (a.status == StatusAtendimento.concluido ||
            a.status == StatusAtendimento.andamento ||
            a.id == proximo?.id);

    EstiloLinha? estiloAbaixo(int i) {
      if (i >= lista.length - 1) return null;
      final a = lista[i];
      final continua =
          a.status == StatusAtendimento.concluido && passou(lista[i + 1]);
      return continua ? linhaContinua : linhaTracejada;
    }

    final itens = <Widget>[];
    var agoraColocado = !ehHoje || ativo != null;
    final minutoAgora = ehHoje ? minutosDoDia(agora!) : 0;

    for (var i = 0; i < lista.length; i++) {
      final a = lista[i];
      final acima = i > 0 ? estiloAbaixo(i - 1) : null;
      if (!agoraColocado && minutosDoDia(a.inicio) > minutoAgora) {
        itens.add(MarcadorAgora(horario: hora(agora!), linha: acima));
        agoraColocado = true;
      }
      itens.add(_itemAtendimento(a, proximo, acima, estiloAbaixo(i)));
    }
    if (!agoraColocado && lista.isNotEmpty) {
      itens.add(MarcadorAgora(horario: hora(agora!)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: itens,
    );
  }

  Widget _itemAtendimento(
    Atendimento a,
    Atendimento? proximo,
    EstiloLinha? acima,
    EstiloLinha? abaixo,
  ) {
    final concluido = a.status == StatusAtendimento.concluido;
    final inativo = a.status.inativo;
    final ativo = a.status == StatusAtendimento.andamento;
    final ehProximo = proximo != null && a.id == proximo.id;
    final apagado = concluido || inativo;

    final corHora = apagado
        ? AppColors.textoSuave
        : ehProximo
            ? AppColors.primariaForte
            : AppColors.texto;
    final pesoHora = ehProximo ? FontWeight.w700 : FontWeight.w600;

    final Widget no;
    if (concluido) {
      no = const NoLinha(
        fundo: AppColors.primariaForte,
        borda: AppColors.primariaForte,
        icone: Icons.check_rounded,
      );
    } else if (ativo) {
      no = NoLinha(
        fundo: AppColors.azul,
        borda: AppColors.azul,
        icone: Icons.more_horiz_rounded,
        brilho: AppColors.azul.withValues(alpha: 0.18),
      );
    } else if (ehProximo) {
      no = NoLinha(
        fundo: AppColors.primariaForte,
        borda: AppColors.primariaForte,
        alvo: true,
        brilho: AppColors.primaria.withValues(alpha: 0.25),
      );
    } else if (inativo) {
      no = const NoLinha(
        fundo: Color(0xFFF0EDE9),
        borda: AppColors.alca,
        icone: Icons.close_rounded,
        corIcone: AppColors.textoSuave,
      );
    } else {
      no = const NoLinha(fundo: Colors.white, borda: AppColors.cinzaNo);
    }

    final horaW = mostrarFim
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(hora(a.inicio),
                  style: AppText.s(14, peso: pesoHora, altura: 20, cor: corHora)),
              Text(hora(a.fim),
                  style:
                      AppText.s(12, altura: 16, cor: AppColors.textoSuave)),
            ],
          )
        : Text(hora(a.inicio),
            style: AppText.s(14, peso: pesoHora, altura: 20, cor: corHora));

    final borda = ativo
        ? AppColors.azul
        : ehProximo
            ? AppColors.primaria
            : AppColors.borda;

    return ItemLinhaDoTempo(
      hora: horaW,
      topoHora: mostrarFim ? 14 : 22,
      no: no,
      acima: acima,
      abaixo: abaixo,
      conteudo: CartaoAtendimentoLinha(
        atendimento: a,
        fundo: apagado ? Colors.transparent : AppColors.superficie,
        borda: borda,
        apagado: apagado,
        aoTocar: () => aoAbrir(a),
      ),
    );
  }
}

/// Cartão de atendimento usado na linha do tempo.
class CartaoAtendimentoLinha extends StatelessWidget {
  const CartaoAtendimentoLinha({
    super.key,
    required this.atendimento,
    required this.fundo,
    required this.borda,
    required this.apagado,
    required this.aoTocar,
  });

  final Atendimento atendimento;
  final Color fundo;
  final Color borda;
  final bool apagado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final a = atendimento;
    return Material(
      color: fundo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borda),
      ),
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.pacienteNome,
                        style: AppText.s(
                          15,
                          peso: FontWeight.w600,
                          altura: 20,
                          cor: apagado ? AppColors.textoSuave : AppColors.texto,
                          decoracao: a.status.inativo
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(a.servicoTexto,
                              style: AppText.s(13,
                                  altura: 18, cor: AppColors.textoSuave)),
                          ChipStatus(a.status),
                        ],
                      ),
                      if (a.temAdicional) ...[
                        const SizedBox(height: 4),
                        LinhaAdicional(a.adicionalTexto),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 24, color: AppColors.textoSuave),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "⊕ + Auriculoterapia 10 min"
class LinhaAdicional extends StatelessWidget {
  const LinhaAdicional(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.add_circle_outline_rounded,
            size: 14, color: AppColors.primariaForte),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            texto,
            style: AppText.s(12,
                peso: FontWeight.w600, altura: 16, cor: AppColors.primariaForte),
          ),
        ),
      ],
    );
  }
}
