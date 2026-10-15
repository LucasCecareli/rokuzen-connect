import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../core/app_text.dart';
import '../../core/formatadores.dart';
import '../../data/models/modelos.dart';
import '../../data/repositorio.dart';
import '../../widgets/componentes.dart';
import '../../widgets/responsivo.dart';
import '../../widgets/decoracao.dart';
import '../../widgets/folhas.dart';
import '../../widgets/linha_do_tempo.dart';

/// Aba "Início": resumo do dia, próximo atendimento e linha do dia.
class TelaInicio extends StatefulWidget {
  const TelaInicio({
    super.key,
    required this.terapeuta,
    required this.aoSair,
    required this.aoVerAgenda,
  });

  final Terapeuta terapeuta;
  final VoidCallback aoSair;
  final VoidCallback aoVerAgenda;

  @override
  State<TelaInicio> createState() => _TelaInicioState();
}

class _TelaInicioState extends State<TelaInicio> {
  List<Atendimento>? _hoje;
  Atendimento? _proximoOutroDia;
  Timer? _relogio;

  /// No modo de demonstração o relógio é fixo; ao iniciar um atendimento o
  /// "agora" avança até o horário dele (como no protótipo).
  DateTime? _agoraAjustado;
  DateTime get _agora => _agoraAjustado ?? agora();

