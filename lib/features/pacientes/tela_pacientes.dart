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
import 'folha_paciente.dart';
import 'tela_perfil_paciente.dart';

enum _Ordem { recentes, az }
int _numeroLocal(String id) =>
    int.tryParse(id.replaceFirst('local-', '')) ?? 0;

/// Aba "Pacientes": busca, ordenação e lista de pacientes.
class TelaPacientes extends StatefulWidget {
  const TelaPacientes({
    super.key,
    required this.terapeuta,
    required this.aoSair,
  });

  final Terapeuta terapeuta;
  final VoidCallback aoSair;

  @override
  State<TelaPacientes> createState() => _TelaPacientesState();
}

class _TelaPacientesState extends State<TelaPacientes> {
  List<PacienteResumo>? _pacientes;
  final _busca = TextEditingController();
  final _focoBusca = FocusNode();
  _Ordem _ordem = _Ordem.recentes;
  String? _destaque;
  Aviso? _aviso;
  Timer? _timerAviso;

  @override
  void initState() {
    super.initState();
    repositorio.addListener(_carregar);
    _focoBusca.addListener(() => setState(() {}));
    _carregar();
  }

  @override
  void dispose() {
    repositorio.removeListener(_carregar);
    _timerAviso?.cancel();
    _busca.dispose();
    _focoBusca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final lista = await repositorio.buscarPacientes(agora());
    if (mounted) setState(() => _pacientes = lista);
  }

