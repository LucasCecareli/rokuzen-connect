import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/models/modelos.dart';
import '../../data/repositorio.dart';
import '../../widgets/componentes.dart';
import '../../widgets/responsivo.dart';
import '../agenda/tela_agenda.dart';
import '../disponibilidade/tela_disponibilidade.dart';
import '../inicio/tela_inicio.dart';
import '../pacientes/tela_pacientes.dart';

/// Estrutura principal depois do login: as quatro abas e a navegação
/// (barra inferior no celular, barra lateral no computador).
///
/// As abas ficam vivas em memória (trocar de aba mantém o estado de cada uma:
/// modo Semana na Agenda, dia selecionado na Disponibilidade etc.).
class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key, required this.aoSair});
  final VoidCallback aoSair;

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _aba = 0;
  Terapeuta? _terapeuta;
  final _navPacientes = GlobalKey<NavigatorState>();

  /// Incrementado em "Ver agenda": a Agenda volta para o modo Dia, hoje.
  final _sinalAgendaHoje = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _terapeuta = repositorio.terapeutaAtual;
    repositorio.addListener(_atualizarTerapeuta);
    _atualizarTerapeuta();
  }

  /// Busca a terapeuta com a escala de expediente (e de novo após
  /// "Tentar novamente", caso a escala não tenha carregado).
  void _atualizarTerapeuta() {
    repositorio.buscarTerapeuta().then((t) {
      if (mounted && !identical(t, _terapeuta)) {
        setState(() => _terapeuta = t);
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    repositorio.removeListener(_atualizarTerapeuta);
    _sinalAgendaHoje.dispose();
    super.dispose();
  }

  void _selecionarAba(int i) {
    if (i == _aba) {
      // Tocar de novo em "Pacientes" volta para a lista.
      if (i == 2) _navPacientes.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _aba = i);
  }

  void _verAgenda() {
    _sinalAgendaHoje.value++;
    setState(() => _aba = 1);
  }

  void _voltar() {
    final nav = _navPacientes.currentState;
    if (_aba == 2 && nav != null && nav.canPop()) {
      nav.pop();
    } else if (_aba != 0) {
      setState(() => _aba = 0);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _terapeuta;
    if (t == null) {
      return const Scaffold(backgroundColor: AppColors.fundo);
    }
    final abas = <Widget>[
      TelaInicio(terapeuta: t, aoSair: widget.aoSair, aoVerAgenda: _verAgenda),
      TelaAgenda(
          terapeuta: t, aoSair: widget.aoSair, sinalHoje: _sinalAgendaHoje),
      Navigator(
        key: _navPacientes,
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => TelaPacientes(terapeuta: t, aoSair: widget.aoSair),
        ),
      ),
      TelaDisponibilidade(terapeuta: t, aoSair: widget.aoSair),
    ];

    final largo = ehTelaLarga(context);
    final conteudo = Stack(
      children: [
        for (var i = 0; i < abas.length; i++)
          Positioned.fill(
            // A animação de opacidade fica POR FORA do TickerMode: assim a aba
            // que sai consegue terminar o fade e some de verdade.
            child: AnimatedOpacity(
              opacity: i == _aba ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: i != _aba,
                child: ExcludeSemantics(
                  excluding: i != _aba,
                  child: TickerMode(
                    enabled: i == _aba,
                    child: abas[i],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _voltar();
      },
      child: Scaffold(
        backgroundColor: AppColors.fundo,
        // A chave mantém o estado das abas quando a janela muda de tamanho.
        body: Row(
          children: [
            if (largo)
              BarraLateral(
                atual: _aba,
                aoSelecionar: _selecionarAba,
                terapeuta: t,
                aoSair: widget.aoSair,
              ),
            Expanded(
              key: const ValueKey('conteudo'),
              child: Column(
                children: [
                  ValueListenableBuilder<String?>(
                    valueListenable: repositorio.erroConexao,
                    builder: (context, erro, _) => erro == null
                        ? const SizedBox.shrink()
                        : _AvisoConexao(
                            mensagem: erro,
                            aoTentarDeNovo: repositorio.recarregar,
                          ),
                  ),
                  Expanded(child: conteudo),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: largo
            ? null
            : BarraNavegacao(atual: _aba, aoSelecionar: _selecionarAba),
      ),
    );
  }
}

/// Faixa exibida quando o servidor não responde.
class _AvisoConexao extends StatelessWidget {
  const _AvisoConexao({required this.mensagem, required this.aoTentarDeNovo});

  final String mensagem;
  final VoidCallback aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.erroFundo,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded,
                  color: AppColors.erro, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mensagem,
                  style: AppText.s(14, altura: 20, cor: AppColors.erroTexto),
                ),
              ),
              BotaoTexto(
                rotulo: 'Tentar novamente',
                cor: AppColors.erroTexto,
                aoPressionar: aoTentarDeNovo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
