import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../core/app_text.dart';
import '../../core/formatadores.dart';
import '../../data/models/modelos.dart';
import '../../data/services/perfil_service.dart';
import '../../widgets/componentes.dart';
import '../../widgets/folhas.dart';

/// Abre a folha com as informações completas do perfil do terapeuta.
Future<void> abrirPerfilTerapeuta(
  BuildContext context, {
  required Terapeuta terapeuta,
  required VoidCallback aoSair,
}) {
  PerfilService.inicializar(terapeuta.id);
  return abrirFolha(
    context,
    builder: (ctx) => _FolhaPerfilTerapeuta(
      terapeuta: terapeuta,
      aoSair: aoSair,
    ),
  );
}

class _FolhaPerfilTerapeuta extends StatefulWidget {
  const _FolhaPerfilTerapeuta({
    required this.terapeuta,
    required this.aoSair,
  });

  final Terapeuta terapeuta;
  final VoidCallback aoSair;

  @override
  State<_FolhaPerfilTerapeuta> createState() => _FolhaPerfilTerapeutaState();
}

class _FolhaPerfilTerapeutaState extends State<_FolhaPerfilTerapeuta> {
  bool _mostrandoSeletor = false;
  bool _carregandoFoto = false;

  final List<({String id, String nome, IconData icone, Color cor})> _avatares = const [
    (id: 'preset_lotus', nome: 'Lótus', icone: Icons.spa_rounded, cor: Color(0xFF6B8E23)),
    (id: 'preset_folha', nome: 'Folha', icone: Icons.eco_rounded, cor: Color(0xFF2E8B57)),
    (id: 'preset_zen', nome: 'Zen', icone: Icons.self_improvement_rounded, cor: Color(0xFF4A7043)),
    (id: 'preset_sol', nome: 'Energia', icone: Icons.wb_sunny_rounded, cor: Color(0xFFD97706)),
    (id: 'preset_massagem', nome: 'Cuidado', icone: Icons.favorite_rounded, cor: Color(0xFFBE185D)),
    (id: 'preset_estrela', nome: 'Brilho', icone: Icons.auto_awesome_rounded, cor: Color(0xFF4338CA)),
  ];

  Future<void> _selecionarAvatar(String id) async {
    if (await _salvarFoto(id) && mounted) {
      setState(() => _mostrandoSeletor = false);
    }
  }