  void _mostrarAviso(Aviso aviso) {
    _timerAviso?.cancel();
    setState(() => _aviso = aviso);
    _timerAviso = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _aviso = null;
          _destaque = null;
        });
      }
    });
  }

  void _abrirPerfil(String id) {
    _timerAviso?.cancel();
    setState(() {
      _aviso = null;
      _destaque = null;
    });
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TelaPerfilPaciente(pacienteId: id),
    ));
  }

  Future<void> _novoPaciente() async {
    final p = await abrirFormularioPaciente(context);
    if (p == null || !mounted) return;
    _busca.clear();
    setState(() {
      _ordem = _Ordem.recentes;
      _destaque = p.id;
    });
    _mostrarAviso(Aviso(
      texto: 'Paciente cadastrado',
      acao: 'Ver perfil',
      aoAcionar: () => _abrirPerfil(p.id),
    ));
  }

  List<PacienteResumo> _filtrados() {
    final todos = _pacientes ?? const <PacienteResumo>[];
    final q = normalizar(_busca.text.trim());
    final dq = apenasDigitos(_busca.text);
    final lista = todos.where((r) {
      if (q.isEmpty) return true;
      if (normalizar(r.paciente.nome).contains(q)) return true;
      return dq.length >= 3 && apenasDigitos(r.paciente.telefone).contains(dq);
    }).toList();

    if (_ordem == _Ordem.az) {
      lista.sort((a, b) =>
          normalizar(a.paciente.nome).compareTo(normalizar(b.paciente.nome)));
    } else {
      // Recentes: cadastrados agora, depois quem tem atendimento hoje (por
      // horário) e, por fim, pela última sessão.
      int grupo(PacienteResumo r) =>
          r.paciente.novo ? 0 : (r.atendimentoHoje != null ? 1 : 2);
      lista.sort((a, b) {
        final g = grupo(a).compareTo(grupo(b));
        if (g != 0) return g;
        if (a.paciente.novo) {
          return _numeroLocal(b.paciente.id)
              .compareTo(_numeroLocal(a.paciente.id));
        }
        if (a.atendimentoHoje != null) {
          return a.atendimentoHoje!.inicio.compareTo(b.atendimentoHoje!.inicio);
        }
        final ua = a.ultimaSessao, ub = b.ultimaSessao;
        if (ua == null && ub == null) return 0;
        if (ua == null) return 1;
        if (ub == null) return -1;
        return ub.compareTo(ua);
      });
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final todos = _pacientes;
    final carregando = todos == null;
    final temPacientes = todos != null && todos.isNotEmpty;
    final lista = _filtrados();
    final total = todos?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.fundo,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: temPacientes ? 104 : 32),
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
                            '$total ${total == 1 ? 'PACIENTE' : 'PACIENTES'}',
                        titulo: 'Pacientes',
                        terapeuta: widget.terapeuta,
                        aoSair: widget.aoSair,
                      ),
                      if (carregando)
                        const _EsqueletoLista()
                      else if (!temPacientes)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: EstadoVazio(
                            icone: Icons.group_outlined,
                            titulo: 'Nenhum paciente ainda',
                            texto:
                                'Cadastre seu primeiro paciente para acompanhar sessões e horários.',
                            acao: BotaoPrimario(
                              rotulo: 'Novo paciente',
                              icone: Icons.person_add_alt_1_outlined,
                              aoPressionar: _novoPaciente,
                            ),
                          ),
                        )
                      else ...[
                        _campoBusca(),
                        _chipsOrdem(),
                        if (lista.isEmpty)
                          _semResultados()
                        else
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                            child: _listaPacientes(lista),
                          ),
                      ],
                    ],
                  ),
                ],
              )),
            ),
          ),
          if (temPacientes)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              right: 16,
              bottom: _aviso == null ? 16 : 80,
              child: BotaoFlutuante(
                rotulo: 'Novo paciente',
                icone: Icons.person_add_alt_1_outlined,
                aoPressionar: _novoPaciente,
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

  Widget _campoBusca() {
    final foco = _focoBusca.hasFocus;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
        padding: const EdgeInsets.only(left: 16, right: 4),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: foco ? AppColors.primariaForte : AppColors.borda,
            width: foco ? 2 : 1,
          ),
          boxShadow: [
            if (foco)
              BoxShadow(
                color: AppColors.primaria.withValues(alpha: 0.26),
                spreadRadius: 4,
              )
            else
              BoxShadow(
                color: AppColors.texto.withValues(alpha: 0.04),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                size: 24, color: AppColors.textoSuave),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _busca,
                focusNode: _focoBusca,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                style: AppText.s(16, peso: FontWeight.w500, altura: 24),
                decoration: InputDecoration.collapsed(
                  hintText: 'Buscar por nome ou telefone',
                  hintStyle: AppText.s(16,
                      peso: FontWeight.w500,
                      altura: 24,
                      cor: AppColors.placeholder),
                ),
              ),
            ),
            if (_busca.text.isNotEmpty)
              BotaoIcone(
                icone: Icons.close_rounded,
                dica: 'Limpar busca',
                cor: AppColors.textoSuave,
                tamanhoIcone: 22,
                aoPressionar: () => setState(_busca.clear),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _chipsOrdem() {
    Widget chip(_Ordem o, String rotulo) {
      final sel = o == _ordem;
      return Semantics(
        button: true,
        selected: sel,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _ordem = o),
          child: SizedBox(
            height: 48,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 32,
                padding: EdgeInsets.only(left: sel ? 8 : 12, right: 12),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primariaSuave : AppColors.superficie,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: sel ? AppColors.primariaSuave : AppColors.contorno),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sel) ...[
                      const Icon(Icons.check_rounded,
                          size: 18, color: AppColors.primariaEscura),
                      const SizedBox(width: 4),
                    ],
                    Text(rotulo,
                        style: AppText.s(13,
                            altura: 16,
                            peso: sel ? FontWeight.w700 : FontWeight.w500,
                            cor: sel
                                ? AppColors.primariaEscura
                                : AppColors.texto)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        children: [
          chip(_Ordem.recentes, 'Recentes'),
          const SizedBox(width: 8),
          chip(_Ordem.az, 'A–Z'),
        ],
      ),
    );
  }

  Widget _semResultados() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: CardBranco(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primariaSuave,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 32, color: AppColors.primariaForte),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum resultado para “${_busca.text.trim()}”',
              textAlign: TextAlign.center,
              style: AppText.s(18, peso: FontWeight.w700, altura: 24),
            ),
            const SizedBox(height: 8),
            Text(
              'Confira a grafia ou busque pelo telefone.',
              textAlign: TextAlign.center,
              style: AppText.s(14, altura: 20, cor: AppColors.textoSuave),
            ),
            const SizedBox(height: 16),
            BotaoTexto(
              rotulo: 'Limpar busca',
              aoPressionar: () => setState(_busca.clear),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listaPacientes(List<PacienteResumo> lista) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borda),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < lista.length; i++) _linha(lista[i], i > 0),
          ],
        ),
      ),
    );
  }

  Widget _linha(PacienteResumo r, bool divisor) {
    final p = r.paciente;
    final ultima = r.ultimaSessao;
    final hoje = r.atendimentoHoje;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: _destaque == p.id ? AppColors.hover : Colors.transparent,
        border: divisor
            ? const Border(top: BorderSide(color: AppColors.divisor))
            : null,
      ),
      child: InkWell(
        onTap: () => _abrirPerfil(p.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AvatarIniciais(iniciais: iniciais(p.nome)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.s(15, peso: FontWeight.w600, altura: 20)),
                    const SizedBox(height: 2),
                    Text(p.telefone,
                        style: AppText.s(13,
                            altura: 18, cor: AppColors.textoSecundario)),
                    const SizedBox(height: 2),
                    Text(
                      ultima == null
                          ? 'Nenhuma sessão ainda'
                          : 'Última sessão ${dataCurta(ultima)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.s(12, altura: 16, cor: AppColors.textoSuave),
                    ),
                  ],
                ),
              ),
              if (hoje != null) ...[
                const SizedBox(width: 16),
                Etiqueta(
                  texto: 'Hoje · ${hora(hoje.inicio)}',
                  icone: Icons.schedule_rounded,
                  fundo: AppColors.texto,
                  cor: Colors.white,
                  negrito: true,
                ),
              ] else if (p.novo) ...[
                const SizedBox(width: 16),
                const Etiqueta(
                  texto: 'Novo',
                  fundo: AppColors.primariaSuave,
                  cor: AppColors.primariaEscura,
                  negrito: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EsqueletoLista extends StatelessWidget {
  const _EsqueletoLista();

  @override
  Widget build(BuildContext context) {
    const larguras = [0.62, 0.48, 0.56, 0.70, 0.44];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Esqueleto(altura: 56, raio: 28),
          const SizedBox(height: 16),
          const Row(
            children: [
              Esqueleto(largura: 104, altura: 32),
              SizedBox(width: 8),
              Esqueleto(largura: 56, altura: 32),
            ],
          ),
          const SizedBox(height: 24),
          CardBranco(
            raio: 16,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < larguras.length; i++)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: i > 0
                          ? const Border(
                              top: BorderSide(color: AppColors.divisor))
                          : null,
                    ),
                    child: Row(
                      children: [
                        const Esqueleto(largura: 48, altura: 48, circular: true),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FractionallySizedBox(
                                widthFactor: larguras[i],
                                child: const Esqueleto(altura: 14, raio: 6),
                              ),
                              const SizedBox(height: 8),
                              const FractionallySizedBox(
                                widthFactor: 0.4,
                                child: Esqueleto(altura: 12, raio: 6),
                              ),
                              const SizedBox(height: 8),
                              const FractionallySizedBox(
                                widthFactor: 0.52,
                                child: Esqueleto(altura: 10, raio: 5),
                              ),
                            ],
                          ),
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
}
