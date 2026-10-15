import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../core/app_text.dart';
import '../../widgets/campos.dart';
import '../../widgets/componentes.dart';
import '../../widgets/decoracao.dart';
import '../../widgets/folhas.dart';
import '../../widgets/responsivo.dart';

enum _Estado { ocioso, carregando, sucesso, erro }

/// Tela de login do terapeuta.
///
/// Modo de demonstração: aceita qualquer e-mail terminado em @gmail.com e
/// qualquer senha não vazia.
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key, required this.aoEntrar});
  final VoidCallback aoEntrar;

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _focoSenha = FocusNode();
  bool _mostrarSenha = false;
  bool _lembrar = true;
  _Estado _estado = _Estado.ocioso;
  String? _erroEmail;
  String? _erroSenha;
  Timer? _timer;

  bool get _ocupado =>
      _estado == _Estado.carregando || _estado == _Estado.sucesso;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _senha.dispose();
    _focoSenha.dispose();
    super.dispose();
  }

  void _limparErros() {
    if (_erroEmail != null || _erroSenha != null || _estado == _Estado.erro) {
      setState(() {
        _erroEmail = null;
        _erroSenha = null;
        if (_estado == _Estado.erro) _estado = _Estado.ocioso;
      });
    }
  }

  void _entrar() {
    if (_ocupado) return;
    final email = _email.text.trim();
    final senha = _senha.text;
    String? erroEmail;
    String? erroSenha;
    if (AppConfig.modoDemonstracao) {
      if (!RegExp(r'^\S+@gmail\.com$', caseSensitive: false).hasMatch(email)) {
        erroEmail = 'Use um e-mail válido terminado em @gmail.com';
      }
      if (senha.isEmpty) erroSenha = 'Digite sua senha';
    } else {
      if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
        erroEmail = email.isEmpty ? 'Informe seu e-mail' : 'Informe um e-mail válido';
      }
      if (senha.isEmpty) erroSenha = 'Informe sua senha';
    }
    if (erroEmail != null || erroSenha != null) {
      setState(() {
        _erroEmail = erroEmail;
        _erroSenha = erroSenha;
        _estado = _Estado.ocioso;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _erroEmail = null;
      _erroSenha = null;
      _estado = _Estado.carregando;
    });
    // TODO(grupo): quando houver autenticação real, validar no backend aqui
    // e usar `_Estado.erro` para "E-mail ou senha incorretos".
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _estado = _Estado.sucesso);
      _timer = Timer(const Duration(milliseconds: 900), widget.aoEntrar);
    });
  }

  Future<void> _esqueciSenha() async {
    if (_ocupado) return;
    final email = _email.text.trim();
    await abrirFolha<void>(
      context,
      builder: (_) => _FolhaRedefinirSenha(
        email: RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)
            ? email
            : 'seuemail@gmail.com',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final erroGeral = _estado == _Estado.erro;
    final largo = ehTelaLarga(context, limite: 720);
    return Scaffold(
      backgroundColor: largo ? AppColors.fundoLogin : AppColors.superficie,
      body: largo ? _layoutLargo(erroGeral) : _layoutCelular(erroGeral),
    );
  }

  /// Celular: faixa verde no topo e folha branca até o fim da tela.
  Widget _layoutCelular(bool erroGeral) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 280 + MediaQuery.paddingOf(context).top - 47,
          child: const ColoredBox(color: AppColors.fundoLogin),
        ),
        const Positioned(
          top: -96,
          right: -120,
          child: AnelEnso(tamanho: 340, espessura: 16, intensidade: 1.2),
        ),
        const Positioned(
          top: -84,
          right: -112,
          child: AnelEnso(
              tamanho: 328, espessura: 5, rotacao: 244, intensidade: 0.7),
        ),
        SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, c) {
              final alturaLogo = erroGeral ? 72.0 : 104.0;
              final espaco = erroGeral ? 8.0 : 24.0;
              final alturaMinima = (c.maxHeight - alturaLogo - espaco)
                  .clamp(0.0, double.infinity)
                  .toDouble();
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: alturaLogo,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      alignment: Alignment.centerLeft,
                      child: _logo(),
                    ),
                    SizedBox(height: espaco),
                    Container(
                      constraints: BoxConstraints(minHeight: alturaMinima),
                      decoration: BoxDecoration(
                        color: AppColors.superficie,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.texto.withValues(alpha: 0.04),
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (alturaMinima - 32)
                              .clamp(0.0, double.infinity)
                              .toDouble(),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _formulario(erroGeral),
                            Padding(
                              padding: EdgeInsets.fromLTRB(0, 32, 0,
                                  24 + MediaQuery.paddingOf(context).bottom),
                              child: _rodape(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Computador / tablet: cartão centralizado sobre o fundo verde-claro.
  Widget _layoutLargo(bool erroGeral) {
    return Stack(
      children: [
        const Positioned(
          top: -160,
          right: -160,
          child: AnelEnso(tamanho: 520, espessura: 22, intensidade: 1.2),
        ),
        const Positioned(
          bottom: -220,
          left: -180,
          child: AnelEnso(
              tamanho: 480, espessura: 14, rotacao: 40, intensidade: 0.8),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(40, 40, 40, 40),
                      decoration: BoxDecoration(
                        color: AppColors.superficie,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: sombraCard(0.3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(alignment: Alignment.centerLeft, child: _logo()),
                          const SizedBox(height: 32),
                          _formulario(erroGeral),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _rodape(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _logo() => Image.asset(
        'assets/images/rokuzen_logo.png',
        height: 53,
        semanticLabel: 'Rokuzen',
      );

  Widget _rodape() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Rokuzen Connect', style: _estiloRodape),
        const SizedBox(width: 8),
        Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: AppColors.primaria,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text('App do Terapeuta', style: _estiloRodape),
      ],
    );
  }

  Widget _formulario(bool erroGeral) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Text('ROKUZEN CONNECT',
                style: AppText.sobretitulo().copyWith(letterSpacing: 1.4)),
            const SizedBox(height: 8),
            Text('Bem-vindo(a)', style: AppText.tituloTela()),
            const SizedBox(height: 8),
            Text(
              'Acesse sua conta de terapeuta',
              style: AppText.s(15, altura: 24, cor: AppColors.textoSuave),
            ),
            if (erroGeral) ...[
              const SizedBox(height: 24),
              const _BannerErro(),
            ],
            SizedBox(height: erroGeral ? 24 : 32),
            CampoTexto(
              rotulo: 'E-mail',
              controller: _email,
              icone: Icons.mail_outline_rounded,
              dica: AppConfig.modoDemonstracao
                  ? 'seuemail@gmail.com'
                  : 'seuemail@rokuzen.com.br',
              erro: _erroEmail,
              erroComIcone: false,
              teclado: TextInputType.emailAddress,
              acaoTeclado: TextInputAction.next,
              autofill: const [AutofillHints.username, AutofillHints.email],
              habilitado: !_ocupado,
              aoMudar: (_) => _limparErros(),
              aoEnviar: (_) => _focoSenha.requestFocus(),
            ),
            const SizedBox(height: 16),
            CampoTexto(
              rotulo: 'Senha',
              controller: _senha,
              focusNode: _focoSenha,
              icone: Icons.lock_outline_rounded,
              dica: 'Digite sua senha',
              erro: _erroSenha,
              erroComIcone: false,
              ocultar: !_mostrarSenha,
              acaoTeclado: TextInputAction.done,
              autofill: const [AutofillHints.password],
              habilitado: !_ocupado,
              aoMudar: (_) => _limparErros(),
              aoEnviar: (_) => _entrar(),
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _lembrar = !_lembrar),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(
                        children: [
                          Interruptor(
                            valor: _lembrar,
                            aoMudar: (v) => setState(() => _lembrar = v),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text('Lembrar de mim',
                                style: AppText.s(14,
                                    peso: FontWeight.w500, altura: 20)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(8, 0),
                  child: BotaoTexto(
                    rotulo: 'Esqueci minha senha',
                    aoPressionar: _esqueciSenha,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _botaoEntrar(),
        ],
      ),
    );
  }

  TextStyle get _estiloRodape =>
      AppText.s(12, altura: 16, cor: AppColors.textoRodape);

  Widget _botaoEntrar() {
    switch (_estado) {
      case _Estado.carregando:
        return BotaoPrimario(
            rotulo: 'Entrando…', carregando: true, aoPressionar: null);
      case _Estado.sucesso:
        return BotaoPrimario(
          rotulo: 'Tudo certo!',
          icone: Icons.check_circle_outline_rounded,
          aoPressionar: () {},
        );
      case _Estado.ocioso:
      case _Estado.erro:
        return BotaoPrimario(
          rotulo: 'Entrar',
          icone: Icons.arrow_forward_rounded,
          iconeDepois: true,
          aoPressionar: _entrar,
        );
    }
  }
}

class _BannerErro extends StatelessWidget {
  const _BannerErro();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.erroFundo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_rounded, size: 20, color: AppColors.erro),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'E-mail ou senha incorretos. ',
                      style: AppText.s(14,
                          peso: FontWeight.w700,
                          altura: 20,
                          cor: AppColors.erroTexto),
                    ),
                    TextSpan(
                      text: 'Confira os dados e tente novamente.',
                      style: AppText.s(14, altura: 20, cor: AppColors.erroTexto),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Folha "Redefinir senha" (apenas visual por enquanto: nada é gravado).
class _FolhaRedefinirSenha extends StatefulWidget {
  const _FolhaRedefinirSenha({required this.email});
  final String email;

  @override
  State<_FolhaRedefinirSenha> createState() => _FolhaRedefinirSenhaState();
}

class _FolhaRedefinirSenhaState extends State<_FolhaRedefinirSenha> {
  final _senha = TextEditingController();
  bool _mostrar = false;
  bool _erro = false;
  bool _salvando = false;
  bool _concluido = false;

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    if (_senha.text.length < 8) {
      setState(() => _erro = true);
      return;
    }
    setState(() => _salvando = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _concluido = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_concluido) return _telaConcluido();
    final ok = _senha.text.length >= 8;
    final corAjuda = _erro
        ? AppColors.erro
        : ok
            ? AppColors.primariaForte
            : AppColors.textoSuave;
    return FolhaFormulario(
      titulo: 'Redefinir senha',
      subtitulo: 'Escolha uma nova senha para sua conta.',
      aoFechar: _salvando ? null : () => Navigator.of(context).pop(),
      children: [
        Text('E-mail', style: AppText.s(14, peso: FontWeight.w600, altura: 20)),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.fundoLogin,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.mail_outline_rounded,
                  size: 22, color: AppColors.primariaForte),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.email,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.s(16, peso: FontWeight.w600, altura: 24),
                ),
              ),
              const Icon(Icons.verified_user_rounded,
                  size: 20, color: AppColors.primariaForte),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CampoTexto(
          rotulo: 'Nova senha',
          controller: _senha,
          icone: Icons.lock_reset_rounded,
          dica: 'Digite a nova senha',
          ocultar: !_mostrar,
          habilitado: !_salvando,
          erro: _erro ? ' ' : null,
          aoMudar: (_) => setState(() => _erro = false),
          aoEnviar: (_) => _salvar(),
          sufixo: BotaoIcone(
            icone: _mostrar
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            dica: _mostrar ? 'Ocultar senha' : 'Mostrar senha',
            cor: AppColors.textoSuave,
            tamanhoIcone: 22,
            aoPressionar: () => setState(() => _mostrar = !_mostrar),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              Icon(
                _erro
                    ? Icons.error_rounded
                    : ok
                        ? Icons.check_circle_rounded
                        : Icons.info_rounded,
                size: 16,
                color: corAjuda,
              ),
              const SizedBox(width: 4),
              Text(
                _erro
                    ? 'A senha precisa ter pelo menos 8 caracteres'
                    : 'Mínimo de 8 caracteres',
                style: AppText.s(12, altura: 16, cor: corAjuda),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        BotaoPrimario(
          rotulo: _salvando ? 'Salvando…' : 'Salvar nova senha',
          carregando: _salvando,
          aoPressionar: _salvar,
        ),
        const SizedBox(height: 8),
        Center(
          child: BotaoTexto(
            rotulo: 'Cancelar',
            aoPressionar: _salvando ? null : () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _telaConcluido() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AlcaFolha(),
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.fundoLogin,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                size: 44, color: AppColors.primariaForte),
          ),
          const SizedBox(height: 16),
          Text('Senha alterada',
              style: AppText.s(22, peso: FontWeight.w700, altura: 28)),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: AppText.s(14, altura: 20, cor: AppColors.textoSuave),
              children: [
                const TextSpan(text: 'Pronto! Já pode entrar com a nova senha em '),
                TextSpan(
                  text: widget.email,
                  style: AppText.s(14, peso: FontWeight.w600, altura: 20),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: BotaoPrimario(
              rotulo: 'Voltar ao login',
              icone: Icons.arrow_forward_rounded,
              iconeDepois: true,
              aoPressionar: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
