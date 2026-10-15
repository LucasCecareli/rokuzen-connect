import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
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
    repositorio.buscarTerapeuta().then((t) {
      if (mounted) setState(() => _terapeuta = t);
    });
  }

  @override
  void dispose() {
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
            Expanded(key: const ValueKey('conteudo'), child: conteudo),
          ],
        ),
        bottomNavigationBar: largo
            ? null
            : BarraNavegacao(atual: _aba, aoSelecionar: _selecionarAba),
      ),
    );
  }
}
