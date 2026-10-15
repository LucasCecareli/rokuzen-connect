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
import '../../widgets/linha_do_tempo.dart';
import 'folha_disponibilidade.dart';

/// Aba "Disponibilidade": horários livres do terapeuta para atendimentos
/// particulares, fora do expediente na Rokuzen.
class TelaDisponibilidade extends StatefulWidget {
  const TelaDisponibilidade({
    super.key,
    required this.terapeuta,
    required this.aoSair,
  });

  final Terapeuta terapeuta;
  final VoidCallback aoSair;

  @override
  State<TelaDisponibilidade> createState() => _TelaDisponibilidadeState();
}

class _TelaDisponibilidadeState extends State<TelaDisponibilidade> {
  List<Disponibilidade>? _itens;
  late DateTime _selecionado = soData(agora());
  late DateTime _ancora = _selecionado;
  bool _recolhido = false;
  Aviso? _aviso;
  Timer? _timerAviso;

  DateTime get _hoje => soData(agora());

  @override
  void initState() {
    super.initState();
    repositorio.addListener(_carregar);
    _carregar();
  }

  @override
  void dispose() {
    repositorio.removeListener(_carregar);
    _timerAviso?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    final lista = await repositorio.buscarDisponibilidades();
    if (mounted) setState(() => _itens = lista);
  }

