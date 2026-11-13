import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../core/app_text.dart';
import '../../core/formatadores.dart';
import '../../data/services/admin_api_service.dart';
import '../../widgets/campos.dart';
import '../../widgets/componentes.dart';
import '../../widgets/folhas.dart';
import '../../widgets/seletores.dart';
import 'aba_pacientes_admin.dart';
import 'tela_admin.dart';

/// Resultado de um agendamento criado.
class AgendamentoCriado {
  const AgendamentoCriado({required this.paciente, required this.dia});
  final String paciente;
  final DateTime dia;
}

/// Abre o "Novo agendamento", na mesma ordem do agendamento do site da
/// Rokuzen: unidade → serviço → tempo (e combo) → data → terapeuta e
/// horário → paciente → confirmar.
Future<AgendamentoCriado?> abrirNovoAgendamento(
  BuildContext context, {
  required List<UnidadeAdmin> unidades,
  String? unidadeInicial,
  required DateTime diaInicial,
}) {
  return abrirFolha<AgendamentoCriado>(
    context,
    builder: (_) => _FolhaNovoAgendamento(
      unidades: unidades,
      unidadeInicial: unidadeInicial,
      diaInicial: diaInicial,
    ),
  );
}

class _FolhaNovoAgendamento extends StatefulWidget {
  const _FolhaNovoAgendamento({
    required this.unidades,
    required this.unidadeInicial,
    required this.diaInicial,
  });

  final List<UnidadeAdmin> unidades;
  final String? unidadeInicial;
  final DateTime diaInicial;

  @override
  State<_FolhaNovoAgendamento> createState() => _FolhaNovoAgendamentoState();
}

class _FolhaNovoAgendamentoState extends State<_FolhaNovoAgendamento> {
  final _api = AdminApiService();

  late List<UnidadeAdmin> _unidades = widget.unidades;
  UnidadeAdmin? _unidade;

  List<ServicoAdmin>? _servicos;
  ServicoAdmin? _servico;
  OpcaoServico? _opcao;
  bool _comCombo = false;

  DateTime? _data;

  List<AgendaTerapeuta>? _agenda;
  bool _carregandoAgenda = false;
  AgendaTerapeuta? _terapeuta;
  int? _horario;

