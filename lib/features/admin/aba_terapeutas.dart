import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../core/app_text.dart';
import '../../core/formatadores.dart';
import '../../data/services/admin_api_service.dart';
import '../../widgets/campos.dart';
import '../../widgets/componentes.dart';
import '../../widgets/decoracao.dart';
import '../../widgets/folhas.dart';
import '../../widgets/responsivo.dart';
import '../../widgets/seletores.dart';
import 'aba_pacientes_admin.dart';
import 'tela_admin.dart';

/// Terapeutas (usuários tipo 3): cadastrar, editar e excluir.
class AbaTerapeutas extends StatefulWidget {
  const AbaTerapeutas({super.key, required this.aoSair});
  final VoidCallback aoSair;

  @override
  State<AbaTerapeutas> createState() => _AbaTerapeutasState();
}

class _AbaTerapeutasState extends State<AbaTerapeutas> {
  final _api = AdminApiService();
  final _busca = TextEditingController();

  List<TerapeutaAdmin>? _itens;
  List<UnidadeAdmin> _unidades = const [];
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final resultados = await Future.wait([
        _api.terapeutas(),
        _api.unidades(todas: true),
      ]);
      if (!mounted) return;
      setState(() {
        _itens = resultados[0] as List<TerapeutaAdmin>;
        _unidades = resultados[1] as List<UnidadeAdmin>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _itens ??= const [];
        _erro = '$e';
      });
    }
  }

  String _nomesUnidades(List<String> ids) {
    final nomes = [
      for (final id in ids)
        _unidades.where((u) => u.id == id).firstOrNull?.nome ?? id,
    ];
    return nomes.isEmpty ? 'Sem unidade' : nomes.join(', ');
  }

  Future<void> _abrir([TerapeutaAdmin? t]) async {
    if (_unidades.isEmpty) {
      await _carregar();
      if (!mounted) return;
    }
    final r = await abrirFolha<Object>(
      context,
      builder: (_) => _FolhaTerapeuta(terapeuta: t, unidades: _unidades),
    );
    if (r == null || !mounted) return;
    avisarAdmin(
      context,
      r == registroExcluido
          ? 'Terapeuta excluído.'
          : t == null
              ? 'Terapeuta cadastrado.'
              : 'Dados do terapeuta atualizados.',
    );
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final termo = normalizar(_busca.text.trim());
    final itens = _itens?.where((t) {
      if (termo.isEmpty) return true;
      return normalizar('${t.nome} ${t.apelido ?? ''} ${t.login ?? ''}')
          .contains(termo);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.fundo,
      floatingActionButton: BotaoFlutuante(
        rotulo: 'Novo terapeuta',
        icone: Icons.person_add_alt_1_rounded,
        aoPressionar: _abrir,
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
                      titulo: 'Terapeutas',
                      subtitulo: 'Cadastre, edite ou exclua terapeutas.',
                      aoSair: widget.aoSair,
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CampoTexto(
                            rotulo: 'Buscar',
                            controller: _busca,
                            icone: Icons.search_rounded,
                            dica: 'Nome, apelido ou login',
                            aoMudar: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          if (_erro != null) ...[
                            ErroAdmin(mensagem: _erro!, aoTentar: _carregar),
                            const SizedBox(height: 16),
                          ],
                          if (itens == null)
                            for (var i = 0; i < 4; i++) ...[
                              const Esqueleto(altura: 72, raio: 16),
                              const SizedBox(height: 8),
                            ]
                          else ...[
                            Text(
                              '${itens.length} terapeuta${itens.length == 1 ? '' : 's'}',
                              style: AppText.s(13,
                                  altura: 18, cor: AppColors.textoSuave),
                            ),
                            const SizedBox(height: 8),
                            if (itens.isEmpty && _erro == null)
                              const EstadoVazio(
                                icone: Icons.person_search_rounded,
                                titulo: 'Nenhum terapeuta',
                                texto: 'Nenhum terapeuta encontrado.',
                              ),
                            for (final t in itens) ...[
                              LinhaCadastroAdmin(
                                titulo: t.apelido == null
                                    ? t.nome
                                    : '${t.nome} (${t.apelido})',
                                subtitulo: [
                                  if (t.login != null) 'Login: ${t.login}',
                                  _nomesUnidades(t.unidades),
                                ].join(' · '),
                                aoTocar: () => _abrir(t),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ],
                      ),
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
}

// =====================================================================
// Formulário de terapeuta
// =====================================================================

class _FolhaTerapeuta extends StatefulWidget {
  const _FolhaTerapeuta({required this.terapeuta, required this.unidades});
  final TerapeutaAdmin? terapeuta;
  final List<UnidadeAdmin> unidades;

  @override
  State<_FolhaTerapeuta> createState() => _FolhaTerapeutaState();
}

class _FolhaTerapeutaState extends State<_FolhaTerapeuta> {
  final _api = AdminApiService();
  late final _nome = TextEditingController(text: widget.terapeuta?.nome);
  late final _apelido = TextEditingController(text: widget.terapeuta?.apelido);
  late final _login = TextEditingController(text: widget.terapeuta?.login);
  late final _email = TextEditingController(text: widget.terapeuta?.email);
  final _senha = TextEditingController();
  late final Set<String> _unidades = {...?widget.terapeuta?.unidades};

  // Escala: "sistema" (segue a escala já lançada), um dos turnos padrão
  // da Rokuzen ou "personalizado".
  static const _turnosPadrao = [
    (id: 'manha', nome: 'Manhã', inicio: 10 * 60, fim: 16 * 60),
    (id: 'tarde', nome: 'Tarde', inicio: 13 * 60, fim: 19 * 60),
    (id: 'noite', nome: 'Noite', inicio: 16 * 60, fim: 22 * 60),
  ];
  static const _nomesDias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  late String _modoEscala;
  late int _inicioEscala;
  late int _fimEscala;
  late Set<int> _diasEscala;
  String? _erroEscala;

  bool _mostrarSenha = false;
  bool _ocupado = false;
  String? _erroNome;
  String? _erroLogin;
  String? _erroSenha;
  String? _erroEmail;
  String? _erroUnidades;
  String? _erroGeral;

  bool get _novo => widget.terapeuta == null;

  @override
  void initState() {
    super.initState();
    final e = widget.terapeuta?.escala;
    if (e == null) {
      // Novo terapeuta: turno da manhã de segunda a sábado. Terapeuta que
      // já existe: continua com a escala do sistema até escolherem outra.
      _modoEscala = _novo ? 'manha' : 'sistema';
      _inicioEscala = 10 * 60;
      _fimEscala = 16 * 60;
      _diasEscala = {1, 2, 3, 4, 5, 6};
    } else {
      final padrao = _turnosPadrao
          .where((t) => t.inicio == e.inicio && t.fim == e.fim)
          .firstOrNull;
      _modoEscala = padrao?.id ?? 'personalizado';
      _inicioEscala = e.inicio;
      _fimEscala = e.fim;
      _diasEscala = {...e.dias};
    }
  }

  void _escolherModo(String modo) {
    setState(() {
      _modoEscala = modo;
      _erroEscala = null;
      final padrao = _turnosPadrao.where((t) => t.id == modo).firstOrNull;
      if (padrao != null) {
        _inicioEscala = padrao.inicio;
        _fimEscala = padrao.fim;
      }
    });
  }

  Future<void> _escolherHora({required bool inicio}) async {
    final m = await escolherHorario(
      context,
      rotulo: inicio ? 'Início do expediente' : 'Fim do expediente',
      diaTexto: 'Escala do terapeuta',
      inicial: inicio ? _inicioEscala : _fimEscala,
      desabilitado: (m) => inicio ? m >= _fimEscala : m <= _inicioEscala,
      conflito: (_) => false,
    );
    if (m == null || !mounted) return;
    setState(() {
      if (inicio) {
        _inicioEscala = m;
      } else {
        _fimEscala = m;
      }
      _erroEscala = null;
    });
  }

  EscalaAdmin? get _escalaEscolhida => _modoEscala == 'sistema'
      ? null
      : EscalaAdmin(
          dias: _diasEscala, inicio: _inicioEscala, fim: _fimEscala);

  @override
  void dispose() {
    _nome.dispose();
    _apelido.dispose();
    _login.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_ocupado) return;
    final nome = _nome.text.trim();
    final login = _login.text.trim();
    final senha = _senha.text;
    final email = _email.text.trim();
    setState(() {
      _erroNome = nome.isEmpty
          ? 'Informe o nome'
          : nome.length > 50
              ? 'Use no máximo 50 caracteres'
              : null;
      _erroLogin = login.isEmpty
          ? 'Informe o login'
          : login.length > 20 || login.contains(' ')
              ? 'Até 20 caracteres, sem espaços'
              : null;
      _erroSenha = (_novo || senha.isNotEmpty) &&
              (senha.length < 4 || senha.length > 50)
          ? 'A senha precisa ter de 4 a 50 caracteres'
          : null;
      _erroEmail = email.isNotEmpty && !RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)
          ? 'E-mail inválido'
          : null;
      _erroUnidades =
          _unidades.isEmpty ? 'Escolha pelo menos uma unidade' : null;
      _erroEscala = _modoEscala == 'sistema'
          ? null
          : _diasEscala.isEmpty
              ? 'Escolha pelo menos um dia'
              : _fimEscala <= _inicioEscala
                  ? 'O fim precisa ser depois do início'
                  : null;
      _erroGeral = null;
    });
    if ([
      _erroNome,
      _erroLogin,
      _erroSenha,
      _erroEmail,
      _erroUnidades,
      _erroEscala,
    ].any((e) => e != null)) {
      return;
    }

    setState(() => _ocupado = true);
    try {
      await _api.salvarTerapeuta(
        id: widget.terapeuta?.id,
        nome: nome,
        login: login,
        unidades: _unidades.toList(),
        apelido: _apelido.text.trim().isEmpty ? null : _apelido.text.trim(),
        email: email.isEmpty ? null : email,
        senha: senha.isEmpty ? null : senha,
        escala: _escalaEscolhida,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _erroGeral = 'Não foi possível salvar. $e';
      });
    }
  }

  Future<void> _excluir() async {
    final t = widget.terapeuta;
    if (t == null || _ocupado) return;
    final ok = await confirmarAdmin(
      context,
      titulo: 'Excluir terapeuta?',
      texto: '${t.nome} perderá o acesso ao app e sairá do cadastro. '
          'Os atendimentos antigos continuam no histórico.',
      rotuloConfirmar: 'Sim, excluir',
      icone: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    setState(() {
      _ocupado = true;
      _erroGeral = null;
    });
    try {
      await _api.excluirTerapeuta(t.id, agora());
      if (mounted) Navigator.of(context).pop(registroExcluido);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _erroGeral = '$e';
      });
    }
  }

  /// "10h", "13h30"
  static String _hora(int minutos) {
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return m == 0 ? '${h}h' : '${h}h${doisDigitos(m)}';
  }

  List<Widget> _secaoEscala() {
    final personalizado = _modoEscala == 'personalizado';
    return [
      RotuloCampo('Escala',
          indicacao: 'Turnos padrão da Rokuzen',
          cor: _erroEscala == null ? null : AppColors.erro),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (!_novo)
            OpcaoAdmin(
              rotulo: 'Escala do sistema',
              detalhe: 'Segue a escala já lançada',
              selecionada: _modoEscala == 'sistema',
              habilitada: !_ocupado,
              aoTocar: () => _escolherModo('sistema'),
            ),
          for (final t in _turnosPadrao)
            OpcaoAdmin(
              rotulo: t.nome,
              detalhe: '${_hora(t.inicio)} às ${_hora(t.fim)}',
              selecionada: _modoEscala == t.id,
              habilitada: !_ocupado,
              aoTocar: () => _escolherModo(t.id),
            ),
          OpcaoAdmin(
            rotulo: 'Personalizado',
            detalhe: 'Escolha o horário',
            selecionada: personalizado,
            habilitada: !_ocupado,
            aoTocar: () => _escolherModo('personalizado'),
          ),
        ],
      ),
      if (personalizado) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CampoSeletor(
                icone: Icons.login_rounded,
                valor: 'Início · ${horaDeMinutos(_inicioEscala)}',
                habilitado: !_ocupado,
                aoTocar: () => _escolherHora(inicio: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CampoSeletor(
                icone: Icons.logout_rounded,
                valor: 'Fim · ${horaDeMinutos(_fimEscala)}',
                habilitado: !_ocupado,
                aoTocar: () => _escolherHora(inicio: false),
              ),
            ),
          ],
        ),
      ],
      if (_modoEscala != 'sistema') ...[
        const SizedBox(height: 16),
        const RotuloCampo('Dias de trabalho'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var d = 1; d <= 7; d++)
              OpcaoAdmin(
                rotulo: _nomesDias[d - 1],
                selecionada: _diasEscala.contains(d),
                habilitada: !_ocupado,
                aoTocar: () => setState(() {
                  if (!_diasEscala.remove(d)) _diasEscala.add(d);
                  _erroEscala = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _diasEscala.contains(7)
              ? 'Domingo: das 14h às 20h, horário das unidades da Rokuzen.'
              : 'Domingo é opcional (das 14h às 20h, horário das unidades).',
          style: AppText.s(13, altura: 18, cor: AppColors.textoSuave),
        ),
      ],
      if (_erroEscala != null) ...[
        const SizedBox(height: 8),
        ErroCampo(_erroEscala!),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_ocupado,
      child: FolhaFormulario(
        titulo: _novo ? 'Novo terapeuta' : 'Editar terapeuta',
        subtitulo: _novo
            ? 'O terapeuta entra no app com o login e a senha definidos aqui.'
            : 'Altere os dados, as unidades ou a senha.',
        aoFechar: _ocupado ? null : () => Navigator.of(context).pop(),
        children: [
          CampoTexto(
            rotulo: 'Nome completo',
            indicacao: 'Obrigatório',
            controller: _nome,
            icone: Icons.person_outline_rounded,
            dica: 'Nome do terapeuta',
            erro: _erroNome,
            habilitado: !_ocupado,
            teclado: TextInputType.name,
          ),
          const SizedBox(height: 16),
          CampoTexto(
            rotulo: 'Apelido',
            indicacao: 'Opcional',
            controller: _apelido,
            icone: Icons.badge_outlined,
            dica: 'Como aparece no app',
            habilitado: !_ocupado,
          ),
          const SizedBox(height: 16),
          CampoTexto(
            rotulo: 'Login',
            indicacao: 'Obrigatório',
            controller: _login,
            icone: Icons.account_circle_outlined,
            dica: 'Usado para entrar no app',
            erro: _erroLogin,
            habilitado: !_ocupado,
          ),
          const SizedBox(height: 16),
          CampoTexto(
            rotulo: _novo ? 'Senha' : 'Nova senha',
            indicacao: _novo ? 'Obrigatório' : 'Deixe em branco para manter',
            controller: _senha,
            icone: Icons.lock_outline_rounded,
            dica: 'Mínimo de 4 caracteres',
            erro: _erroSenha,
            ocultar: !_mostrarSenha,
            habilitado: !_ocupado,
            sufixo: BotaoIcone(
              icone: _mostrarSenha
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              dica: _mostrarSenha ? 'Ocultar senha' : 'Mostrar senha',
              cor: AppColors.textoSuave,
              tamanhoIcone: 22,
              aoPressionar: () =>
                  setState(() => _mostrarSenha = !_mostrarSenha),
            ),
          ),
          const SizedBox(height: 16),
          CampoTexto(
            rotulo: 'E-mail',
            indicacao: 'Opcional',
            controller: _email,
            icone: Icons.mail_outline_rounded,
            dica: 'Usado em "Esqueci minha senha"',
            erro: _erroEmail,
            habilitado: !_ocupado,
            teclado: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          RotuloCampo('Unidades',
              indicacao: 'Obrigatório',
              cor: _erroUnidades == null ? null : AppColors.erro),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final u in widget.unidades)
                OpcaoAdmin(
                  rotulo: u.nome,
                  selecionada: _unidades.contains(u.id),
                  habilitada: !_ocupado,
                  aoTocar: () => setState(() {
                    if (!_unidades.remove(u.id)) _unidades.add(u.id);
                    _erroUnidades = null;
                  }),
                ),
            ],
          ),
          if (_erroUnidades != null) ...[
            const SizedBox(height: 8),
            ErroCampo(_erroUnidades!),
          ],
          const SizedBox(height: 24),
          ..._secaoEscala(),
          if (_erroGeral != null) ...[
            const SizedBox(height: 16),
            Semantics(liveRegion: true, child: ErroCampo(_erroGeral!)),
          ],
          const SizedBox(height: 24),
          BotaoPrimario(
            rotulo: _ocupado
                ? 'Salvando…'
                : _novo
                    ? 'Cadastrar terapeuta'
                    : 'Salvar alterações',
            carregando: _ocupado,
            aoPressionar: _salvar,
          ),
          if (!_novo) ...[
            const SizedBox(height: 12),
            BotaoExcluirAdmin(
              rotulo: 'Excluir terapeuta',
              aoPressionar: _ocupado ? null : _excluir,
            ),
          ],
        ],
      ),
    );
  }
}
