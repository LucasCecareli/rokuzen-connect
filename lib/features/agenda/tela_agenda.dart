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

enum _Modo { dia, semana }

/// Aba "Agenda": visão diária (linha do tempo) e semanal (agrupada por dia).
class TelaAgenda extends StatefulWidget {
  const TelaAgenda({
    super.key,
    required this.terapeuta,
    required this.aoSair,
    required this.sinalHoje,
  });

  final Terapeuta terapeuta;
  final VoidCallback aoSair;

  /// Quando muda, a agenda volta para o modo Dia, no dia de hoje.
  final ValueNotifier<int> sinalHoje;

  @override
  State<TelaAgenda> createState() => _TelaAgendaState();
}

class _TelaAgendaState extends State<TelaAgenda> {
  _Modo _modo = _Modo.dia;
  late DateTime _inicioSemana = inicioDaSemana(agora());
  late DateTime _selecionado = soData(agora());
  List<Atendimento>? _semana;
  int _requisicao = 0;
  final _rolagem = ScrollController();

  DateTime get _hoje => soData(agora());

  @override
  void initState() {
    super.initState();
    repositorio.addListener(_recarregar);
    widget.sinalHoje.addListener(_irParaHoje);
    _carregar();
  }

  @override
  void dispose() {
    repositorio.removeListener(_recarregar);
    widget.sinalHoje.removeListener(_irParaHoje);
    _rolagem.dispose();
    super.dispose();
  }

  void _recarregar() => _carregar(mostrarCarregando: false);

  Future<void> _carregar({bool mostrarCarregando = true}) async {
    final id = ++_requisicao;
    if (mostrarCarregando) setState(() => _semana = null);
    final lista = await repositorio.buscarAtendimentos(
        _inicioSemana, somarDias(_inicioSemana, 7));
    if (!mounted || id != _requisicao) return;
    setState(() => _semana = lista);
  }

  void _topo() {
    if (_rolagem.hasClients) _rolagem.jumpTo(0);
  }

  void _irParaSemana(DateTime inicio, {DateTime? selecionar}) {
    final mudou = !mesmoDia(inicio, _inicioSemana);
    setState(() {
      _inicioSemana = inicio;
      _selecionado = selecionar ??
          somarDias(inicio, _selecionado.weekday - 1);
    });
    if (mudou) _carregar();
    _topo();
  }

  void _irParaHoje() {
    setState(() => _modo = _Modo.dia);
    _irParaSemana(inicioDaSemana(_hoje), selecionar: _hoje);
  }

  List<Atendimento> _doDia(DateTime dia) =>
      (_semana ?? const <Atendimento>[])
          .where((a) => mesmoDia(a.inicio, dia))
          .toList();

  int _sessoes(Iterable<Atendimento> l) =>
      l.where((a) => !a.status.inativo).length;