  /// Grava a foto no banco; se falhar, avisa e devolve false.
  Future<bool> _salvarFoto(String? foto) async {
    try {
      await PerfilService.salvarFoto(foto);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Não foi possível salvar a foto. $e'),
          backgroundColor: AppColors.erroTexto,
        ));
      }
      return false;
    }
  }

  bool get _ehDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> _escolherFoto(ImageSource source) async {
    try {
      setState(() => _carregandoFoto = true);
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final salvou =
            await _salvarFoto('data:image/jpeg;base64,$base64String');
        if (mounted) {
          setState(() {
            if (salvou) _mostrandoSeletor = false;
            _carregandoFoto = false;
          });
        }
      } else {
        if (mounted) setState(() => _carregandoFoto = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregandoFoto = false);
        final erroStr = e.toString();
        final String mensagem;
        if (erroStr.contains('MissingPluginException')) {
          mensagem = 'O app precisa ser reiniciado para registrar o novo plugin. No terminal, aperte "q" e rode "flutter run -d windows" novamente.';
        } else if (erroStr.contains('camera') || erroStr.contains('StateError')) {
          mensagem = 'A câmera não está disponível no Windows. Escolha uma foto do computador.';
        } else {
          mensagem = 'Não foi possível carregar a foto: $e';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensagem),
            backgroundColor: AppColors.erroTexto,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _removerFoto() async {
    if (await _salvarFoto(null) && mounted) {
      setState(() => _mostrandoSeletor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.terapeuta;
    final hoje = agora();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AlcaFolha(),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Perfil do Terapeuta',
                style: AppText.s(20, peso: FontWeight.w700, altura: 28),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textoSuave),
                tooltip: 'Fechar',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Avatar com botão de edição
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _mostrandoSeletor = !_mostrandoSeletor),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ValueListenableBuilder<String?>(
                    valueListenable: PerfilService.fotoNotifier,
                    builder: (context, foto, _) {
                      return _WidgetFotoGrande(
                        foto: foto,
                        inicial: t.nome.isNotEmpty ? t.nome[0].toUpperCase() : 'T',
                      );
                    },
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Material(
                      color: AppColors.primariaForte,
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _mostrandoSeletor = !_mostrandoSeletor),
              icon: Icon(
                _mostrandoSeletor ? Icons.keyboard_arrow_up_rounded : Icons.add_a_photo_rounded,
                size: 16,
                color: AppColors.primariaForte,
              ),
              label: Text(
                _mostrandoSeletor ? 'Fechar opções' : 'Alterar foto de perfil',
                style: AppText.s(13, peso: FontWeight.w600, cor: AppColors.primariaForte),
              ),
            ),
          ),
          const SizedBox(height: 4),

          Center(
            child: Text(
              t.nome,
              textAlign: TextAlign.center,
              style: AppText.s(18, peso: FontWeight.w700, altura: 24),
            ),
          ),
          Center(
            child: Text(
              'Terapeuta Corporal · ${t.unidade}',
              textAlign: TextAlign.center,
              style: AppText.s(14, altura: 20, cor: AppColors.textoSuave),
            ),
          ),

          // Painel de seleção de foto da galeria ou avatar
          if (_mostrandoSeletor) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primariaSuave.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primariaForte.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _ehDesktop
                        ? 'Selecione uma foto dos arquivos ou use um avatar:'
                        : 'Selecione uma foto da galeria ou use um avatar:',
                    style: AppText.s(14, peso: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  // Botões para Galeria e Câmera
                  if (_carregandoFoto)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primariaForte),
                      ),
                    )
                  else if (_ehDesktop) ...[
                    ElevatedButton.icon(
                      onPressed: () => _escolherFoto(ImageSource.gallery),
                      icon: const Icon(Icons.folder_open_rounded, size: 20),
                      label: const Text('Escolher foto do computador'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primariaForte,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _escolherFoto(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 18),
                            label: const Text('Galeria'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primariaForte,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _escolherFoto(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_rounded, size: 18, color: AppColors.primariaForte),
                            label: Text(
                              'Câmera',
                              style: AppText.s(14, peso: FontWeight.w600, cor: AppColors.primariaForte),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primariaForte),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borda),
                  const SizedBox(height: 8),
                  Text(
                    'Ou escolha um avatar ilustrado:',
                    style: AppText.s(12, cor: AppColors.textoSecundario),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final av in _avatares)
                        GestureDetector(
                          onTap: () => _selecionarAvatar(av.id),
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: av.cor,
                                  shape: BoxShape.circle,
                                  boxShadow: sombraCard(),
                                ),
                                child: Icon(av.icone, color: Colors.white, size: 22),
                              ),
                              const SizedBox(height: 4),
                              Text(av.nome, style: AppText.s(11, cor: AppColors.textoSuave)),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _removerFoto,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                      label: const Text('Remover foto (usar iniciais)', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Informações detalhadas
          Container(
            decoration: BoxDecoration(
              color: AppColors.superficie,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borda),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _LinhaInfoPerfil(
                  icone: Icons.person_outline_rounded,
                  titulo: 'Nome completo',
                  valor: t.nome,
                ),
                const Divider(height: 20, color: AppColors.divisor),
                _LinhaInfoPerfil(
                  icone: Icons.storefront_outlined,
                  titulo: 'Local de atendimento',
                  valor: '${t.unidade} Shopping',
                ),
                const Divider(height: 20, color: AppColors.divisor),
                _LinhaInfoPerfil(
                  icone: Icons.schedule_rounded,
                  titulo: 'Expediente hoje (${diaSemanaCurto(hoje)})',
                  valor: t.turnoTexto(hoje),
                ),
                const Divider(height: 20, color: AppColors.divisor),
                _LinhaInfoPerfil(
                  icone: Icons.badge_outlined,
                  titulo: 'ID do Terapeuta',
                  valor: t.id,
                ),
                const Divider(height: 20, color: AppColors.divisor),
                _LinhaInfoPerfil(
                  icone: Icons.cloud_done_outlined,
                  titulo: 'Banco de dados',
                  valor: 'TiDB Cloud (Conectado)',
                  corValor: const Color(0xFF2E8B57),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Botão Sair da conta
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.aoSair();
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            label: Text(
              'Sair da conta',
              style: AppText.s(15, peso: FontWeight.w600, cor: Colors.redAccent),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetFotoGrande extends StatelessWidget {
  const _WidgetFotoGrande({
    required this.foto,
    required this.inicial,
  });

  final String? foto;
  final String inicial;

  @override
  Widget build(BuildContext context) {
    if (foto != null && foto!.isNotEmpty) {
      if (foto!.startsWith('data:image')) {
        try {
          final base64Part = foto!.split(',').last;
          final bytes = base64Decode(base64Part);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _avatarIniciais(80, inicial),
            ),
          );
        } catch (_) {
          return _avatarIniciais(80, inicial);
        }
      }

      if (foto!.startsWith('http://') || foto!.startsWith('https://')) {
        return ClipOval(
          child: Image.network(
            foto!,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _avatarIniciais(80, inicial),
          ),
        );
      }

      final corPreset = switch (foto) {
        'preset_lotus' => const Color(0xFF6B8E23),
        'preset_folha' => const Color(0xFF2E8B57),
        'preset_zen' => const Color(0xFF4A7043),
        'preset_sol' => const Color(0xFFD97706),
        'preset_massagem' => const Color(0xFFBE185D),
        'preset_estrela' => const Color(0xFF4338CA),
        _ => AppColors.texto,
      };

      final iconePreset = switch (foto) {
        'preset_lotus' => Icons.spa_rounded,
        'preset_folha' => Icons.eco_rounded,
        'preset_zen' => Icons.self_improvement_rounded,
        'preset_sol' => Icons.wb_sunny_rounded,
        'preset_massagem' => Icons.favorite_rounded,
        'preset_estrela' => Icons.auto_awesome_rounded,
        _ => null,
      };

      if (iconePreset != null) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: corPreset,
            shape: BoxShape.circle,
            boxShadow: sombraCard(),
          ),
          child: Icon(iconePreset, color: Colors.white, size: 40),
        );
      }
    }

    return _avatarIniciais(80, inicial);
  }

  Widget _avatarIniciais(double tamanho, String inicial) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: AppColors.texto,
        shape: BoxShape.circle,
        boxShadow: sombraCard(),
      ),
      alignment: Alignment.center,
      child: Text(
        inicial,
        style: AppText.s(tamanho * 0.45, peso: FontWeight.w700, cor: Colors.white),
      ),
    );
  }
}

class _LinhaInfoPerfil extends StatelessWidget {
  const _LinhaInfoPerfil({
    required this.icone,
    required this.titulo,
    required this.valor,
    this.corValor,
  });

  final IconData icone;
  final String titulo;
  final String valor;
  final Color? corValor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primariaSuave,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, size: 20, color: AppColors.primariaForte),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: AppText.s(12, cor: AppColors.textoSuave),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: AppText.s(
                  14,
                  peso: FontWeight.w600,
                  cor: corValor ?? AppColors.texto,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
