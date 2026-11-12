import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/services/senha_api_service.dart';
import '../../widgets/campos.dart';
import '../../widgets/componentes.dart';
import '../../widgets/folhas.dart';

/// Abre o card "Esqueci minha senha". Devolve true se a senha foi trocada.
///
/// Mecanismo simplificado para a apresentação do projeto: confere se o
/// e-mail existe e grava a nova senha, sem código de confirmação.
Future<bool> abrirEsqueciSenha(BuildContext context) async {
  final alterou = await abrirFolha<bool>(
    context,
    builder: (_) => const _FolhaEsqueciSenha(),
  );
  return alterou ?? false;
}

class _FolhaEsqueciSenha extends StatefulWidget {
  const _FolhaEsqueciSenha();

  @override
  State<_FolhaEsqueciSenha> createState() => _FolhaEsqueciSenhaState();
}

class _FolhaEsqueciSenhaState extends State<_FolhaEsqueciSenha> {
  final _api = SenhaApiService();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  final _focoSenha = FocusNode();
  final _focoConfirmacao = FocusNode();

  /// O e-mail foi encontrado: mostra os campos da nova senha.
  bool _emailConfirmado = false;
  bool _ocupado = false;
  bool _mostrarSenha = false;
  String? _erroEmail;
  String? _erroSenha;
  String? _erroConfirmacao;
  String? _erroGeral;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    _confirmacao.dispose();
    _focoSenha.dispose();
    _focoConfirmacao.dispose();
    super.dispose();
  }

  Future<void> _verificarEmail() async {
    if (_ocupado) return;
    final email = _email.text.trim();
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      setState(() => _erroEmail = 'Digite um e-mail válido');
      return;
    }
    setState(() {
      _ocupado = true;
      _erroEmail = null;
      _erroGeral = null;
    });
    try {
      final existe = await _api.emailExiste(email);
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        if (existe) {
          _emailConfirmado = true;
        } else {
          _erroEmail = 'Não encontramos uma conta com este e-mail';
        }
      });
      if (existe) _focoSenha.requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _erroGeral = '$e';
      });
    }
  }

  Future<void> _salvar() async {
    if (_ocupado) return;
    final senha = _senha.text;
    final erroSenha = senha.length < 4
        ? 'A senha precisa ter pelo menos 4 caracteres'
        : senha.length > 50
            ? 'Use no máximo 50 caracteres'
            : null;
    final erroConfirmacao =
        erroSenha == null && _confirmacao.text != senha
            ? 'As senhas não são iguais'
            : null;
    if (erroSenha != null || erroConfirmacao != null) {
      setState(() {
        _erroSenha = erroSenha;
        _erroConfirmacao = erroConfirmacao;
      });
      return;
    }
    setState(() {
      _ocupado = true;
      _erroGeral = null;
    });
    try {
      await _api.redefinir(_email.text, senha);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _erroGeral = 'Não foi possível alterar a senha. $e';
      });
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _botaoVerSenha() => BotaoIcone(
        icone: _mostrarSenha
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        dica: _mostrarSenha ? 'Ocultar senha' : 'Mostrar senha',
        cor: AppColors.textoSuave,
        tamanhoIcone: 22,
        aoPressionar: () => setState(() => _mostrarSenha = !_mostrarSenha),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_ocupado,
      child: FolhaFormulario(
        titulo: 'Esqueci minha senha',
        subtitulo: 'Digite seu e-mail e, caso ele exista, digite sua nova '
            'senha no campo indicado.',
        aoFechar: _ocupado ? null : () => Navigator.of(context).pop(false),
        children: [
          CampoTexto(
            rotulo: 'E-mail',
            controller: _email,
            icone: Icons.mail_outline_rounded,
            dica: 'email@exemplo.com',
            erro: _erroEmail,
            habilitado: !_ocupado && !_emailConfirmado,
            teclado: TextInputType.emailAddress,
            acaoTeclado: TextInputAction.done,
            autofill: const [AutofillHints.email],
            aoMudar: (_) {
              if (_erroEmail != null) setState(() => _erroEmail = null);
            },
            aoEnviar: (_) => _verificarEmail(),
          ),
          if (_emailConfirmado) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 16, color: AppColors.primariaForte),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'E-mail encontrado. Digite sua nova senha abaixo.',
                    style: AppText.s(13,
                        altura: 18, cor: AppColors.primariaForte),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CampoTexto(
              rotulo: 'Nova senha',
              controller: _senha,
              focusNode: _focoSenha,
              icone: Icons.lock_outline_rounded,
              dica: 'Mínimo de 4 caracteres',
              erro: _erroSenha,
              ocultar: !_mostrarSenha,
              habilitado: !_ocupado,
              acaoTeclado: TextInputAction.next,
              autofill: const [AutofillHints.newPassword],
              aoMudar: (_) {
                if (_erroSenha != null) setState(() => _erroSenha = null);
              },
              aoEnviar: (_) => _focoConfirmacao.requestFocus(),
              sufixo: _botaoVerSenha(),
            ),
            const SizedBox(height: 16),
            CampoTexto(
              rotulo: 'Confirmar nova senha',
              controller: _confirmacao,
              focusNode: _focoConfirmacao,
              icone: Icons.lock_outline_rounded,
              dica: 'Digite a senha de novo',
              erro: _erroConfirmacao,
              ocultar: !_mostrarSenha,
              habilitado: !_ocupado,
              acaoTeclado: TextInputAction.done,
              aoMudar: (_) {
                if (_erroConfirmacao != null) {
                  setState(() => _erroConfirmacao = null);
                }
              },
              aoEnviar: (_) => _salvar(),
            ),
          ],
          if (_erroGeral != null) ...[
            const SizedBox(height: 16),
            Semantics(liveRegion: true, child: ErroCampo(_erroGeral!)),
          ],
          const SizedBox(height: 24),
          BotaoPrimario(
            rotulo: _emailConfirmado
                ? (_ocupado ? 'Salvando…' : 'Salvar nova senha')
                : (_ocupado ? 'Verificando…' : 'Continuar'),
            carregando: _ocupado,
            aoPressionar: _emailConfirmado ? _salvar : _verificarEmail,
          ),
          if (_emailConfirmado) ...[
            const SizedBox(height: 12),
            BotaoSecundario(
              rotulo: 'Usar outro e-mail',
              aoPressionar: _ocupado
                  ? null
                  : () => setState(() {
                        _emailConfirmado = false;
                        _senha.clear();
                        _confirmacao.clear();
                        _erroSenha = null;
                        _erroConfirmacao = null;
                        _erroGeral = null;
                      }),
            ),
          ],
        ],
      ),
    );
  }
}
