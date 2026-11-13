import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../core/app_text.dart';
import '../../core/formatadores.dart';
import '../../data/services/admin_api_service.dart';
import '../../widgets/componentes.dart';
import '../../widgets/decoracao.dart';
import '../../widgets/responsivo.dart';
import '../../widgets/seletores.dart';
import 'folha_novo_agendamento.dart';
import 'tela_admin.dart';

/// Agendamentos de um dia, de todas as unidades ou de uma só, com
/// "Novo agendamento" e "Cancelar".
class AbaAgendamentos extends StatefulWidget {
  const AbaAgendamentos({super.key, required this.aoSair});
  final VoidCallback aoSair;

  @override
  State<AbaAgendamentos> createState() => _AbaAgendamentosState();
}

class _AbaAgendamentosState extends State<AbaAgendamentos> {
  final _api = AdminApiService();

  DateTime _dia = soData(agora());
  String? _unidadeId;
  List<UnidadeAdmin> _unidades = const [];
  List<AgendamentoAdmin>? _itens;
  String? _erro;
  final _cancelando = <String>{};
  int _pedido = 0;

  @override
  void initState() {
    super.initState();
    _carregarUnidades();
    _carregar();
  }

  Future<void> _carregarUnidades() async {
    try {
      final lista = await _api.unidades();
      if (mounted) setState(() => _unidades = lista);
    } catch (_) {
      // A lista de agendamentos mostra o erro de conexão.
    }
  }

  Future<void> _carregar() async {
    final pedido = ++_pedido;
    setState(() {
      _itens = null;
      _erro = null;
    });
    try {
      final itens = await _api.agendamentos(
        dia: _dia,
        unidadeId: _unidadeId,
        agora: agora(),
      );
      if (!mounted || pedido != _pedido) return;
      setState(() => _itens = itens);
    } catch (e) {
      if (!mounted || pedido != _pedido) return;
      setState(() {
        _itens = const [];
        _erro = '$e';
      });
    }
  }

  void _irPara(DateTime dia) {
    setState(() => _dia = soData(dia));
    _carregar();
  }

  Future<void> _escolherDia() async {
    final d = await escolherData(
      context,
      rotulo: 'Ver agendamentos de',
      inicial: _dia,
      hoje: agora(),
      mostrarAno: true,
    );
    if (d != null) _irPara(d);
  }

  Future<void> _novo() async {
    if (_unidades.isEmpty) await _carregarUnidades();
    if (!mounted) return;
    final criado = await abrirNovoAgendamento(
      context,
      unidades: _unidades,
      unidadeInicial: _unidadeId,
      diaInicial: _dia.isBefore(soData(agora())) ? soData(agora()) : _dia,
    );
    if (criado == null || !mounted) return;
    avisarAdmin(context, 'Agendamento criado para ${criado.paciente}.');
    _irPara(criado.dia);
  }

