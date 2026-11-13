import 'dart:async';

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
import 'tela_admin.dart';

/// Marca devolvida pelos formulários quando o registro foi excluído.
const registroExcluido = 'excluido';

/// Todos os pacientes da Rokuzen: buscar, cadastrar, editar e excluir.
class AbaPacientesAdmin extends StatefulWidget {
  const AbaPacientesAdmin({super.key, required this.aoSair});
  final VoidCallback aoSair;

  @override
  State<AbaPacientesAdmin> createState() => _AbaPacientesAdminState();
}

class _AbaPacientesAdminState extends State<AbaPacientesAdmin> {
  final _api = AdminApiService();
  final _busca = TextEditingController();
  Timer? _atraso;

  List<PacienteAdmin>? _itens;
  int _total = 0;
  String? _erro;
  int _pedido = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    _atraso?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    final pedido = ++_pedido;
    setState(() => _erro = null);
    try {
      final (total, lista) = await _api.pacientes(busca: _busca.text);
      if (!mounted || pedido != _pedido) return;
      setState(() {
        _total = total;
        _itens = lista;
      });
    } catch (e) {
      if (!mounted || pedido != _pedido) return;
      setState(() {
        _itens ??= const [];
        _erro = '$e';
      });
    }
  }

  void _aoDigitar(String _) {
    _atraso?.cancel();
    _atraso = Timer(const Duration(milliseconds: 350), _carregar);
  }

  Future<void> _abrir([PacienteAdmin? p]) async {
    final r = await _abrirFormulario(context, paciente: p);
    if (r == null || !mounted) return;
    avisarAdmin(
      context,
      r == registroExcluido
          ? 'Paciente excluído.'
          : p == null
              ? 'Paciente cadastrado.'
              : 'Dados do paciente atualizados.',
    );
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final itens = _itens;
    final termo = _busca.text.trim();
    return Scaffold(
      backgroundColor: AppColors.fundo,
      floatingActionButton: BotaoFlutuante(
        rotulo: 'Novo paciente',
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
                      titulo: 'Pacientes',
                      subtitulo: 'Cadastre, edite ou exclua pacientes.',
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
                            dica: 'Nome ou telefone',
                            aoMudar: _aoDigitar,
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
                              itens.length < _total
                                  ? 'Mostrando ${itens.length} de $_total '
                                      'pacientes${termo.isEmpty ? ' · busque para encontrar outros' : ''}'
                                  : '$_total paciente${_total == 1 ? '' : 's'}',
                              style: AppText.s(13,
                                  altura: 18, cor: AppColors.textoSuave),
                            ),
                            const SizedBox(height: 8),
                            if (itens.isEmpty && _erro == null)
                              const EstadoVazio(
                                icone: Icons.person_search_rounded,
                                titulo: 'Nenhum paciente',
                                texto: 'Nenhum paciente encontrado com essa busca.',
                              ),
                            for (final p in itens) ...[
                              LinhaCadastroAdmin(
                                titulo: p.nome,
                                subtitulo: [
                                  if (p.telefone != null) p.telefone!,
                                  if (p.email != null) p.email!,
                                ].join(' · '),
                                aoTocar: () => _abrir(p),
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

/// Linha clicável usada nas listas do administrador.
class LinhaCadastroAdmin extends StatelessWidget {
  const LinhaCadastroAdmin({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.aoTocar,
    this.etiqueta,
  });

  final String titulo;
  final String subtitulo;
  final String? etiqueta;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borda),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              AvatarIniciais(iniciais: iniciais(titulo), tamanho: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppText.s(15, peso: FontWeight.w700, altura: 20)),
                    if (subtitulo.isNotEmpty)
                      Text(subtitulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.s(13,
                              altura: 18, cor: AppColors.textoSuave)),
                  ],
                ),
              ),
              if (etiqueta != null) ...[
                const SizedBox(width: 8),
                Etiqueta(
                  texto: etiqueta!,
                  fundo: AppColors.primariaSuave,
                  cor: AppColors.primariaEscura,
                ),
              ],
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Formulário de paciente (administrador)
// =====================================================================

/// Cadastra um paciente e devolve o paciente salvo (usado no agendamento).
Future<PacienteAdmin?> abrirFormularioPacienteAdmin(BuildContext context) async {
  final r = await _abrirFormulario(context);
  return r is PacienteAdmin ? r : null;
}

/// Devolve o [PacienteAdmin] salvo, [registroExcluido] ou null.
Future<Object?> _abrirFormulario(BuildContext context, {PacienteAdmin? paciente}) {
  return abrirFolha<Object>(
    context,
    builder: (_) => _FolhaPacienteAdmin(paciente: paciente),
  );
}

class _FolhaPacienteAdmin extends StatefulWidget {
  const _FolhaPacienteAdmin({this.paciente});
  final PacienteAdmin? paciente;

  @override
  State<_FolhaPacienteAdmin> createState() => _FolhaPacienteAdminState();
}

class _FolhaPacienteAdminState extends State<_FolhaPacienteAdmin> {
  final _api = AdminApiService();
  late final _nome = TextEditingController(text: widget.paciente?.nome);
  late final _telefone = TextEditingController(
      text: widget.paciente?.telefone == null
          ? null
          : mascaraTelefone(widget.paciente!.telefone!));
  late final _email = TextEditingController(text: widget.paciente?.email);
  late DateTime? _nascimento = widget.paciente?.nascimento;

  String? _erroNome;
  String? _erroTelefone;
  String? _erroEmail;
  String? _erroGeral;
  bool _ocupado = false;

  bool get _novo => widget.paciente == null;

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _escolherNascimento() async {
    final d = await escolherData(
      context,
      rotulo: 'Data de nascimento',
      inicial: _nascimento,
      hoje: agora(),
      maxima: agora(),
      comAnos: true,
      mostrarAno: true,
    );
    if (d != null && mounted) setState(() => _nascimento = d);
  }

  Future<void> _salvar() async {
    if (_ocupado) return;
    final nome = _nome.text.trim();
    final telefone = _telefone.text.trim();
    final email = _email.text.trim();
    setState(() {
      _erroNome = nome.isEmpty ? 'Informe o nome' : null;
      _erroTelefone = apenasDigitos(telefone).length < 8
          ? 'Informe um telefone válido'
          : null;
      _erroEmail = email.isNotEmpty && !RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)
          ? 'E-mail inválido'
          : null;
      _erroGeral = null;
    });
    if (_erroNome != null || _erroTelefone != null || _erroEmail != null) {
      return;
    }
    setState(() => _ocupado = true);
    try {
      final salvo = await _api.salvarPaciente(
        id: widget.paciente?.id,
        nome: nome,
        telefone: telefone,
        email: email.isEmpty ? null : email,
        nascimento: _nascimento,
      );
      if (mounted) Navigator.of(context).pop(salvo);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _erroGeral = 'Não foi possível salvar. $e';
      });
    }
  }

  Future<void> _excluir() async {
    final p = widget.paciente;
    if (p == null || _ocupado) return;
    final ok = await confirmarAdmin(
      context,
      titulo: 'Excluir paciente?',
      texto: '${p.nome} será removido do cadastro. Esta ação não pode ser '
          'desfeita.',
      rotuloConfirmar: 'Sim, excluir',
      icone: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    setState(() {
      _ocupado = true;
      _erroGeral = null;
    });
    try {
      await _api.excluirPaciente(p.id, agora());
      if (mounted) Navigator.of(context).pop(registroExcluido);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _erroGeral = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_ocupado,
      child: FolhaFormulario(
        titulo: _novo ? 'Novo paciente' : 'Editar paciente',
        subtitulo: _novo
            ? 'Cadastro de paciente feito pela administração.'
            : 'Altere os dados ou exclua o paciente.',
        aoFechar: _ocupado ? null : () => Navigator.of(context).pop(),
        children: [
          CampoTexto(
            rotulo: 'Nome completo',
            indicacao: 'Obrigatório',
            controller: _nome,
            icone: Icons.person_outline_rounded,
            dica: 'Nome do paciente',
            erro: _erroNome,
            habilitado: !_ocupado,
            teclado: TextInputType.name,
          ),
          const SizedBox(height: 16),
          CampoTexto(
            rotulo: 'Telefone',
            indicacao: 'Obrigatório',
            controller: _telefone,
            icone: Icons.call_outlined,
            dica: '(11) 99999-9999',
            erro: _erroTelefone,
            habilitado: !_ocupado,
            teclado: TextInputType.phone,
            formatadores: [MascaraTelefoneFormatter()],
          ),
          const SizedBox(height: 16),
          CampoTexto(
            rotulo: 'E-mail',
            indicacao: 'Opcional',
            controller: _email,
            icone: Icons.mail_outline_rounded,
            dica: 'email@exemplo.com',
            erro: _erroEmail,
            habilitado: !_ocupado,
            teclado: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          const RotuloCampo('Data de nascimento', indicacao: 'Opcional'),
          const SizedBox(height: 8),
          CampoSeletor(
            icone: Icons.cake_outlined,
            valor: _nascimento == null
                ? 'Escolha a data'
                : dataCurta(_nascimento!),
            vazio: _nascimento == null,
            habilitado: !_ocupado,
            iconeFinal: Icons.expand_more_rounded,
            aoTocar: _escolherNascimento,
          ),
          if (_erroGeral != null) ...[
            const SizedBox(height: 16),
            Semantics(liveRegion: true, child: ErroCampo(_erroGeral!)),
          ],
          const SizedBox(height: 24),
          BotaoPrimario(
            rotulo: _ocupado
                ? 'Salvando…'
                : _novo
                    ? 'Cadastrar paciente'
                    : 'Salvar alterações',
            carregando: _ocupado,
            aoPressionar: _salvar,
          ),
          if (!_novo) ...[
            const SizedBox(height: 12),
            BotaoExcluirAdmin(
              rotulo: 'Excluir paciente',
              aoPressionar: _ocupado ? null : _excluir,
            ),
          ],
        ],
      ),
    );
  }
}

/// Botão de excluir (contorno vermelho suave).
class BotaoExcluirAdmin extends StatelessWidget {
  const BotaoExcluirAdmin({
    super.key,
    required this.rotulo,
    required this.aoPressionar,
  });

  final String rotulo;
  final VoidCallback? aoPressionar;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: aoPressionar,
      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.ausente),
      label: Text(rotulo,
          style: AppText.s(15, peso: FontWeight.w600, cor: AppColors.ausente)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        side: BorderSide(color: AppColors.ausente.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