  void _mostrarAviso(Aviso aviso) {
    _timerAviso?.cancel();
    setState(() => _aviso = aviso);
    _timerAviso = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _aviso = null);
    });
  }

  void _avisoRemocao(Disponibilidade d) {
    _mostrarAviso(Aviso(
      texto: 'Horário removido',
      icone: Icons.delete_outline_rounded,
      acao: 'Desfazer',
      aoAcionar: () {
        _timerAviso?.cancel();
        setState(() => _aviso = null);
        repositorio.restaurarDisponibilidade(d);
      },
    ));
  }

  Future<void> _abrirFormulario({Disponibilidade? existente}) async {
    final r = await abrirFormularioDisponibilidade(
      context,
      terapeuta: widget.terapeuta,
      data: _selecionado,
      agora: agora(),
      cadastradas: _itens ?? const [],
      existente: existente,
    );
    if (r == null || !mounted) return;
    setState(() {
      _selecionado = soData(r.data);
      _ancora = _selecionado;
    });
    if (r.removida != null) {
      _avisoRemocao(r.removida!);
    } else {
      _mostrarAviso(Aviso(texto: r.mensagem));
    }
  }

  Future<void> _remover(Disponibilidade d) async {
    await repositorio.removerDisponibilidade(d.id);
    _avisoRemocao(d);
  }

  List<Disponibilidade> _doDia(DateTime dia) =>
      (_itens ?? const <Disponibilidade>[])
          .where((d) => mesmoDia(d.data, dia))
          .toList()
        ..sort((a, b) => a.inicio.compareTo(b.inicio));

  @override
  Widget build(BuildContext context) {
    final carregando = _itens == null;
    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 104),
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
                      sobretitulo: 'ATENDIMENTOS PARTICULARES',
                      titulo: 'Minha Disponibilidade',
                      subtitulo:
                          'Seus horários livres fora do expediente na Rokuzen.',
                      terapeuta: widget.terapeuta,
                      aoSair: widget.aoSair,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: carregando
                          ? const _EsqueletoDisponibilidade()
                          : _conteudo(),
                    ),
                  ],
                ),
              ],
            )),
          ),
        ),
        if (!carregando)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            right: 16,
            bottom: _aviso == null ? 16 : 80,
            child: BotaoFlutuante(
              rotulo: 'Adicionar horário',
              icone: Icons.add_rounded,
              aoPressionar: () => _abrirFormulario(),
            ),
          ),
        if (_aviso != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: Responsivo.larguraFolha),
                  child: AvisoFlutuante(aviso: _aviso!),
                ),
              ),
          ),
      ],
    );
  }

  Widget _conteudo() {
    final dia = _selecionado;
    final lista = _doDia(dia);
    final (tIni, tFim) = widget.terapeuta.turnoDe(dia);
    final ehHoje = mesmoDia(dia, _hoje);
    final livres = lista.where((d) => !d.reservado);
    final minutosLivres = livres.fold<int>(0, (s, d) => s + d.duracao);
    final reservados = lista.where((d) => d.reservado).length;
    final resumo = StringBuffer(minutosLivres > 0
        ? '${duracaoTexto(minutosLivres)} disponíve${minutosLivres == 1 ? 'l' : 'is'}'
        : 'Nenhum horário disponível');
    if (reservados > 0) {
      resumo.write(' · $reservados reservado${reservados > 1 ? 's' : ''}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _calendario(),
        const SizedBox(height: 16),
        CardResumo(children: [
          Text(
            '${diaSemanaCompleto(dia).toUpperCase()}${ehHoje ? ' · HOJE' : ''}',
            style: AppText.sobretitulo(),
          ),
          Text(diaEMes(dia),
              style: AppText.s(22,
                  peso: FontWeight.w700, altura: 28, espacamento: -0.2)),
          LinhaInfo(
            icone: Icons.event_available_outlined,
            texto: resumo.toString(),
            destaque: true,
          ),
          LinhaInfo(
            icone: Icons.lock_outline_rounded,
            texto: 'Expediente Rokuzen · ${horaDeMinutos(tIni)} – '
                '${horaDeMinutos(tFim)} · ${widget.terapeuta.unidade}',
          ),
        ]),
        const SizedBox(height: 24),
        _linhaDoTempo(lista, tIni, tFim, ehHoje),
        if (lista.isEmpty) ...[
          const SizedBox(height: 8),
          EstadoVazio(
            icone: Icons.event_available_outlined,
            titulo: 'Nenhum horário particular',
            texto: 'Adicione horários livres para ${diaSemanaMinusculo(dia)}, '
                '${diaEMes(dia)}, fora do seu expediente das '
                '${horaDeMinutos(tIni)} às ${horaDeMinutos(tFim)}.',
            acao: BotaoPrimario(
              rotulo: 'Adicionar horário',
              icone: Icons.add_rounded,
              aoPressionar: () => _abrirFormulario(),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------- calendário

  Widget _calendario() {
    final hoje = _hoje;
    List<Widget> celulas;
    String rotulo;
    bool podeVoltar;
    if (_recolhido) {
      final inicio = somarDias(_ancora, -(_ancora.weekday % 7)); // domingo
      final fim = somarDias(inicio, 6);
      celulas = [for (var i = 0; i < 7; i++) _celula(somarDias(inicio, i))];
      rotulo = intervaloDatas(inicio, fim);
      podeVoltar = inicio.isAfter(hoje);
    } else {
      final primeiro = DateTime(_ancora.year, _ancora.month, 1);
      final diasNoMes = DateTime(_ancora.year, _ancora.month + 1, 0).day;
      celulas = [
        for (var i = 0; i < primeiro.weekday % 7; i++) const SizedBox(),
        for (var d = 1; d <= diasNoMes; d++)
          _celula(DateTime(_ancora.year, _ancora.month, d)),
      ];
      rotulo = mesAno(_ancora);
      podeVoltar = _ancora.year > hoje.year ||
          (_ancora.year == hoje.year && _ancora.month > hoje.month);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borda),
        boxShadow: sombraCard(0.18),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _recolhido = !_recolhido;
                    _ancora = _selecionado;
                  }),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.texto,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(rotulo,
                          style: AppText.s(16,
                              peso: FontWeight.w700, altura: 24)),
                      const SizedBox(width: 4),
                      Icon(
                        _recolhido
                            ? Icons.expand_more_rounded
                            : Icons.expand_less_rounded,
                        size: 22,
                        color: AppColors.textoSuave,
                        semanticLabel: _recolhido
                            ? 'Mostrar mês inteiro'
                            : 'Recolher para a semana',
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                BotaoIcone(
                  icone: Icons.chevron_left_rounded,
                  dica: _recolhido ? 'Semana anterior' : 'Mês anterior',
                  aoPressionar: podeVoltar
                      ? () => setState(() => _ancora = _recolhido
                          ? somarDias(_ancora, -7)
                          : DateTime(_ancora.year, _ancora.month - 1, 1))
                      : null,
                ),
                BotaoIcone(
                  icone: Icons.chevron_right_rounded,
                  dica: _recolhido ? 'Próxima semana' : 'Próximo mês',
                  aoPressionar: () => setState(() => _ancora = _recolhido
                      ? somarDias(_ancora, 7)
                      : DateTime(_ancora.year, _ancora.month + 1, 1)),
                ),
              ],
            ),
          ),
          Row(
            children: [
              for (final l in iniciaisSemanaDomingo)
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: Center(
                      child: Text(l,
                          style: AppText.s(12,
                              peso: FontWeight.w700,
                              altura: 16,
                              cor: AppColors.textoSuave)),
                    ),
                  ),
                ),
            ],
          ),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 48,
            ),
            children: celulas,
          ),
        ],
      ),
    );
  }

  Widget _celula(DateTime dia) {
    final sel = mesmoDia(dia, _selecionado);
    final hoje = mesmoDia(dia, _hoje);
    final passado = dia.isBefore(_hoje);
    final temHorario = !passado && _doDia(dia).isNotEmpty;
    final cor = sel
        ? AppColors.sobrePrimaria
        : passado
            ? AppColors.cinzaNo
            : hoje
                ? AppColors.primariaForte
                : AppColors.texto;
    return Semantics(
      button: true,
      selected: sel,
      label: '${dataPorExtenso(dia)}${hoje ? ' (hoje)' : ''}'
          '${temHorario ? ', com disponibilidade' : ''}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: passado
            ? null
            : () => setState(() {
                  _selecionado = dia;
                  _ancora = dia;
                }),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: sel ? AppColors.primaria : Colors.transparent,
              shape: BoxShape.circle,
              border: hoje && !sel
                  ? Border.all(color: AppColors.primariaForte, width: 2)
                  : null,
              boxShadow: sel && hoje
                  ? const [
                      BoxShadow(color: AppColors.primariaForte, spreadRadius: 4),
                      BoxShadow(color: Colors.white, spreadRadius: 2),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text('${dia.day}',
                    style: AppText.s(14,
                        altura: 20,
                        peso: sel || hoje ? FontWeight.w700 : FontWeight.w500,
                        cor: cor)),
                if (temHorario)
                  Positioned(
                    bottom: 5,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.sobrePrimaria
                            : AppColors.primariaForte,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------ linha do tempo

  Widget _linhaDoTempo(
      List<Disponibilidade> lista, int tIni, int tFim, bool ehHoje) {
    // Itens do dia + o bloco do expediente, em ordem de horário.
    final itens = <(int, Disponibilidade?)>[
      for (final d in lista) (d.inicio, d),
      (tIni, null),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final agoraMin = minutosDoDia(agora());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < itens.length; i++)
          _itemLinha(
            itens[i].$2,
            tIni,
            tFim,
            acima: i > 0 ? linhaTracejada : null,
            abaixo: i < itens.length - 1 ? linhaTracejada : null,
            passou: ehHoje &&
                itens[i].$2 != null &&
                itens[i].$2!.fim <= agoraMin,
          ),
      ],
    );
  }

  Widget _itemLinha(
    Disponibilidade? d,
    int tIni,
    int tFim, {
    EstiloLinha? acima,
    EstiloLinha? abaixo,
    required bool passou,
  }) {
    final inicio = d?.inicio ?? tIni;
    final fim = d?.fim ?? tFim;
    final corHora = d == null
        ? AppColors.textoSecundario
        : passou
            ? AppColors.textoSuave
            : d.reservado
                ? AppColors.texto
                : AppColors.primariaForte;
    final hora = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(horaDeMinutos(inicio),
            style: AppText.s(14, peso: FontWeight.w600, altura: 20, cor: corHora)),
        Text(horaDeMinutos(fim),
            style: AppText.s(12, altura: 16, cor: AppColors.textoSuave)),
      ],
    );

    final Widget no;
    final Widget conteudo;
    if (d == null) {
      no = const NoLinha(
        fundo: Color(0xFFF0EDE9),
        borda: AppColors.cinzaNo,
        icone: Icons.lock_rounded,
        corIcone: AppColors.textoSecundario,
      );
      conteudo = _BlocoExpediente(
        unidade: widget.terapeuta.unidade,
        faixa: '${horaDeMinutos(tIni)} às ${horaDeMinutos(tFim)}',
      );
    } else if (d.reservado) {
      no = const NoLinha(
        fundo: AppColors.texto,
        borda: AppColors.texto,
        icone: Icons.person_rounded,
      );
      conteudo = _CartaoReservado(
        d: d,
        aoTocar: () => _mostrarAviso(Aviso(
          texto: 'Reservado por ${d.clienteReservado}. Remarque com a '
              'cliente antes de alterar ou excluir.',
          icone: Icons.info_rounded,
        )),
      );
    } else {
      no = NoLinha(
        fundo: Colors.white,
        borda: passou ? AppColors.alca : AppColors.primariaForte,
      );
      conteudo = _CartaoLivre(
        d: d,
        passou: passou,
        aoEditar: () => _abrirFormulario(existente: d),
        aoExcluir: () => _remover(d),
      );
    }

    return ItemLinhaDoTempo(
      hora: hora,
      topoHora: 14,
      no: no,
      acima: acima,
      abaixo: abaixo,
      opacidade: passou ? 0.6 : 1,
      conteudo: conteudo,
    );
  }
}