  final _buscaTerapeuta = TextEditingController();
  final _busca = TextEditingController();
  Timer? _atrasoBusca;
  List<PacienteAdmin>? _resultados;
  bool _buscando = false;
  PacienteAdmin? _paciente;

  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _data = soData(widget.diaInicial);
    if (widget.unidadeInicial != null) {
      final u = _unidades.where((u) => u.id == widget.unidadeInicial);
      if (u.isNotEmpty) _unidade = u.first;
    }
    if (_unidades.isEmpty) _carregarUnidades();
    _carregarServicos();
  }

  @override
  void dispose() {
    _busca.dispose();
    _buscaTerapeuta.dispose();
    _atrasoBusca?.cancel();
    super.dispose();
  }

  Future<void> _carregarUnidades() async {
    try {
      final lista = await _api.unidades();
      if (mounted) setState(() => _unidades = lista);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível carregar as unidades. $e');
      }
    }
  }

  Future<void> _carregarServicos() async {
    try {
      final lista = await _api.servicos();
      if (mounted) setState(() => _servicos = lista);
    } catch (e) {
      if (mounted) {
        setState(() {
          _servicos = const [];
          _erro = 'Não foi possível carregar os serviços. $e';
        });
      }
    }
  }

  // ------------------------------------------------------------ etapas

  int? get _duracaoTotal {
    final o = _opcao;
    if (o == null) return null;
    final combo = _comCombo ? (_servico?.combo?.duracao ?? 0) : 0;
    return o.duracao + combo;
  }

  double? get _precoTotal {
    final preco = _opcao?.preco;
    if (preco == null) return null;
    final combo = _comCombo ? (_servico?.combo?.preco ?? 0) : 0;
    return preco + combo;
  }

  void _limparAgenda() {
    _agenda = null;
    _terapeuta = null;
    _horario = null;
    _carregandoAgenda = false;
  }

  void _escolherUnidade(UnidadeAdmin u) {
    setState(() {
      _unidade = u;
      _limparAgenda();
    });
    _carregarAgenda();
  }

  void _escolherServico(ServicoAdmin s) {
    setState(() {
      _servico = s;
      _opcao = s.opcoes.length == 1 ? s.opcoes.first : null;
      _comCombo = false;
      _limparAgenda();
    });
    _carregarAgenda();
  }

  void _escolherOpcao(OpcaoServico o) {
    setState(() {
      _opcao = o;
      _limparAgenda();
    });
    _carregarAgenda();
  }

  void _escolherCombo(bool sim) {
    setState(() {
      _comCombo = sim;
      _limparAgenda();
    });
    _carregarAgenda();
  }

  Future<void> _escolherData() async {
    final d = await escolherData(
      context,
      rotulo: 'Data da sessão',
      inicial: _data,
      hoje: agora(),
      minima: soData(agora()),
      mostrarAno: true,
    );
    if (d == null || !mounted) return;
    setState(() {
      _data = soData(d);
      _limparAgenda();
    });
    _carregarAgenda();
  }

  Future<void> _carregarAgenda() async {
    final u = _unidade, d = _data, total = _duracaoTotal;
    if (u == null || d == null || total == null) return;
    setState(() {
      _carregandoAgenda = true;
      _erro = null;
    });
    try {
      final lista = await _api.agendaTerapeutas(
        unidadeId: u.id,
        dia: d,
        duracao: total,
        agora: agora(),
      );
      if (!mounted ||
          _unidade != u ||
          _data != d ||
          _duracaoTotal != total) {
        return;
      }
      setState(() {
        _agenda = lista;
        _carregandoAgenda = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _agenda = const [];
        _carregandoAgenda = false;
        _erro = 'Não foi possível carregar os horários. $e';
      });
    }
  }

  void _escolherHorario(AgendaTerapeuta t, int minutos) {
    setState(() {
      _terapeuta = t;
      _horario = minutos;
    });
  }

  // --------------------------------------------------------- paciente

  void _aoDigitarBusca(String texto) {
    _atrasoBusca?.cancel();
    if (texto.trim().length < 2) {
      setState(() {
        _resultados = null;
        _buscando = false;
      });
      return;
    }
    setState(() => _buscando = true);
    _atrasoBusca = Timer(const Duration(milliseconds: 350), () async {
      try {
        final (_, lista) = await _api.pacientes(busca: texto);
        if (!mounted || _busca.text != texto) return;
        setState(() {
          _resultados = lista.take(8).toList();
          _buscando = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _resultados = const [];
          _buscando = false;
          _erro = 'Não foi possível buscar pacientes. $e';
        });
      }
    });
  }

  Future<void> _novoPaciente() async {
    final p = await abrirFormularioPacienteAdmin(context);
    if (p != null && mounted) setState(() => _paciente = p);
  }

  // ---------------------------------------------------------- confirmar

  bool get _completo =>
      _unidade != null &&
      _servico != null &&
      _opcao != null &&
      _data != null &&
      _terapeuta != null &&
      _horario != null &&
      _paciente != null;

  Future<void> _confirmar() async {
    if (!_completo || _salvando) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await _api.agendar(
        unidadeId: _unidade!.id,
        servicoId: _servico!.id,
        duracao: _opcao!.duracao,
        comCombo: _comCombo,
        terapeutaId: _terapeuta!.id,
        pacienteId: _paciente!.id,
        inicio: _data!.add(Duration(minutes: _horario!)),
        agora: agora(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erro = 'Não foi possível agendar. $e';
        _terapeuta = null;
        _horario = null;
      });
      // O horário pode ter sido ocupado: atualiza a lista.
      _carregarAgenda();
      return;
    }
    if (mounted) {
      Navigator.of(context).pop(
        AgendamentoCriado(paciente: _paciente!.nome, dia: _data!),
      );
    }
  }

  // ------------------------------------------------------------- tela

  @override
  Widget build(BuildContext context) {
    final etapas = <Widget>[
      _Etapa(
        numero: 1,
        titulo: 'Selecione a unidade',
        child: _unidades.isEmpty
            ? const _Carregando()
            : Wrap(spacing: 8, runSpacing: 8, children: [
                for (final u in _unidades)
                  OpcaoAdmin(
                    rotulo: u.nome,
                    selecionada: _unidade?.id == u.id,
                    aoTocar: () => _escolherUnidade(u),
                  ),
              ]),
      ),
      if (_unidade != null)
        _Etapa(
          numero: 2,
          titulo: 'Selecione o serviço',
          child: _servicos == null
              ? const _Carregando()
              : _GradeServicos(
                  servicos: _servicos!,
                  selecionado: _servico,
                  aoEscolher: _escolherServico,
                ),
        ),
      if (_servico != null)
        _Etapa(
          numero: 3,
          titulo: 'Selecione o tempo',
          child: _tempo(_servico!),
        ),
      if (_opcao != null)
        _Etapa(
          numero: 4,
          titulo: 'Escolha a data',
          child: CampoSeletor(
            icone: Icons.calendar_today_outlined,
            valor: capitalizar(dataPorExtenso(_data!)),
            iconeFinal: Icons.expand_more_rounded,
            aoTocar: _escolherData,
          ),
        ),
      if (_opcao != null && _data != null)
        _Etapa(
          numero: 5,
          titulo: 'Selecione o terapeuta e o horário',
          child: _terapeutas(),
        ),
      if (_horario != null)
        _Etapa(
          numero: 6,
          titulo: 'Paciente',
          child: _escolhaPaciente(),
        ),
    ];

    return PopScope(
      canPop: !_salvando,
      child: FolhaFormulario(
        titulo: 'Novo agendamento',
        subtitulo: 'Mesmo passo a passo do agendamento do site da Rokuzen.',
        aoFechar: _salvando ? null : () => Navigator.of(context).pop(),
        children: [
          ...etapas,
          if (_erro != null) ...[
            Semantics(liveRegion: true, child: ErroCampo(_erro!)),
            const SizedBox(height: 16),
          ],
          if (_completo) ...[
            _resumo(),
            const SizedBox(height: 16),
          ],
          BotaoPrimario(
            rotulo: _salvando ? 'Agendando…' : 'Confirmar agendamento',
            icone: Icons.check_rounded,
            carregando: _salvando,
            aoPressionar: _completo ? _confirmar : null,
          ),
        ],
      ),
    );
  }

  /// Etapa 3: durações do serviço e, na Reflexologia, o combo.
  Widget _tempo(ServicoAdmin s) {
    final combo = s.combo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.nome.toUpperCase(),
            style: AppText.s(14,
                peso: FontWeight.w700, altura: 20, espacamento: 0.6)),
        const SizedBox(height: 8),
        for (final o in s.opcoes)
          _LinhaRadio(
            rotulo: '${o.duracao} minutos'
                '${o.preco == null ? '' : ' · ${_preco(o.preco!)}'}',
            selecionada: _opcao?.duracao == o.duracao,
            aoTocar: () => _escolherOpcao(o),
          ),
        if (combo != null && _opcao != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            decoration: BoxDecoration(
              color: AppColors.primariaSuave,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primariaForte),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Promoção: aproveite e acrescente uma sessão de Aurículo!',
                  style: AppText.s(14,
                      peso: FontWeight.w700,
                      altura: 20,
                      cor: AppColors.primariaEscura),
                ),
                const SizedBox(height: 4),
                Text(
                  (s.nomeCombo ?? 'Auriculoterapia - Combo').toUpperCase(),
                  style: AppText.s(12,
                      peso: FontWeight.w700,
                      altura: 16,
                      espacamento: 0.6,
                      cor: AppColors.textoSuave),
                ),
                const SizedBox(height: 4),
                _LinhaRadio(
                  rotulo: 'Não tenho interesse',
                  selecionada: !_comCombo,
                  aoTocar: () => _escolherCombo(false),
                ),
                _LinhaRadio(
                  rotulo: '${combo.duracao} minutos'
                      '${combo.preco == null ? '' : ' · ${_preco(combo.preco!)}'}',
                  selecionada: _comCombo,
                  aoTocar: () => _escolherCombo(true),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Etapa 5: cada terapeuta com o período e os horários do dia.
  Widget _terapeutas() {
    final todos = _agenda;
    if (_carregandoAgenda || todos == null) return const _Carregando();
    final algumLivre = todos.any((t) => t.temHorarioLivre);
    final termo = normalizar(_buscaTerapeuta.text.trim());
    final lista = termo.isEmpty
        ? todos
        : todos.where((t) => normalizar(t.nome).contains(termo)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (todos.length > 3) ...[
          CampoTexto(
            rotulo: 'Buscar terapeuta',
            controller: _buscaTerapeuta,
            icone: Icons.search_rounded,
            dica: 'Nome do terapeuta',
            aoMudar: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (lista.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _Mensagem('Nenhum terapeuta com esse nome nesta unidade.'),
            ),
        ],
        if (!algumLivre)
          Container(
            padding: const EdgeInsets.all(16),
            margin: EdgeInsets.only(bottom: lista.isEmpty ? 0 : 12),
            decoration: BoxDecoration(
              color: AppColors.ausenteFundo,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_busy_rounded,
                    color: AppColors.ausente, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nenhum terapeuta disponível para esse serviço neste '
                    'horário',
                    style: AppText.s(14,
                        peso: FontWeight.w600,
                        altura: 20,
                        cor: AppColors.erroTexto),
                  ),
                ),
              ],
            ),
          ),
        for (final t in lista) ...[
          _CartaoTerapeuta(
            terapeuta: t,
            horarioSelecionado: _terapeuta?.id == t.id ? _horario : null,
            aoEscolher: (m) => _escolherHorario(t, m),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _escolhaPaciente() {
    final p = _paciente;
    if (p != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.primariaSuave,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primariaForte, width: 1.5),
        ),
        child: Row(
          children: [
            AvatarIniciais(iniciais: iniciais(p.nome), tamanho: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.nome,
                      style: AppText.s(15, peso: FontWeight.w700, altura: 20)),
                  if (p.telefone != null)
                    Text(p.telefone!,
                        style: AppText.s(13,
                            altura: 18, cor: AppColors.textoSuave)),
                ],
              ),
            ),
            BotaoTexto(
              rotulo: 'Trocar',
              aoPressionar: () => setState(() => _paciente = null),
            ),
          ],
        ),
      );
    }
    final resultados = _resultados;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampoTexto(
          rotulo: 'Buscar paciente',
          controller: _busca,
          icone: Icons.search_rounded,
          dica: 'Nome ou telefone (mín. 2 letras)',
          aoMudar: _aoDigitarBusca,
        ),
        const SizedBox(height: 8),
        if (_buscando)
          const _Carregando()
        else if (resultados != null && resultados.isEmpty)
          const _Mensagem('Nenhum paciente encontrado.')
        else if (resultados != null)
          for (final r in resultados)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: AvatarIniciais(iniciais: iniciais(r.nome), tamanho: 36),
              title: Text(r.nome,
                  style: AppText.s(15, peso: FontWeight.w600, altura: 20)),
              subtitle: r.telefone == null
                  ? null
                  : Text(r.telefone!,
                      style: AppText.s(13, cor: AppColors.textoSuave)),
              onTap: () => setState(() => _paciente = r),
            ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: BotaoTexto(
            rotulo: 'Cadastrar novo paciente',
            icone: Icons.person_add_alt_1_outlined,
            aoPressionar: _novoPaciente,
          ),
        ),
      ],
    );
  }

  Widget _resumo() {
    final inicio = _data!.add(Duration(minutes: _horario!));
    final fim = inicio.add(Duration(minutes: _duracaoTotal!));
    final preco = _precoTotal;
    final combo = _comCombo && _servico!.combo != null
        ? ' + Auriculoterapia ${_servico!.combo!.duracao} min'
        : '';
    return CardResumo(
      children: [
        Text('RESUMO', style: AppText.sobretitulo()),
        Text(
          '${capitalizar(dataPorExtenso(inicio))} · ${hora(inicio)}–${hora(fim)}',
          style: AppText.s(17, peso: FontWeight.w700, altura: 24),
        ),
        LinhaInfo(
          icone: Icons.spa_outlined,
          texto: '${_servico!.nome} · ${_opcao!.duracao} min$combo'
              '${preco == null ? '' : ' · ${_preco(preco)}'}',
        ),
        LinhaInfo(icone: Icons.place_outlined, texto: _unidade!.nome),
        LinhaInfo(
            icone: Icons.self_improvement_rounded, texto: _terapeuta!.nome),
        LinhaInfo(
            icone: Icons.person_outline_rounded,
            texto: _paciente!.nome,
            destaque: true),
      ],
    );
  }
}

