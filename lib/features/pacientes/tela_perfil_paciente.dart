import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../inicio/tela_inicio.dart'
    show HorarioGrande, LinhaServico, PilulaContagemRegressiva;
import 'componentes_pacientes.dart';
import 'folha_paciente.dart';
import 'tela_historico_paciente.dart';

/// Perfil do paciente: contato, métricas, próximo atendimento e as três
/// sessões mais recentes.
class TelaPerfilPaciente extends StatefulWidget {
  const TelaPerfilPaciente({super.key, required this.pacienteId});
  final String pacienteId;

  @override
  State<TelaPerfilPaciente> createState() => _TelaPerfilPacienteState();
}

class _TelaPerfilPacienteState extends State<TelaPerfilPaciente> {
  Paciente? _paciente;
  List<Atendimento>? _atendimentos;
  Aviso? _aviso;
  Timer? _timerAviso;

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
    final p = await repositorio.buscarPaciente(widget.pacienteId);
    final a = await repositorio.buscarAtendimentosDoPaciente(widget.pacienteId);
    if (!mounted) return;
    setState(() {
      _paciente = p;
      _atendimentos = a;
    });
  }

  Future<void> _editar() async {
    final p = _paciente;
    if (p == null) return;
    final salvo = await abrirFormularioPaciente(context, paciente: p);
    if (salvo == null || !mounted) return;
    _timerAviso?.cancel();
    setState(() => _aviso = const Aviso(texto: 'Dados atualizados'));
    _timerAviso = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _aviso = null);
    });
  }

  Future<void> _abrirLink(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _aviso = const Aviso(
            texto: 'Não foi possível abrir este contato no aparelho.',
            icone: Icons.info_rounded,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _paciente;
    final atendimentos = _atendimentos;
    return Scaffold(
      backgroundColor: AppColors.fundo,
      body: Stack(
        children: [
          SafeArea(
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Row(
                          children: [
                            const BotaoVoltar(dica: 'Voltar para pacientes'),
                            const Spacer(),
                            if (p != null)
                              BotaoTexto(
                                rotulo: 'Editar',
                                icone: Icons.edit_outlined,
                                aoPressionar: _editar,
                              ),
                          ],
                        ),
                      ),
                      if (p == null || atendimentos == null)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Esqueleto(
                                      largura: 72, altura: 72, circular: true),
                                  SizedBox(width: 16),
                                  Esqueleto(largura: 180, altura: 24),
                                ],
                              ),
                              SizedBox(height: 24),
                              Esqueleto(altura: 48, raio: 16),
                              SizedBox(height: 16),
                              Esqueleto(altura: 88, raio: 24),
                            ],
                          ),
                        )
                      else
                        _conteudo(p, atendimentos),
                    ],
                  ),
                ],
              )),
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
      ),
    );
  }

  Widget _conteudo(Paciente p, List<Atendimento> atendimentos) {
    final agoraApp = agora();
    final abertos = atendimentos
        .where((a) => a.status.emAberto && a.fim.isAfter(agoraApp))
        .toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
    final proximo = abertos.isEmpty ? null : abertos.first;
    final historico = atendimentos
        .where((a) => !a.status.emAberto && !a.inicio.isAfter(agoraApp))
        .toList(); // já vem do mais recente para o mais antigo
    final concluidas =
        historico.where((a) => a.status == StatusAtendimento.concluido).toList();
    final ultima = concluidas.isEmpty ? null : concluidas.first.inicio;
    final digitos = apenasDigitos(p.telefone);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.texto.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AvatarIniciais(iniciais: iniciais(p.nome), tamanho: 66),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nome,
                        style: AppText.s(24,
                            peso: FontWeight.w700,
                            altura: 32,
                            espacamento: -0.3)),
                    const SizedBox(height: 4),
                    Text(p.telefone,
                        style: AppText.s(14,
                            altura: 20, cor: AppColors.textoSecundario)),
                    if (p.email != null && p.email!.isNotEmpty)
                      Text(p.email!,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.s(14,
                              altura: 20, cor: AppColors.textoSuave)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _BotaoContato(
                  rotulo: 'Ligar',
                  icone: Icons.call_rounded,
                  aoPressionar: () => _abrirLink(Uri.parse('tel:+55$digitos')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BotaoContato(
                  rotulo: 'WhatsApp',
                  icone: Icons.chat_rounded,
                  aoPressionar: () =>
                      _abrirLink(Uri.parse('https://wa.me/55$digitos')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CardMetrica(
                  valor: '${concluidas.length}',
                  rotulo: concluidas.length == 1
                      ? 'Sessão realizada'
                      : 'Sessões realizadas',
                  icone: Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CardMetrica(
                  valor: ultima == null
                      ? '—'
                      : '${doisDigitos(ultima.day)}/${doisDigitos(ultima.month)}',
                  rotulo: 'Última sessão',
                  icone: Icons.history_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const TituloSecao('Próximo atendimento'),
          if (proximo == null)
            const CaixaTracejada(
              icone: Icons.event_available_outlined,
              texto: 'Nenhum atendimento agendado',
            )
          else
            _CardProximoPaciente(atendimento: proximo, agora: agoraApp),
          const SizedBox(height: 32),
          const TituloSecao('Histórico de sessões'),
          if (historico.isEmpty)
            const CaixaTracejada(
              icone: Icons.history_rounded,
              texto: 'Nenhuma sessão registrada ainda',
            )
          else ...[
            const SizedBox(height: 8),
            ListaHistorico(
              sessoes: historico.take(3).toList(),
              aoAbrir: (a) =>
                  abrirDetalhesAtendimento(context, a, mostrarData: true),
            ),
          ],
          if (historico.length > 3)
            Center(
              child: BotaoTexto(
                rotulo: 'Ver todas as ${historico.length} sessões',
                icone: Icons.arrow_forward_rounded,
                iconeDepois: true,
                aoPressionar: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TelaHistoricoPaciente(
                      paciente: p,
                      historico: historico,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BotaoContato extends StatelessWidget {
  const _BotaoContato({
    required this.rotulo,
    required this.icone,
    required this.aoPressionar,
  });

  final String rotulo;
  final IconData icone;
  final VoidCallback aoPressionar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primariaSuave,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: aoPressionar,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 20, color: AppColors.primariaEscura),
              const SizedBox(width: 8),
              Text(rotulo,
                  style: AppText.s(14,
                      peso: FontWeight.w700,
                      altura: 20,
                      cor: AppColors.primariaEscura)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardProximoPaciente extends StatelessWidget {
  const _CardProximoPaciente({required this.atendimento, required this.agora});
  final Atendimento atendimento;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final a = atendimento;
    final ehHoje = mesmoDia(a.inicio, agora);
    final faltam = a.inicio.difference(agora).inMinutes;
    final dia =
        '${diaSemanaMinusculo(a.inicio)}, ${diaEMes(a.inicio)}'.toUpperCase();
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
              Expanded(
                child: Text(ehHoje ? 'HOJE · $dia' : dia,
                    style: AppText.sobretitulo()),
              ),
              ChipStatus(a.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: HorarioGrande(inicio: a.inicio, fim: a.fim)),
              if (ehHoje && faltam > 0)
                PilulaContagemRegressiva(contagemRegressiva(faltam)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divisor),
          const SizedBox(height: 16),
          LinhaServico(icone: Icons.spa_outlined, texto: a.servicoCompleto),
          const SizedBox(height: 8),
          LinhaServico(icone: Icons.meeting_room_outlined, texto: a.localTexto),
          const SizedBox(height: 16),
          BotaoSecundario(
            rotulo: 'Ver detalhes',
            aoPressionar: () =>
                abrirDetalhesAtendimento(context, a, mostrarData: true),
          ),
        ],
      ),
    );
  }
}