  @override
  void initState() {
    super.initState();
    repositorio.addListener(_carregar);
    _carregar();
    if (!AppConfig.modoDemonstracao) {
      _relogio = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    repositorio.removeListener(_carregar);
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    final dia = soData(_agora);
    final lista =
        await repositorio.buscarAtendimentos(dia, somarDias(dia, 1));
    Atendimento? proximo;
    if (lista.isEmpty) {
      proximo = await repositorio.buscarProximoAtendimento(_agora);
    }
    if (!mounted) return;
    setState(() {
      _hoje = lista;
      _proximoOutroDia = proximo;
    });
  }

  Future<void> _iniciar(Atendimento a) async {
    final inicio = a.inicio;
    if (_agora.isBefore(inicio)) _agoraAjustado = inicio;
    // Só em memória: o status não é gravado no banco (ver repositorio.dart).
    await repositorio.alterarStatus(a.id, StatusAtendimento.andamento);
  }

  Future<void> _finalizar(Atendimento a) async {
    if (AppConfig.modoDemonstracao) _agoraAjustado = a.fim;
    await repositorio.alterarStatus(a.id, StatusAtendimento.concluido);
  }

  @override
  Widget build(BuildContext context) {
    final hoje = _agora;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: LarguraConteudo(child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              top: -157,
              right: -120,
              child: AnelEnso(tamanho: 300, espessura: 13),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CabecalhoTela(
                  sobretitulo:
                      '${diaSemanaCompleto(hoje)}, ${diaEMes(hoje)}'.toUpperCase(),
                  titulo: 'Olá, ${widget.terapeuta.primeiroNome}',
                  terapeuta: widget.terapeuta,
                  aoSair: widget.aoSair,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _conteudo(),
                ),
              ],
            ),
          ],
        )),
      ),
    );
  }

  Widget _conteudo() {
    final lista = _hoje;
    if (lista == null) return const _EsqueletoInicio();
    if (lista.isEmpty) return _diaVazio();

    final ativos = lista.where((a) => !a.status.inativo).toList();
    final concluidos =
        ativos.where((a) => a.status == StatusAtendimento.concluido).length;
    final total = ativos.length;
    Atendimento? emAndamento;
    Atendimento? proximo;
    for (final a in lista) {
      if (a.status == StatusAtendimento.andamento) emAndamento ??= a;
      if (a.status == StatusAtendimento.confirmado ||
          a.status == StatusAtendimento.pendente) {
        proximo ??= a;
      }
    }
    final destaque = emAndamento ?? proximo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cardResumo(concluidos, total),
        if (destaque != null) ...[
          const SizedBox(height: 24),
          TituloSecao(emAndamento != null ? 'Em andamento' : 'Próximo atendimento'),
          if (emAndamento != null)
            _CardEmAndamento(
              atendimento: emAndamento,
              agora: _agora,
              aoFinalizar: () => _finalizar(emAndamento!),
              aoVerDetalhes: () =>
                  abrirDetalhesAtendimento(context, emAndamento!),
            )
          else
            _CardProximo(
              atendimento: destaque,
              agora: _agora,
              aoIniciar: () => _iniciar(destaque),
              aoVerDetalhes: () => abrirDetalhesAtendimento(context, destaque),
            ),
        ] else ...[
          const SizedBox(height: 24),
          _diaConcluido(),
        ],
        const SizedBox(height: 32),
        TituloSecao(
          'Linha do dia',
          acao: Transform.translate(
            offset: const Offset(8, 0),
            child: BotaoTexto(
                rotulo: 'Ver agenda', aoPressionar: widget.aoVerAgenda),
          ),
        ),
        const SizedBox(height: 8),
        LinhaDoDia(
          atendimentos: lista,
          agora: _agora,
          aoAbrir: (a) => abrirDetalhesAtendimento(context, a),
        ),
      ],
    );
  }

  Widget _cardResumo(int concluidos, int total) {
    final hoje = _agora;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primariaSuave,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(
            right: -64,
            bottom: -96,
            child: AnelEnso(tamanho: 200, espessura: 10, rotacao: 300),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Semantics(
                  label: '$concluidos de $total atendimentos concluídos',
                  child: AnelProgresso(
                    progresso: total == 0 ? 0 : concluidos / total,
                    rotulo: '$concluidos/$total',
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$concluidos de $total concluídos',
                          style: AppText.s(18, peso: FontWeight.w700, altura: 24)),
                      const SizedBox(height: 8),
                      LinhaInfo(
                        icone: Icons.schedule_rounded,
                        texto:
                            'Expediente ${widget.terapeuta.turnoTexto(hoje)}',
                      ),
                      const SizedBox(height: 8),
                      LinhaInfo(
                        icone: Icons.location_on_outlined,
                        texto: widget.terapeuta.unidade,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diaConcluido() {
    return CardBranco(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.primariaSuave,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.primariaForte),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Atendimentos do dia concluídos',
                    style: AppText.s(16, peso: FontWeight.w700, altura: 24)),
                const SizedBox(height: 2),
                Text('Bom descanso, ${widget.terapeuta.primeiroNome}.',
                    style:
                        AppText.s(14, altura: 20, cor: AppColors.textoSuave)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diaVazio() {
    final p = _proximoOutroDia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EstadoVazio(
          icone: Icons.spa_outlined,
          titulo: 'Dia livre por aqui',
          texto:
              'Nenhum atendimento marcado para hoje. Aproveite para respirar fundo e cuidar de você.',
        ),
        if (p != null) ...[
          const SizedBox(height: 24),
          const TituloSecao('Próximo atendimento'),
          _CartaoProximoDia(
            atendimento: p,
            hoje: soData(_agora),
            aoTocar: () =>
                abrirDetalhesAtendimento(context, p, mostrarData: true),
          ),
        ],
      ],
    );
  }
}

/// Card branco do próximo atendimento (com contagem regressiva).
class _CardProximo extends StatelessWidget {
  const _CardProximo({
    required this.atendimento,
    required this.agora,
    required this.aoIniciar,
    required this.aoVerDetalhes,
  });

  final Atendimento atendimento;
  final DateTime agora;
  final VoidCallback aoIniciar;
  final VoidCallback aoVerDetalhes;

  @override
  Widget build(BuildContext context) {
    final a = atendimento;
    final faltam = a.inicio.difference(agora).inMinutes;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borda),
        boxShadow: sombraCard(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: HorarioGrande(inicio: a.inicio, fim: a.fim)),
              PilulaContagemRegressiva(contagemRegressiva(faltam)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              AvatarIniciais(iniciais: iniciais(a.pacienteNome)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.pacienteNome,
                        style: AppText.s(17, peso: FontWeight.w600, altura: 24)),
                    const SizedBox(height: 4),
                    ChipStatus(a.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divisor),
          const SizedBox(height: 16),
          LinhaServico(icone: Icons.spa_outlined, texto: a.servicoCompleto),
          const SizedBox(height: 8),
          LinhaServico(icone: Icons.meeting_room_outlined, texto: a.localTexto),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 16,
                child: BotaoPrimario(
                  rotulo: 'Iniciar atendimento',
                  aoPressionar: aoIniciar,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 10,
                child: BotaoSecundario(
                  rotulo: 'Ver detalhes',
                  aoPressionar: aoVerDetalhes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card escuro do atendimento em andamento.
class _CardEmAndamento extends StatelessWidget {
  const _CardEmAndamento({
    required this.atendimento,
    required this.agora,
    required this.aoFinalizar,
    required this.aoVerDetalhes,
  });

  final Atendimento atendimento;
  final DateTime agora;
  final VoidCallback aoFinalizar;
  final VoidCallback aoVerDetalhes;

  @override
  Widget build(BuildContext context) {
    final a = atendimento;
    final total = a.fim.difference(a.inicio).inMinutes;
    final passados = agora.difference(a.inicio).inMinutes;
    final progresso =
        total <= 0 ? 0.0 : (passados / total).clamp(0.0, 1.0).toDouble();
    final restam = a.fim.difference(agora).inMinutes;
    final textoRestante =
        passados <= 0 ? 'Iniciado agora' : 'Restam $restam min';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.texto,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.texto.withValues(alpha: 0.6),
            blurRadius: 32,
            spreadRadius: -16,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(
            top: -80,
            right: -80,
            child: AnelEnso(
                tamanho: 200, espessura: 9, rotacao: 200, intensidade: 1.1),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      height: 28,
                      padding: const EdgeInsets.only(left: 8, right: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaria.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PontoPulsante(),
                          const SizedBox(width: 6),
                          Text('Em andamento',
                              style: AppText.s(12,
                                  peso: FontWeight.w700,
                                  altura: 16,
                                  cor: AppColors.verdeClaroSnack)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(textoRestante,
                        style: AppText.s(14,
                            peso: FontWeight.w600,
                            altura: 20,
                            cor: AppColors.textoSobreEscuro2)),
                  ],
                ),
                const SizedBox(height: 16),
                HorarioGrande(
                    inicio: a.inicio, fim: a.fim, sobreEscuro: true),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Progresso do atendimento',
                  value: '${(progresso * 100).round()}%',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progresso,
                      minHeight: 8,
                      color: AppColors.primaria,
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    AvatarIniciais(
                      iniciais: iniciais(a.pacienteNome),
                      fundo: Colors.white.withValues(alpha: 0.1),
                      cor: Colors.white,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.pacienteNome,
                              style: AppText.s(17,
                                  peso: FontWeight.w600,
                                  altura: 24,
                                  cor: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                            '${a.servico.nome}${a.temAdicional ? ' + Auriculoterapia' : ''} · ${a.sala}',
                            style: AppText.s(13,
                                altura: 18, cor: AppColors.textoSobreEscuro),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 16,
                      child: BotaoPrimario(
                        rotulo: 'Finalizar atendimento',
                        icone: Icons.check_rounded,
                        sombra: false,
                        aoPressionar: aoFinalizar,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 10,
                      child: BotaoSecundario(
                        rotulo: 'Ver detalhes',
                        escuro: true,
                        aoPressionar: aoVerDetalhes,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Atalho para o próximo atendimento quando hoje não há nenhum.
class _CartaoProximoDia extends StatelessWidget {
  const _CartaoProximoDia({
    required this.atendimento,
    required this.hoje,
    required this.aoTocar,
  });

  final Atendimento atendimento;
  final DateTime hoje;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final a = atendimento;
    final amanha = mesmoDia(a.inicio, somarDias(hoje, 1));
    final quando = amanha
        ? 'Amanhã, ${hora(a.inicio)}'
        : '${diaSemanaCurto(a.inicio)}, ${hora(a.inicio)}';
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
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primariaSuave,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(diaSemanaSigla(a.inicio),
                        style: AppText.s(11,
                            peso: FontWeight.w700,
                            altura: 14,
                            cor: AppColors.primariaForte)),
                    Text('${a.inicio.day}',
                        style: AppText.s(16, peso: FontWeight.w700, altura: 20)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$quando · ${a.pacienteNome}',
                        style: AppText.s(15, peso: FontWeight.w600, altura: 20)),
                    const SizedBox(height: 2),
                    Text('${a.servicoTexto} · ${a.unidade}',
                        style: AppText.s(13,
                            altura: 18, cor: AppColors.textoSuave)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}

/// "14:00 – 15:00" em destaque.
class HorarioGrande extends StatelessWidget {
  const HorarioGrande({
    super.key,
    required this.inicio,
    required this.fim,
    this.sobreEscuro = false,
  });

  final DateTime inicio;
  final DateTime fim;
  final bool sobreEscuro;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: hora(inicio),
            style: AppText.s(28,
                peso: FontWeight.w700,
                altura: 36,
                espacamento: -0.4,
                cor: sobreEscuro ? Colors.white : AppColors.texto),
          ),
          TextSpan(
            text: '  – ${hora(fim)}',
            style: AppText.s(15,
                altura: 20,
                cor: sobreEscuro
                    ? AppColors.textoSobreEscuro
                    : AppColors.textoSuave),
          ),
        ],
      ),
    );
  }
}

/// Pílula escura "● em 25 min".
class PilulaContagemRegressiva extends StatelessWidget {
  const PilulaContagemRegressiva(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.texto,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PontoPulsante(),
          const SizedBox(width: 6),
          Text(texto,
              style: AppText.s(13,
                  peso: FontWeight.w700, altura: 16, cor: Colors.white)),
        ],
      ),
    );
  }
}

/// Linha com ícone cinza (serviço e sala).
class LinhaServico extends StatelessWidget {
  const LinhaServico({super.key, required this.icone, required this.texto});
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 20, color: AppColors.textoSuave),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texto,
              style: AppText.s(14,
                  altura: 20, cor: AppColors.textoSecundario)),
        ),
      ],
    );
  }
}

