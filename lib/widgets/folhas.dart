import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_config.dart';
import '../core/app_text.dart';
import '../core/formatadores.dart';
import '../data/models/modelos.dart';
import '../data/repositorio.dart';
import 'componentes.dart';
import 'decoracao.dart';
import 'responsivo.dart';

/// Abre uma folha inferior (bottom sheet) no estilo do protótipo:
/// cantos de 28px, véu marrom e alça para arrastar.
Future<T?> abrirFolha<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool podeFechar = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    isDismissible: podeFechar,
    enableDrag: podeFechar,
    backgroundColor: AppColors.superficie,
    barrierColor: AppColors.veu,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    // No computador a folha não ocupa a largura inteira da janela.
    constraints: const BoxConstraints(maxWidth: Responsivo.larguraFolha),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: builder(context),
    ),
  );
}

/// Alça cinza no topo das folhas.
class AlcaFolha extends StatelessWidget {
  const AlcaFolha({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.alca,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Estrutura de folha com formulário: alça, anel decorativo, título,
/// subtítulo e botão fechar.
class FolhaFormulario extends StatelessWidget {
  const FolhaFormulario({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.aoFechar,
    required this.children,
  });

  final String titulo;
  final String subtitulo;
  final VoidCallback? aoFechar;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          top: -120,
          right: -140,
          child: AnelEnso(tamanho: 260, espessura: 10, intensidade: 0.75),
        ),
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const AlcaFolha(),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: AppText.s(22,
                              peso: FontWeight.w700,
                              altura: 28,
                              espacamento: -0.2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitulo,
                          style: AppText.s(14,
                              altura: 20, cor: AppColors.textoSuave),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(12, -8),
                    child: BotaoIcone(
                      icone: Icons.close_rounded,
                      dica: 'Fechar',
                      cor: AppColors.textoSuave,
                      aoPressionar: aoFechar,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
      ],
    );
  }
}

/// Folha com os detalhes de um atendimento (usada em Início, Agenda e
/// Pacientes).
Future<void> abrirDetalhesAtendimento(
  BuildContext context,
  Atendimento a, {
  bool mostrarData = false,
}) {
  return abrirFolha<void>(
    context,
    builder: (context) => _DetalhesAtendimento(a: a, mostrarData: mostrarData),
  );
}

class _DetalhesAtendimento extends StatelessWidget {
  const _DetalhesAtendimento({required this.a, required this.mostrarData});
  final Atendimento a;
  final bool mostrarData;

  @override
  Widget build(BuildContext context) {
    final linhas = <Widget>[
      if (mostrarData)
        _linha(Icons.calendar_today_rounded, Text(_dataTexto(a.inicio), style: _estilo)),
      _linha(Icons.schedule_rounded, Text(a.horarioTexto, style: _estilo)),
      _linha(
        Icons.spa_rounded,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.temAdicional ? a.servicoTexto : a.servico.nome,
                style: _estilo),
            if (a.temAdicional) ...[
              const SizedBox(height: 4),
              Text(
                '+ Auriculoterapia · ${a.adicionalAuriculo} min',
                style: AppText.s(14,
                    peso: FontWeight.w600,
                    altura: 20,
                    cor: AppColors.primariaForte),
              ),
            ],
          ],
        ),
      ),
      _linha(Icons.meeting_room_rounded, Text(a.localTexto, style: _estilo)),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AlcaFolha(),
          const SizedBox(height: 24),
          Row(
            children: [
              AvatarIniciais(iniciais: iniciais(a.pacienteNome), tamanho: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.pacienteNome,
                        style: AppText.s(20, peso: FontWeight.w700, altura: 28)),
                    const SizedBox(height: 4),
                    ChipStatus(a.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < linhas.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            linhas[i],
          ],
          const SizedBox(height: 24),
          if (!a.status.inativo) ...[
            _BotaoClienteAusente(aoPressionar: () => _confirmarAusencia(context)),
            const SizedBox(height: 12),
          ],
          BotaoSecundario(
            rotulo: 'Fechar',
            aoPressionar: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Abre a confirmação. Se a terapeuta confirmar, o atendimento é gravado
  /// como "Faltou" e a folha de detalhes fecha. "Voltar" só fecha o pop-up.
  Future<void> _confirmarAusencia(BuildContext context) async {
    final mensageiro = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    final confirmado = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.veu,
      builder: (_) => _DialogoClienteAusente(atendimento: a),
    );
    if (confirmado != true) return;
    navegador.pop();
    mensageiro.showSnackBar(SnackBar(
      content: Text('${a.pacienteNome}: agendamento baixado como ausente.'),
    ));
  }

  static final _estilo = AppText.s(15, altura: 20);

  static String _dataTexto(DateTime d) {
    final ano = d.year != agora().year ? ' de ${d.year}' : '';
    return '${dataPorExtenso(d)}$ano';
  }

  Widget _linha(IconData icone, Widget conteudo) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 22, color: AppColors.primariaForte),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: conteudo,
          ),
        ),
      ],
    );
  }
}

/// Botão "Cliente ausente", no estilo do "Sair da conta" (contorno e texto
/// em vermelho), com um vermelho mais suave.
class _BotaoClienteAusente extends StatelessWidget {
  const _BotaoClienteAusente({required this.aoPressionar});
  final VoidCallback aoPressionar;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: aoPressionar,
      icon: const Icon(Icons.person_off_outlined, color: AppColors.ausente),
      label: Text(
        'Cliente ausente',
        style: AppText.s(15, peso: FontWeight.w600, cor: AppColors.ausente),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: AppColors.ausente.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// Pop-up de confirmação do "Cliente ausente".
class _DialogoClienteAusente extends StatefulWidget {
  const _DialogoClienteAusente({required this.atendimento});
  final Atendimento atendimento;

  @override
  State<_DialogoClienteAusente> createState() => _DialogoClienteAusenteState();
}

class _DialogoClienteAusenteState extends State<_DialogoClienteAusente> {
  bool _salvando = false;
  String? _erro;

  Future<void> _confirmar() async {
    if (_salvando) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await repositorio.alterarStatus(
          widget.atendimento.id, StatusAtendimento.faltou);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erro = 'Não foi possível dar baixa. $e';
      });
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.superficie,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.ausenteFundo,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_off_outlined,
                      color: AppColors.ausente, size: 28),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cliente ausente',
                textAlign: TextAlign.center,
                style: AppText.s(20, peso: FontWeight.w700, altura: 28),
              ),
              const SizedBox(height: 8),
              Text(
                'Cliente não compareceu a sessão? Se sim, confirme no botão '
                'abaixo para dar baixa no agendamento.',
                textAlign: TextAlign.center,
                style: AppText.s(15, altura: 22, cor: AppColors.textoSuave),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(
                  _erro!,
                  textAlign: TextAlign.center,
                  style: AppText.s(13, altura: 18, cor: AppColors.erroTexto),
                ),
              ],
              const SizedBox(height: 24),
              BotaoPrimario(
                rotulo: _salvando ? 'Dando baixa…' : 'Sim, cliente ausente',
                carregando: _salvando,
                fundo: AppColors.ausente,
                cor: Colors.white,
                sombra: false,
                aoPressionar: _confirmar,
              ),
              const SizedBox(height: 12),
              BotaoSecundario(
                rotulo: 'Voltar',
                aoPressionar:
                    _salvando ? null : () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