  Future<void> _cancelar(AgendamentoAdmin a) async {
    final ok = await confirmarAdmin(
      context,
      titulo: 'Cancelar agendamento?',
      texto: '${a.paciente} · ${hora(a.inicio)} com ${a.terapeuta}. '
          'O horário fica livre para outro agendamento.',
      rotuloConfirmar: 'Sim, cancelar',
      icone: Icons.event_busy_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _cancelando.add(a.id));
    try {
      await _api.cancelar(a.id);
      if (!mounted) return;
      avisarAdmin(context, 'Agendamento cancelado.');
      _carregar();
    } catch (e) {
      if (mounted) avisarAdmin(context, 'Não foi possível cancelar. $e', erro: true);
    } finally {
      if (mounted) setState(() => _cancelando.remove(a.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final itens = _itens;
    final ativos = itens?.where((a) => !a.status.inativo).length ?? 0;
    return Scaffold(
      backgroundColor: AppColors.fundo,
      floatingActionButton: BotaoFlutuante(
        rotulo: 'Novo agendamento',
        icone: Icons.add_rounded,
        aoPressionar: _novo,
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _carregar,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              LarguraConteudo(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CabecalhoAdmin(
                      titulo: 'Agendamentos',
                      subtitulo: 'Marque e cancele sessões em qualquer unidade.',
                      aoSair: widget.aoSair,
                    ),
                    const SizedBox(height: 20),
                    _navegacaoDia(),
                    const SizedBox(height: 12),
                    _filtroUnidades(),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _conteudo(itens, ativos),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navegacaoDia() {
    final hoje = mesmoDia(_dia, agora());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          BotaoIcone(
            icone: Icons.chevron_left_rounded,
            dica: 'Dia anterior',
            aoPressionar: () => _irPara(somarDias(_dia, -1)),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _escolherDia,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      hoje ? 'HOJE' : diaSemanaCompleto(_dia).toUpperCase(),
                      style: AppText.sobretitulo(),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${diaEMes(_dia)} de ${_dia.year}',
                          style: AppText.s(18,
                              peso: FontWeight.w700, altura: 24),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.calendar_month_outlined,
                            size: 18, color: AppColors.primariaForte),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          BotaoIcone(
            icone: Icons.chevron_right_rounded,
            dica: 'Próximo dia',
            aoPressionar: () => _irPara(somarDias(_dia, 1)),
          ),
          if (!hoje)
            BotaoTexto(rotulo: 'Hoje', aoPressionar: () => _irPara(agora())),
        ],
      ),
    );
  }

  Widget _filtroUnidades() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          OpcaoAdmin(
            rotulo: 'Todas as unidades',
            selecionada: _unidadeId == null,
            aoTocar: () {
              setState(() => _unidadeId = null);
              _carregar();
            },
          ),
          for (final u in _unidades) ...[
            const SizedBox(width: 8),
            OpcaoAdmin(
              rotulo: u.nome,
              selecionada: _unidadeId == u.id,
              aoTocar: () {
                setState(() => _unidadeId = u.id);
                _carregar();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _conteudo(List<AgendamentoAdmin>? itens, int ativos) {
    if (itens == null) {
      return Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            const Esqueleto(altura: 96, raio: 20),
            const SizedBox(height: 12),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_erro != null) ...[
          ErroAdmin(mensagem: _erro!, aoTentar: _carregar),
          const SizedBox(height: 16),
        ],
        if (itens.isEmpty && _erro == null)
          EstadoVazio(
            icone: Icons.event_available_rounded,
            titulo: 'Nenhum agendamento',
            texto: 'Não há sessões marcadas para este dia'
                '${_unidadeId == null ? '' : ' nesta unidade'}.',
            acao: BotaoPrimario(
              rotulo: 'Novo agendamento',
              icone: Icons.add_rounded,
              aoPressionar: _novo,
            ),
          )
        else if (itens.isNotEmpty) ...[
          Row(
            children: [
              Text(sessoesTexto(ativos), style: AppText.tituloSecao()),
              const Spacer(),
              if (itens.length != ativos)
                Text(
                  '${itens.length - ativos} cancelado(s) ou falta(s)',
                  style: AppText.s(13, cor: AppColors.textoSuave),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final a in itens) ...[
            _CartaoAgendamento(
              agendamento: a,
              cancelando: _cancelando.contains(a.id),
              aoCancelar: a.status.emAberto && a.fim.isAfter(agora())
                  ? () => _cancelar(a)
                  : null,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _CartaoAgendamento extends StatelessWidget {
  const _CartaoAgendamento({
    required this.agendamento,
    required this.cancelando,
    required this.aoCancelar,
  });

  final AgendamentoAdmin agendamento;
  final bool cancelando;
  final VoidCallback? aoCancelar;

  @override
  Widget build(BuildContext context) {
    final a = agendamento;
    final apagado = a.status.inativo;
    return Opacity(
      opacity: apagado ? 0.6 : 1,
      child: CardBranco(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        raio: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 56,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hora(a.inicio),
                          style: AppText.s(16,
                              peso: FontWeight.w700,
                              altura: 22,
                              numerosTabulares: true)),
                      Text(hora(a.fim),
                          style: AppText.s(13,
                              altura: 18,
                              cor: AppColors.textoSuave,
                              numerosTabulares: true)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.paciente,
                        style: AppText.s(16,
                            peso: FontWeight.w700,
                            altura: 22,
                            decoracao:
                                apagado ? TextDecoration.lineThrough : null),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${a.servico} · ${a.duracao} min',
                        style: AppText.s(14,
                            altura: 20, cor: AppColors.textoSecundario),
                      ),
                      Text(
                        'Com ${a.terapeuta} · ${a.unidade}',
                        style: AppText.s(13,
                            altura: 18, cor: AppColors.textoSuave),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ChipStatus(a.status),
              ],
            ),
            if (aoCancelar != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: cancelando
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Indicador(cor: AppColors.ausente),
                      )
                    : TextButton.icon(
                        onPressed: aoCancelar,
                        icon: const Icon(Icons.event_busy_rounded,
                            size: 18, color: AppColors.ausente),
                        label: Text('Cancelar agendamento',
                            style: AppText.s(14,
                                peso: FontWeight.w600,
                                cor: AppColors.ausente)),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
