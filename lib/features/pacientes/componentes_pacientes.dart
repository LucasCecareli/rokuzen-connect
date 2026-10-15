import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/formatadores.dart';
import '../../data/models/modelos.dart';
import '../../widgets/componentes.dart';
import '../../widgets/linha_do_tempo.dart';

/// Card de métrica ("8 · Sessões realizadas").
class CardMetrica extends StatelessWidget {
  const CardMetrica({
    super.key,
    required this.valor,
    required this.rotulo,
    required this.icone,
    this.iconePreenchido = false,
  });

  final String valor;
  final String rotulo;
  final IconData icone;
  final bool iconePreenchido;

  @override
  Widget build(BuildContext context) {
    return CardBranco(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valor,
              style: AppText.s(24,
                  peso: FontWeight.w700, altura: 32, espacamento: -0.3)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icone, size: 16, color: AppColors.primariaForte),
              const SizedBox(width: 4),
              Expanded(
                child: Text(rotulo,
                    style: AppText.s(13,
                        altura: 18, cor: AppColors.textoSecundario)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lista de sessões em linha do tempo (perfil e histórico completo).
class ListaHistorico extends StatelessWidget {
  const ListaHistorico({
    super.key,
    required this.sessoes,
    required this.aoAbrir,
  });

  final List<Atendimento> sessoes;
  final ValueChanged<Atendimento> aoAbrir;

  @override
  Widget build(BuildContext context) {
    EstiloLinha? abaixo(int i) {
      if (i >= sessoes.length - 1) return null;
      final continua = sessoes[i].status == StatusAtendimento.concluido &&
          sessoes[i + 1].status == StatusAtendimento.concluido;
      return continua ? linhaContinua : linhaTracejada;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sessoes.length; i++)
          ItemLinhaDoTempo(
            topoNo: 16,
            acima: i > 0 ? abaixo(i - 1) : null,
            abaixo: abaixo(i),
            no: _no(sessoes[i].status),
            conteudo: _CartaoSessao(
              sessao: sessoes[i],
              aoTocar: () => aoAbrir(sessoes[i]),
            ),
          ),
      ],
    );
  }

  Widget _no(StatusAtendimento s) {
    if (s == StatusAtendimento.concluido) {
      return const NoLinha(
        fundo: AppColors.primariaForte,
        borda: AppColors.primariaForte,
        icone: Icons.check_rounded,
      );
    }
    if (s.inativo) {
      return const NoLinha(
        fundo: Color(0xFFF0EDE9),
        borda: AppColors.alca,
        icone: Icons.close_rounded,
        corIcone: AppColors.textoSuave,
      );
    }
    return const NoLinha(fundo: Colors.white, borda: AppColors.cinzaNo);
  }
}

class _CartaoSessao extends StatelessWidget {
  const _CartaoSessao({required this.sessao, required this.aoTocar});
  final Atendimento sessao;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final a = sessao;
    return Material(
      color: AppColors.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borda),
      ),
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dataEtiqueta(a.inicio),
                      style: AppText.s(12,
                          peso: FontWeight.w700,
                          altura: 16,
                          espacamento: 1,
                          cor: AppColors.primariaForte),
                    ),
                  ),
                  ChipStatus(a.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${hora(a.inicio)} – ${hora(a.fim)}',
                style: AppText.s(15,
                    peso: FontWeight.w600,
                    altura: 20,
                    decoracao:
                        a.status.inativo ? TextDecoration.lineThrough : null),
              ),
              const SizedBox(height: 4),
              Text(a.servicoTexto,
                  style: AppText.s(13,
                      altura: 18, cor: AppColors.textoSecundario)),
              if (a.temAdicional) ...[
                const SizedBox(height: 4),
                LinhaAdicional(a.adicionalTexto),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: AppColors.textoSuave),
                  const SizedBox(width: 4),
                  Text(a.unidade,
                      style: AppText.s(13,
                          altura: 18, cor: AppColors.textoSuave)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão redondo de voltar (48px, com borda).
class BotaoVoltar extends StatelessWidget {
  const BotaoVoltar({super.key, required this.dica});
  final String dica;

  @override
  Widget build(BuildContext context) {
    return BotaoIcone(
      icone: Icons.arrow_back_rounded,
      dica: dica,
      contorno: true,
      aoPressionar: () => Navigator.of(context).maybePop(),
    );
  }
}