class _EsqueletoInicio extends StatelessWidget {
  const _EsqueletoInicio();

  @override
  Widget build(BuildContext context) {
    Widget linhaTempo() => const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Esqueleto(largura: 48, altura: 16, raio: 6),
              SizedBox(width: 16),
              Expanded(child: Esqueleto(altura: 64, raio: 16)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Esqueleto(altura: 120, raio: 24),
        const SizedBox(height: 32),
        const Align(
          alignment: Alignment.centerLeft,
          child: Esqueleto(largura: 180, altura: 24),
        ),
        const SizedBox(height: 16),
        CardBranco(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Esqueleto(largura: 140, altura: 32),
                  Esqueleto(largura: 88, altura: 32, raio: 16),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Esqueleto(largura: 48, altura: 48, circular: true),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: 0.7,
                          child: Esqueleto(altura: 16),
                        ),
                        SizedBox(height: 8),
                        FractionallySizedBox(
                          widthFactor: 0.4,
                          child: Esqueleto(altura: 12, raio: 6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Esqueleto(altura: 56, raio: 16)),
                  SizedBox(width: 8),
                  Esqueleto(largura: 112, altura: 56, raio: 16),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Align(
          alignment: Alignment.centerLeft,
          child: Esqueleto(largura: 120, altura: 24),
        ),
        const SizedBox(height: 16),
        linhaTempo(),
        linhaTempo(),
      ],
    );
  }
}