String _preco(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

/// "10h", "14h30"
String _horaCurta(int minutos) {
  final h = minutos ~/ 60;
  final m = minutos % 60;
  return m == 0 ? '${h}h' : '${h}h${doisDigitos(m)}';
}

/// Uma etapa numerada do agendamento.
class _Etapa extends StatelessWidget {
  const _Etapa({
    required this.numero,
    required this.titulo,
    required this.child,
  });

  final int numero;
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primariaForte,
                  shape: BoxShape.circle,
                ),
                child: Text('$numero',
                    style: AppText.s(13,
                        peso: FontWeight.w700, cor: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(titulo, style: AppText.tituloSecao())),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Os 4 serviços em cartões com ícone (como no site).
class _GradeServicos extends StatelessWidget {
  const _GradeServicos({
    required this.servicos,
    required this.selecionado,
    required this.aoEscolher,
  });

  final List<ServicoAdmin> servicos;
  final ServicoAdmin? selecionado;
  final ValueChanged<ServicoAdmin> aoEscolher;

  static IconData _icone(String id) => switch (id) {
        'quick' => Icons.chair_alt_outlined,
        'maca' => Icons.airline_seat_flat_outlined,
        'reflexologia' => Icons.do_not_step_outlined,
        'auriculoterapia' => Icons.hearing_outlined,
        _ => Icons.spa_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final colunas = c.maxWidth >= 440 ? 4 : 2;
        final largura = (c.maxWidth - 8 * (colunas - 1)) / colunas;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in servicos)
              SizedBox(
                width: largura,
                child: _CartaoServico(
                  nome: s.nome,
                  icone: _icone(s.id),
                  selecionado: selecionado?.id == s.id,
                  aoTocar: () => aoEscolher(s),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CartaoServico extends StatelessWidget {
  const _CartaoServico({
    required this.nome,
    required this.icone,
    required this.selecionado,
    required this.aoTocar,
  });

  final String nome;
  final IconData icone;
  final bool selecionado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selecionado,
      child: Material(
        color: selecionado ? AppColors.primariaSuave : AppColors.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selecionado ? AppColors.primariaForte : AppColors.borda,
            width: selecionado ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Column(
              children: [
                Icon(icone,
                    size: 30,
                    color: selecionado
                        ? AppColors.primariaForte
                        : AppColors.textoSecundario),
                const SizedBox(height: 8),
                Text(
                  nome,
                  textAlign: TextAlign.center,
                  style: AppText.s(13,
                      peso: selecionado ? FontWeight.w700 : FontWeight.w600,
                      altura: 18,
                      cor: selecionado
                          ? AppColors.primariaEscura
                          : AppColors.texto),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha com botão de rádio ("30 minutos · R$ 120,00").
class _LinhaRadio extends StatelessWidget {
  const _LinhaRadio({
    required this.rotulo,
    required this.selecionada,
    required this.aoTocar,
  });

  final String rotulo;
  final bool selecionada;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selecionada,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Icon(
                selecionada
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selecionada
                    ? AppColors.primariaForte
                    : AppColors.contorno,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rotulo,
                  style: AppText.s(15,
                      peso: selecionada ? FontWeight.w700 : FontWeight.w600,
                      altura: 20,
                      numerosTabulares: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cartão do terapeuta: nome, período do dia e os horários (livres ou
/// apagados). Sem horário livre, o cartão inteiro fica apagado.
class _CartaoTerapeuta extends StatelessWidget {
  const _CartaoTerapeuta({
    required this.terapeuta,
    required this.horarioSelecionado,
    required this.aoEscolher,
  });

  final AgendaTerapeuta terapeuta;
  final int? horarioSelecionado;
  final ValueChanged<int> aoEscolher;

  @override
  Widget build(BuildContext context) {
    final t = terapeuta;
    final ativo = t.temHorarioLivre;
    final ini = t.inicio, fim = t.fim;
    final periodo = ini != null && fim != null
        ? 'período: ${_horaCurta(ini)} às ${_horaCurta(fim)}'
        : '';
    final motivo = t.motivo;
    final selecionado = horarioSelecionado != null;

    return Opacity(
      opacity: ativo ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ativo ? AppColors.superficie : const Color(0xFFF2F0ED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selecionado ? AppColors.primariaForte : AppColors.borda,
            width: selecionado ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AvatarIniciais(
                  iniciais: iniciais(t.nome),
                  tamanho: 40,
                  fundo: ativo ? AppColors.primariaSuave : AppColors.skeleton,
                  cor: ativo ? AppColors.primariaEscura : AppColors.placeholder,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.nome,
                        style: AppText.s(15,
                            peso: FontWeight.w700,
                            altura: 20,
                            cor: ativo
                                ? AppColors.texto
                                : AppColors.placeholder),
                      ),
                      Text(
                        ativo
                            ? periodo
                            : motivo == null
                                ? 'Indisponível'
                                : 'Indisponível · $motivo',
                        style: AppText.s(13,
                            altura: 18,
                            cor: ativo
                                ? AppColors.textoSuave
                                : AppColors.placeholder),
                      ),
                    ],
                  ),
                ),
                if (!ativo)
                  const Etiqueta(
                    texto: 'Indisponível',
                    fundo: AppColors.skeleton,
                    cor: AppColors.textoSuave,
                  ),
              ],
            ),
            if (ativo) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (m, livre) in t.horarios)
                    OpcaoAdmin(
                      rotulo: _horaCurta(m),
                      selecionada: horarioSelecionado == m,
                      habilitada: livre,
                      aoTocar: () => aoEscolher(m),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: Indicador(cor: AppColors.primariaForte)),
      );
}

class _Mensagem extends StatelessWidget {
  const _Mensagem(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: AppText.s(14, altura: 20, cor: AppColors.textoSuave),
      );
}
