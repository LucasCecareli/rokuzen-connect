import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/formatadores.dart';
import '../../data/models/modelos.dart';
import '../../data/repositorio.dart';
import '../../widgets/campos.dart';
import '../../widgets/componentes.dart';
import '../../widgets/folhas.dart';
import '../../widgets/seletores.dart';

/// Abre o formulário de novo paciente (ou de edição, se [paciente] vier
/// preenchido). Devolve o paciente salvo, ou null se cancelar.
///
/// Por enquanto o cadastro fica só na memória do aparelho.
Future<Paciente?> abrirFormularioPaciente(
  BuildContext context, {
  Paciente? paciente,
}) {
  return abrirFolha<Paciente>(
    context,
    builder: (_) => _FolhaPaciente(paciente: paciente),
  );
}

class _FolhaPaciente extends StatefulWidget {
  const _FolhaPaciente({this.paciente});
  final Paciente? paciente;

  @override
  State<_FolhaPaciente> createState() => _FolhaPacienteState();
}

class _FolhaPacienteState extends State<_FolhaPaciente> {
  late final _nome = TextEditingController(text: widget.paciente?.nome ?? '');
  late final _telefone =
      TextEditingController(text: widget.paciente?.telefone ?? '');
  late final _email = TextEditingController(text: widget.paciente?.email ?? '');
  late DateTime? _nascimento = widget.paciente?.nascimento;
  final _focoNome = FocusNode();
  final _focoTelefone = FocusNode();
  final _focoEmail = FocusNode();
  String? _erroNome;
  String? _erroTelefone;
  String? _erroEmail;
  bool _salvando = false;
  bool _seletorAberto = false;

  bool get _novo => widget.paciente == null;

  @override
  void initState() {
    super.initState();
    if (_novo) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _focoNome.requestFocus());
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _email.dispose();
    _focoNome.dispose();
    _focoTelefone.dispose();
    _focoEmail.dispose();
    super.dispose();
  }

  Future<void> _escolherNascimento() async {
    if (_salvando) return;
    FocusScope.of(context).unfocus();
    setState(() => _seletorAberto = true);
    final data = await escolherData(
      context,
      rotulo: 'Data de nascimento',
      inicial: _nascimento,
      hoje: agora(),
      maxima: agora(),
      comAnos: true,
      mostrarAno: true,
    );
    if (!mounted) return;
    setState(() {
      _seletorAberto = false;
      if (data != null) _nascimento = data;
    });
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    final nome = _nome.text.trim();
    final digitos = apenasDigitos(_telefone.text);
    final email = _email.text.trim();
    final erroNome = nome.isEmpty ? 'Informe o nome do paciente' : null;
    final erroTelefone = digitos.length == 11
        ? null
        : digitos.isEmpty
            ? 'Informe o telefone'
            : 'Telefone incompleto. Use (11) 99999-9999';
    final erroEmail = email.isNotEmpty &&
            !RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)
        ? 'E-mail inválido'
        : null;
    if (erroNome != null || erroTelefone != null || erroEmail != null) {
      setState(() {
        _erroNome = erroNome;
        _erroTelefone = erroTelefone;
        _erroEmail = erroEmail;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _salvando = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    final Paciente salvo;
    if (_novo) {
      salvo = await repositorio.cadastrarPaciente(
        nome: nome,
        telefone: _telefone.text,
        email: email.isEmpty ? null : email,
        nascimento: _nascimento,
      );
    } else {
      salvo = await repositorio.editarPaciente(
        Paciente(
          id: widget.paciente!.id,
          nome: nome,
          telefone: _telefone.text,
          email: email.isEmpty ? null : email,
          nascimento: _nascimento,
          novo: widget.paciente!.novo,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop(salvo);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_salvando,
      child: FolhaFormulario(
        titulo: _novo ? 'Novo paciente' : 'Editar paciente',
        subtitulo: _novo
            ? 'Preencha os dados básicos para adicionar um paciente.'
            : 'Atualize os dados cadastrais do paciente.',
        aoFechar: _salvando ? null : () => Navigator.of(context).pop(),
        children: [
          CampoTexto(
            rotulo: 'Nome completo',
            indicacao: 'Obrigatório',
            controller: _nome,
            focusNode: _focoNome,
            icone: Icons.person_outline_rounded,
            dica: 'Nome do paciente',
            erro: _erroNome,
            habilitado: !_salvando,
            teclado: TextInputType.name,
            acaoTeclado: TextInputAction.next,
            autofill: const [AutofillHints.name],
            aoMudar: (_) {
              if (_erroNome != null) setState(() => _erroNome = null);
            },
            aoEnviar: (_) => _focoTelefone.requestFocus(),
          ),
          const SizedBox(height: 16),
          CampoTexto(
            rotulo: 'Telefone',
            indicacao: 'Obrigatório',
            controller: _telefone,
            focusNode: _focoTelefone,
            icone: Icons.call_outlined,
            dica: '(11) 99999-9999',
            erro: _erroTelefone,
            habilitado: !_salvando,
            teclado: TextInputType.phone,
            formatadores: [MascaraTelefoneFormatter()],
            acaoTeclado: TextInputAction.next,
            autofill: const [AutofillHints.telephoneNumberNational],
            aoMudar: (_) {
              if (_erroTelefone != null) setState(() => _erroTelefone = null);
            },
            aoEnviar: (_) => _focoEmail.requestFocus(),
          ),
          const SizedBox(height: 16),
          CampoTexto(
            rotulo: 'E-mail',
            indicacao: 'Opcional',
            controller: _email,
            focusNode: _focoEmail,
            icone: Icons.mail_outline_rounded,
            dica: 'email@exemplo.com',
            erro: _erroEmail,
            habilitado: !_salvando,
            teclado: TextInputType.emailAddress,
            acaoTeclado: TextInputAction.done,
            autofill: const [AutofillHints.email],
            aoMudar: (_) {
              if (_erroEmail != null) setState(() => _erroEmail = null);
            },
          ),
          const SizedBox(height: 16),
          const RotuloCampo('Data de nascimento', indicacao: 'Opcional'),
          const SizedBox(height: 8),
          CampoSeletor(
            icone: Icons.cake_outlined,
            valor: _nascimento == null ? 'dd/mm/aaaa' : dataCurta(_nascimento!),
            vazio: _nascimento == null,
            iconeFinal: Icons.calendar_month_outlined,
            foco: _seletorAberto,
            habilitado: !_salvando,
            rotuloAcessivel: 'Data de nascimento',
            aoTocar: _escolherNascimento,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 10,
                child: Opacity(
                  opacity: _salvando ? 0.6 : 1,
                  child: BotaoSecundario(
                    rotulo: 'Cancelar',
                    aoPressionar:
                        _salvando ? null : () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 18,
                child: BotaoPrimario(
                  rotulo: _salvando
                      ? (_novo ? 'Cadastrando…' : 'Salvando…')
                      : (_novo ? 'Cadastrar paciente' : 'Salvar alterações'),
                  carregando: _salvando,
                  aoPressionar: _salvar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