  @override
  Widget build(BuildContext context) {
    final fimSemana = somarDias(_inicioSemana, 6);
    final vendoHoje = mesmoDia(_selecionado, _hoje);
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        controller: _rolagem,
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
                  sobretitulo: mesAno(_selecionado).toUpperCase(),
                  titulo: 'Minha Agenda',
                  terapeuta: widget.terapeuta,
                  aoSair: widget.aoSair,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _SeletorModo(
                    modo: _modo,
                    aoMudar: (m) {
                      setState(() => _modo = m);
                      _topo();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(intervaloDatas(_inicioSemana, fimSemana),
                            style: AppText.s(16,
                                peso: FontWeight.w700, altura: 24)),
                      ),
                      Opacity(
                        opacity: vendoHoje ? 0.5 : 1,
                        child: _BotaoHoje(aoPressionar: _irParaHoje),
                      ),
                      BotaoIcone(
                        icone: Icons.chevron_left_rounded,
                        dica: 'Semana anterior',
                        aoPressionar: () =>
                            _irParaSemana(somarDias(_inicioSemana, -7)),
                      ),
                      BotaoIcone(
                        icone: Icons.chevron_right_rounded,
                        dica: 'Próxima semana',
                        aoPressionar: () =>
                            _irParaSemana(somarDias(_inicioSemana, 7)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: _faixaDias(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _semana == null
                      ? _EsqueletoAgenda(semana: _modo == _Modo.semana)
                      : _modo == _Modo.dia
                          ? _visaoDia()
                          : _visaoSemana(),
                ),
              ],
            ),
          ],
        )),
      ),
    );
  }

  Widget _faixaDias() {
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(child: _diaFaixa(somarDias(_inicioSemana, i))),
      ],
    );
  }

  Widget _diaFaixa(DateTime dia) {
    final sel = mesmoDia(dia, _selecionado);
    final hoje = mesmoDia(dia, _hoje);
    final passado = dia.isBefore(_hoje);
    final atendimentos = _doDia(dia);
    final qtd = _sessoes(atendimentos);
    final corRotulo = sel
        ? AppColors.sobrePrimaria
        : hoje
            ? AppColors.primariaForte
            : AppColors.textoSuave;
    final corNumero = sel
        ? AppColors.sobrePrimaria
        : hoje
            ? AppColors.primariaForte
            : passado
                ? AppColors.textoSuave
                : AppColors.texto;
    final corPonto = sel
        ? AppColors.sobrePrimaria
        : passado
            ? AppColors.cinzaNo
            : AppColors.primaria;
    return Semantics(
      button: true,
      selected: sel,
      label: '${dataPorExtenso(dia)}${hoje ? ' (hoje)' : ''}'
          '${qtd > 0 ? ', ${sessoesTexto(qtd)}' : ''}',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _selecionado = dia;
            _modo = _Modo.dia;
          });
          _topo();
        },
        child: SizedBox(
          height: 72,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 64,
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.primaria
                    : hoje
                        ? AppColors.superficie
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: hoje && !sel
                    ? Border.all(color: AppColors.primariaForte, width: 2)
                    : null,
                boxShadow: sel && hoje
                    ? const [
                        BoxShadow(color: AppColors.primariaForte, spreadRadius: 4),
                        BoxShadow(color: AppColors.fundo, spreadRadius: 2),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(diaSemanaSigla(dia),
                      style: AppText.s(11,
                          peso: FontWeight.w700,
                          altura: 16,
                          espacamento: 0.4,
                          cor: corRotulo)),
                  const SizedBox(height: 2),
                  Text(doisDigitos(dia.day),
                      style: AppText.s(16,
                          peso: FontWeight.w700, altura: 20, cor: corNumero)),
                  const SizedBox(height: 2),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: atendimentos.isEmpty
                          ? Colors.transparent
                          : corPonto,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _visaoDia() {
    final dia = _selecionado;
    final lista = _doDia(dia);
    final ehHoje = mesmoDia(dia, _hoje);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardResumo(children: [
          Text(
            '${diaSemanaCompleto(dia).toUpperCase()}${ehHoje ? ' · HOJE' : ''}',
            style: AppText.sobretitulo(),
          ),
          Row(
            children: [
              Expanded(
                child: Text(diaEMes(dia),
                    style: AppText.s(22,
                        peso: FontWeight.w700, altura: 28, espacamento: -0.2)),
              ),
              const SizedBox(width: 16),
              PilulaContagem(sessoesTexto(_sessoes(lista))),
            ],
          ),
          LinhaInfo(
            icone: Icons.schedule_rounded,
            texto: 'Expediente ${widget.terapeuta.turnoTexto(dia)} · '
                '${widget.terapeuta.unidade}',
          ),
        ]),
        if (lista.isEmpty) ...[
          const SizedBox(height: 24),
          EstadoVazio(
            icone: Icons.spa_outlined,
            titulo: 'Dia livre por aqui',
            texto: 'Nenhum atendimento marcado para '
                '${diaSemanaMinusculo(dia)}, ${diaEMes(dia)}.',
          ),
        ] else ...[
          const SizedBox(height: 24),
          LinhaDoDia(
            atendimentos: lista,
            agora: ehHoje ? agora() : null,
            mostrarFim: true,
            aoAbrir: (a) =>
                abrirDetalhesAtendimento(context, a, mostrarData: true),
          ),
        ],
      ],
    );
  }

  Widget _visaoSemana() {
    final inicio = _inicioSemana;
    final fim = somarDias(inicio, 6);
    final semanaAtual = inicioDaSemana(_hoje);
    // Arredonda para não errar em semanas com horário de verão.
    final diferenca = (inicio.difference(semanaAtual).inHours / 168).round();
    final sobretitulo = switch (diferenca) {
      0 => 'SEMANA ATUAL',
      1 => 'PRÓXIMA SEMANA',
      -1 => 'SEMANA ANTERIOR',
      > 1 => 'DAQUI A $diferenca SEMANAS',
      _ => 'HÁ ${-diferenca} SEMANAS',
    };
    final t = widget.terapeuta;
    final turnoSemana = '${horaDeMinutos(t.inicioTurno)} – ${horaDeMinutos(t.fimTurno)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardResumo(children: [
          Text(sobretitulo, style: AppText.sobretitulo()),
          Row(
            children: [
              Expanded(
                child: Text(intervaloDatas(inicio, fim),
                    style: AppText.s(22,
                        peso: FontWeight.w700, altura: 28, espacamento: -0.2)),
              ),
              const SizedBox(width: 16),
              PilulaContagem(sessoesTexto(_sessoes(_semana!))),
            ],
          ),
          LinhaInfo(
            icone: Icons.schedule_rounded,
            texto: 'Seg–sáb $turnoSemana · Dom 14:00 – 20:00',
          ),
          LinhaInfo(icone: Icons.location_on_outlined, texto: t.unidade),
        ]),
        for (var i = 0; i < 7; i++) ...[
          const SizedBox(height: 24),
          _grupoDia(somarDias(inicio, i)),
        ],
      ],
    );
  }

  Widget _grupoDia(DateTime dia) {
    final lista = _doDia(dia);
    final hoje = mesmoDia(dia, _hoje);
    final passado = dia.isBefore(_hoje);
    Atendimento? proximo;
    if (hoje) {
      for (final a in lista) {
        if (a.status.emAberto) {
          proximo = a;
          break;
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('${diaSemanaCompleto(dia)}, ${dia.day}',
                style: AppText.s(15,
                    peso: FontWeight.w700,
                    altura: 20,
                    cor: passado ? AppColors.textoSuave : AppColors.texto)),
            if (hoje) ...[
              const SizedBox(width: 8),
              const Etiqueta(
                texto: 'HOJE',
                fundo: AppColors.texto,
                cor: Colors.white,
                negrito: true,
              ),
            ],
            const Spacer(),
            if (lista.isNotEmpty)
              Text(sessoesTexto(_sessoes(lista)),
                  style: AppText.s(12,
                      peso: FontWeight.w600,
                      altura: 16,
                      cor: AppColors.textoSuave)),
          ],
        ),
        const SizedBox(height: 8),
        if (lista.isEmpty)
          const CaixaTracejada(
            icone: Icons.event_available_outlined,
            texto: 'Sem atendimentos',
            altura: 48,
            tamanhoTexto: 13,
          )
        else
          Container(
            decoration: BoxDecoration(
              color: passado ? Colors.transparent : AppColors.superficie,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: hoje ? AppColors.primaria : AppColors.borda),
              boxShadow: hoje ? sombraCard() : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (var k = 0; k < lista.length; k++)
                    _linhaSemana(lista[k], k > 0, passado, lista[k].id == proximo?.id),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _linhaSemana(
      Atendimento a, bool divisor, bool diaPassado, bool ehProximo) {
    final apagado =
        a.status == StatusAtendimento.concluido || a.status.inativo || diaPassado;
    return InkWell(
      onTap: () => abrirDetalhesAtendimento(context, a, mostrarData: true),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: divisor
              ? const Border(top: BorderSide(color: AppColors.divisor))
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hora(a.inicio),
                      style: AppText.s(14,
                          peso: FontWeight.w700,
                          altura: 20,
                          cor: apagado
                              ? AppColors.textoSuave
                              : ehProximo
                                  ? AppColors.primariaForte
                                  : AppColors.texto)),
                  Text(hora(a.fim),
                      style:
                          AppText.s(12, altura: 16, cor: AppColors.textoSuave)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.pacienteNome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.s(
                      15,
                      peso: FontWeight.w600,
                      altura: 20,
                      cor: apagado ? AppColors.textoSuave : AppColors.texto,
                      decoracao:
                          a.status.inativo ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(a.servicoTexto,
                      style:
                          AppText.s(13, altura: 18, cor: AppColors.textoSuave)),
                  if (a.temAdicional) ...[
                    const SizedBox(height: 2),
                    LinhaAdicional(a.adicionalTexto),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            IconeStatus(a.status),
          ],
        ),
      ),
    );
  }
}

/// Alternância "Dia | Semana".
class _SeletorModo extends StatelessWidget {
  const _SeletorModo({required this.modo, required this.aoMudar});
  final _Modo modo;
  final ValueChanged<_Modo> aoMudar;

  @override
  Widget build(BuildContext context) {
    Widget opcao(_Modo m, String rotulo) {
      final sel = m == modo;
      return Expanded(
        child: Semantics(
          button: true,
          selected: sel,
          child: InkWell(
            onTap: () => aoMudar(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              color: sel ? AppColors.primariaSuave : Colors.transparent,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sel) ...[
                    const Icon(Icons.check_rounded,
                        size: 18, color: AppColors.primariaEscura),
                    const SizedBox(width: 8),
                  ],
                  Text(rotulo,
                      style: AppText.s(14,
                          altura: 20,
                          peso: sel ? FontWeight.w700 : FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.contorno),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          children: [
            opcao(_Modo.dia, 'Dia'),
            Container(width: 1, color: AppColors.contorno),
            opcao(_Modo.semana, 'Semana'),
          ],
        ),
      ),
    );
  }
}

class _BotaoHoje extends StatelessWidget {
  const _BotaoHoje({required this.aoPressionar});
  final VoidCallback aoPressionar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Voltar para hoje',
      child: InkWell(
        onTap: aoPressionar,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.contorno),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.today_rounded,
                      size: 16, color: AppColors.primariaEscura),
                  const SizedBox(width: 4),
                  Text('Hoje',
                      style: AppText.s(13,
                          peso: FontWeight.w700,
                          altura: 16,
                          cor: AppColors.primariaEscura)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EsqueletoAgenda extends StatelessWidget {
  const _EsqueletoAgenda({required this.semana});
  final bool semana;

  @override
  Widget build(BuildContext context) {
    if (semana) {
      Widget grupo(double altura) => Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Esqueleto(largura: 144, altura: 16, raio: 6),
                    Esqueleto(largura: 56, altura: 12, raio: 6),
                  ],
                ),
                const SizedBox(height: 8),
                Esqueleto(altura: altura, raio: 16),
              ],
            ),
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Esqueleto(altura: 136, raio: 24),
          grupo(128),
          grupo(128),
          grupo(64),
        ],
      );
    }
    Widget linha() => const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Row(
            children: [
              SizedBox(
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
              SizedBox(width: 12),
              Esqueleto(largura: 24, altura: 24, circular: true),
              SizedBox(width: 12),
              Expanded(child: Esqueleto(altura: 72, raio: 16)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Esqueleto(altura: 112, raio: 24),
        const SizedBox(height: 8),
        linha(),
        linha(),
        linha(),
        linha(),
      ],
    );
  }
}
