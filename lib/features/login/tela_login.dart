import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/services/auth_api_service.dart';
import '../../data/services/login_preferences_service.dart';
import '../../core/app_text.dart';
import '../../widgets/campos.dart';
import '../../widgets/componentes.dart';
import '../../widgets/decoracao.dart';
import '../../widgets/responsivo.dart';

enum _Estado { ocioso, carregando, sucesso, erro }

/// Tela de login do terapeuta.
/// Autenticação real pelo backend Rokuzen Connect.
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key, required this.aoEntrar});
  final VoidCallback aoEntrar;

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _login = TextEditingController();
  final _senha = TextEditingController();
  final _focoSenha = FocusNode();
  bool _mostrarSenha = false;
  bool _lembrar = false;
  bool _preferenciasCarregadas = false;

  final LoginPreferencesService _loginPreferences = LoginPreferencesService();
  _Estado _estado = _Estado.ocioso;
  String? _erroLogin;
  String _mensagemErro = 'Login ou senha incorretos.';
  String? _erroSenha;

  bool get _ocupado =>
      _estado == _Estado.carregando || _estado == _Estado.sucesso;

  @override
  void initState() {
    super.initState();
    _carregarPreferencias();
  }

  Future<void> _carregarPreferencias() async {
    try {
      final lembrar = await _loginPreferences.deveLembrar();
      final loginSalvo = await _loginPreferences.carregarLogin();

      if (!mounted) return;

      setState(() {
        _lembrar = lembrar;
        _preferenciasCarregadas = true;

        if (lembrar && loginSalvo != null) {
          _login.text = loginSalvo;
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _lembrar = false;
        _preferenciasCarregadas = true;
      });
    }
  }

  @override
  void dispose() {
    _login.dispose();
    _senha.dispose();
    _focoSenha.dispose();
    super.dispose();
  }

  void _limparErros() {
    if (_erroLogin != null || _erroSenha != null || _estado == _Estado.erro) {
      setState(() {
        _erroLogin = null;
        _erroSenha = null;
        if (_estado == _Estado.erro) _estado = _Estado.ocioso;
      });
    }
  }

  Future<void> _entrar() async {
    if (_ocupado) return;

    final login = _login.text.trim();
    final senha = _senha.text;
    final erroLogin = login.isEmpty ? 'Informe seu login' : null;
    final erroSenha = senha.isEmpty ? 'Informe sua senha' : null;

    if (erroLogin != null || erroSenha != null) {
      setState(() {
        _erroLogin = erroLogin;
        _erroSenha = erroSenha;
        _estado = _Estado.ocioso;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _erroLogin = null;
      _erroSenha = null;
      _estado = _Estado.carregando;
    });

    try {
      final resultado = await AuthApiService().autenticar(
        login: login,
        senha: senha,
      );
      if (!mounted) return;

      if (resultado['success'] == true) {
        try {
          if (_lembrar) {
            await _loginPreferences.salvarLogin(login);
          } else {
            await _loginPreferences.limparLogin();
          }
        } catch (_) {
          // Falhas no armazenamento local não impedem o login.
        }

        if (!mounted) return;

        _senha.clear();
        setState(() => _estado = _Estado.sucesso);
        widget.aoEntrar();
      }else {
        if (!mounted) return;
        setState(() {
          _mensagemErro = resultado['message'] is String
              ? resultado['message'] as String
              : 'Login ou senha incorretos.';
          _estado = _Estado.erro;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mensagemErro =
            'Não foi possível autenticar. Verifique suas credenciais e a conexão com o servidor.';
        _estado = _Estado.erro;
      });
    }
  }

  void _esqueciSenha() {
    if (_ocupado) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'A recuperação de senha ainda não está disponível. '
          'Entre em contato com o administrador.',
        ),
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
            tamanho: 328,
            espessura: 5,
            rotacao: 244,
            intensidade: 0.7,
          ),
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
                          top: Radius.circular(32),
                        ),
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
                              padding: EdgeInsets.fromLTRB(
                                0,
                                32,
                                0,
                                24 + MediaQuery.paddingOf(context).bottom,
                              ),
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
            tamanho: 480,
            espessura: 14,
            rotacao: 40,
            intensidade: 0.8,
          ),
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
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _logo(),
                          ),
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
          Text(
            'ROKUZEN CONNECT',
            style: AppText.sobretitulo().copyWith(letterSpacing: 1.4),
          ),
          const SizedBox(height: 8),
          Text('Bem-vindo(a)', style: AppText.tituloTela()),
          const SizedBox(height: 8),
          Text(
            'Acesse sua conta de terapeuta',
            style: AppText.s(15, altura: 24, cor: AppColors.textoSuave),
          ),
          if (erroGeral) ...[
            const SizedBox(height: 24),
            _BannerErro(mensagem: _mensagemErro),
          ],
          SizedBox(height: erroGeral ? 24 : 32),
          CampoTexto(
            rotulo: 'Login',
            controller: _login,
            icone: Icons.person_outline_rounded,
            dica: 'Digite seu login',
            erro: _erroLogin,
            erroComIcone: false,
            teclado: TextInputType.text,
            acaoTeclado: TextInputAction.next,
            autofill: const [AutofillHints.username],
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
                  onTap: _ocupado || !_preferenciasCarregadas
                      ? null
                      : () => setState(() => _lembrar = !_lembrar),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: [
                        Interruptor(
                          valor: _lembrar,
                          aoMudar: (v) {
                            if (_ocupado || !_preferenciasCarregadas) return;

                            setState(() => _lembrar = v);
                          },
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Lembrar de mim',
                            style: AppText.s(
                              14,
                              peso: FontWeight.w500,
                              altura: 20,
                            ),
                          ),
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
          rotulo: 'Entrando…',
          carregando: true,
          aoPressionar: null,
        );
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
  const _BannerErro({required this.mensagem});

  final String mensagem;

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
                      text: mensagem,
                      style: AppText.s(
                        14,
                        peso: FontWeight.w700,
                        altura: 20,
                        cor: AppColors.erroTexto,
                      ),
                    ),
                    TextSpan(
                      text: ' Confira os dados e tente novamente.',
                      style: AppText.s(
                        14,
                        altura: 20,
                        cor: AppColors.erroTexto,
                      ),
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