class _BlocoExpediente extends StatelessWidget {
  const _BlocoExpediente({required this.unidade, required this.faixa});
  final String unidade;
  final String faixa;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Expediente Rokuzen das $faixa, bloqueado para particulares',
      excludeSemantics: true,
      child: FundoListrado(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_rounded,
                        size: 18, color: AppColors.textoSecundario),
                    const SizedBox(width: 8),
                    Text('Expediente Rokuzen',
                        style: AppText.s(15, peso: FontWeight.w700, altura: 20)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('$unidade · bloqueado para particulares',
                    style: AppText.s(13,
                        altura: 18, cor: AppColors.textoSecundario)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartaoLivre extends StatelessWidget {
  const _CartaoLivre({
    required this.d,
    required this.passou,
    required this.aoEditar,
    required this.aoExcluir,
  });

  final Disponibilidade d;
  final bool passou;
  final VoidCallback aoEditar;
  final VoidCallback aoExcluir;

  @override
  Widget build(BuildContext context) {
    final faixa = '${horaDeMinutos(d.inicio)} – ${horaDeMinutos(d.fim)}';
    return Material(
      color: d.nova
          ? AppColors.hover
          : passou
              ? Colors.transparent
              : AppColors.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borda),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: passou ? null : aoEditar,
              child: Semantics(
                button: !passou,
                label: 'Editar horário $faixa',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
                    child: Row(
                      children: [
                        const Etiqueta(
                          texto: 'Disponível',
                          icone: Icons.event_available_rounded,
                          fundo: AppColors.primariaSuave,
                          cor: AppColors.primariaEscura,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            duracaoTexto(d.duracao) +
                                (passou ? ' · encerrado' : ''),
                            style: AppText.s(13,
                                altura: 18, cor: AppColors.textoSuave),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!passou)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: BotaoIcone(
                icone: Icons.delete_outline_rounded,
                dica: 'Excluir horário $faixa',
                cor: AppColors.textoSuave,
                tamanhoIcone: 22,
                aoPressionar: aoExcluir,
              ),
            ),
        ],
      ),
    );
  }
}

class _CartaoReservado extends StatelessWidget {
  const _CartaoReservado({required this.d, required this.aoTocar});
  final Disponibilidade d;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final faixa = '${horaDeMinutos(d.inicio)} – ${horaDeMinutos(d.fim)}';
    return Material(
      color: AppColors.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.texto),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Semantics(
          label: 'Reservado por ${d.clienteReservado}, $faixa',
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.clienteReservado ?? '',
                            style: AppText.s(15,
                                peso: FontWeight.w600, altura: 20)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Etiqueta(
                              texto: 'Reservado',
                              icone: Icons.person_rounded,
                              fundo: AppColors.texto,
                              cor: Colors.white,
                              negrito: true,
                            ),
                            const SizedBox(width: 8),
                            Text(duracaoTexto(d.duracao),
                                style: AppText.s(13,
                                    altura: 18, cor: AppColors.textoSuave)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.lock_rounded,
                        size: 22, color: AppColors.cinzaNo),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EsqueletoDisponibilidade extends StatelessWidget {
  const _EsqueletoDisponibilidade();

  @override
  Widget build(BuildContext context) {
    Widget linha(double altura) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              const SizedBox(
                width: 48,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Esqueleto(largura: 40, altura: 14, raio: 6),
                    SizedBox(height: 6),
                    Esqueleto(largura: 32, altura: 10, raio: 5),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Esqueleto(largura: 24, altura: 24, circular: true),
              const SizedBox(width: 12),
              Expanded(child: Esqueleto(altura: altura, raio: 16)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Esqueleto(altura: 320, raio: 24),
        const SizedBox(height: 16),
        const Esqueleto(altura: 120, raio: 24),
        const SizedBox(height: 8),
        linha(64),
        linha(96),
        linha(64),
      ],
    );
  }
}
