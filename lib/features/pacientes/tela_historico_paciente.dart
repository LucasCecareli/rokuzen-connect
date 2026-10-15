import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/formatadores.dart';
import '../../data/models/modelos.dart';
import '../../widgets/folhas.dart';
import '../../widgets/responsivo.dart';
import 'componentes_pacientes.dart';

/// Histórico completo de sessões de um paciente, agrupado por mês.
class TelaHistoricoPaciente extends StatelessWidget {
  const TelaHistoricoPaciente({
    super.key,
    required this.paciente,
    required this.historico,
  });

  final Paciente paciente;

  /// Sessões do mais recente para o mais antigo.
  final List<Atendimento> historico;

  @override
  Widget build(BuildContext context) {
    final concluidas =
        historico.where((a) => a.status == StatusAtendimento.concluido).length;
    final primeira = historico.isEmpty ? null : historico.last.inicio;

    // Agrupa por mês, mantendo a ordem.
    final grupos = <(String, List<Atendimento>)>[];
    for (final a in historico) {
      final rotulo = mesAno(a.inicio);
      if (grupos.isEmpty || grupos.last.$1 != rotulo) {
        grupos.add((rotulo, [a]));
      } else {
        grupos.last.$2.add(a);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.fundo,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: LarguraConteudo(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 24, 0),
                child: Row(
                  children: [
                    const BotaoVoltar(dica: 'Voltar para o perfil'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Histórico de sessões',
                              style: AppText.s(22,
                                  peso: FontWeight.w700,
                                  altura: 28,
                                  espacamento: -0.2)),
                          const SizedBox(height: 2),
                          Text(paciente.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.s(14,
                                  altura: 20, cor: AppColors.textoSuave)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: CardMetrica(
                        valor: '$concluidas',
                        rotulo: concluidas == 1
                            ? 'Sessão realizada'
                            : 'Sessões realizadas',
                        icone: Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CardMetrica(
                        valor: primeira == null
                            ? '—'
                            : '${doisDigitos(primeira.day)}/${doisDigitos(primeira.month)}',
                        rotulo: primeira == null
                            ? 'Primeira sessão'
                            : 'Primeira sessão · ${primeira.year}',
                        icone: Icons.event_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              for (final (rotulo, sessoes) in grupos)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(rotulo,
                            style: AppText.s(15,
                                peso: FontWeight.w700, altura: 20)),
                      ),
                      const SizedBox(height: 8),
                      ListaHistorico(
                        sessoes: sessoes,
                        aoAbrir: (a) => abrirDetalhesAtendimento(context, a,
                            mostrarData: true),
                      ),
                    ],
                  ),
                ),
            ],
          )),
        ),
      ),
    );
  }
}
