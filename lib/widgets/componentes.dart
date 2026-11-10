import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../data/models/modelos.dart';
import '../data/services/perfil_service.dart';
import '../features/perfil/folha_perfil_terapeuta.dart';
import 'decoracao.dart';
import 'responsivo.dart';

// ======================================================================
// Status
// ======================================================================

class EstiloStatus {
  const EstiloStatus(this.fundo, this.texto, this.icone);
  final Color fundo;
  final Color texto;
  final IconData icone;
}

EstiloStatus estiloStatus(StatusAtendimento s) => switch (s) {
      StatusAtendimento.confirmado => const EstiloStatus(
          AppColors.primariaSuave, AppColors.primariaEscura, Icons.check_rounded),
      StatusAtendimento.pendente => const EstiloStatus(
          Color(0xFFFDF0D9), Color(0xFF7A4A00), Icons.schedule_rounded),
      StatusAtendimento.andamento => const EstiloStatus(
          AppColors.azulSuave, AppColors.azul, Icons.play_circle_rounded),
      StatusAtendimento.concluido => const EstiloStatus(
          Color(0xFFF0EDE9), AppColors.textoSecundario, Icons.check_circle_rounded),
      StatusAtendimento.cancelado => const EstiloStatus(
          Color(0xFFF6EBE4), Color(0xFF7A3E22), Icons.event_busy_rounded),
      StatusAtendimento.faltou => const EstiloStatus(
          AppColors.erroFundo, AppColors.erroTexto, Icons.person_off_rounded),
    };

/// Chip de status ("✓ Confirmado").
class ChipStatus extends StatelessWidget {
  const ChipStatus(this.status, {super.key});
  final StatusAtendimento status;

  @override
  Widget build(BuildContext context) {
    final e = estiloStatus(status);
    return Etiqueta(
      texto: status.rotulo,
      icone: e.icone,
      fundo: e.fundo,
      cor: e.texto,
    );
  }
}

/// Etiqueta pequena com ícone (chips de status, "Hoje · 14:00", "Novo"...).
class Etiqueta extends StatelessWidget {
  const Etiqueta({
    super.key,
    required this.texto,
    this.icone,
    required this.fundo,
    required this.cor,
    this.negrito = false,
  });

  final String texto;
  final IconData? icone;
  final Color fundo;
  final Color cor;
  final bool negrito;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: EdgeInsets.only(left: icone == null ? 8 : 6, right: 8),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 14, color: cor),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: AppText.s(
              12,
              peso: negrito ? FontWeight.w700 : FontWeight.w600,
              altura: 16,
              cor: cor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ícone quadrado de status (linhas da agenda semanal).
class IconeStatus extends StatelessWidget {
  const IconeStatus(this.status, {super.key});
  final StatusAtendimento status;

  @override
  Widget build(BuildContext context) {
    final e = estiloStatus(status);
    return Tooltip(
      message: status.rotulo,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: e.fundo,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(e.icone, size: 16, color: e.texto),
      ),
    );
  }
}

// ======================================================================
// Avatar e cabeçalho
// ======================================================================

/// Círculo com as iniciais do paciente.
class AvatarIniciais extends StatelessWidget {
  const AvatarIniciais({
    super.key,
    required this.iniciais,
    this.tamanho = 48,
    this.fundo = AppColors.primariaSuave,
    this.cor = AppColors.primariaEscura,
  });

  final String iniciais;
  final double tamanho;
  final Color fundo;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(color: fundo, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        iniciais,
        style: AppText.s(tamanho * 0.32, peso: FontWeight.w700, cor: cor),
      ),
    );
  }
}

/// Cabeçalho padrão das abas: sobretítulo verde, título e avatar do terapeuta.
class CabecalhoTela extends StatelessWidget {
  const CabecalhoTela({
    super.key,
    required this.sobretitulo,
    required this.titulo,
    this.subtitulo,
    required this.terapeuta,
    required this.aoSair,
  });

  final String sobretitulo;
  final String titulo;
  final String? subtitulo;
  final Terapeuta? terapeuta;
  final VoidCallback aoSair;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        crossAxisAlignment: subtitulo == null
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sobretitulo, style: AppText.sobretitulo()),
                const SizedBox(height: 4),
                Text(titulo, style: AppText.tituloTela()),
                if (subtitulo != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitulo!,
                    style: AppText.s(14, altura: 20, cor: AppColors.textoSuave),
                  ),
                ],
              ],
            ),
          ),
          // No computador o perfil já aparece na barra lateral.
          if (!ehTelaLarga(context)) ...[
            const SizedBox(width: 16),
            AvatarTerapeuta(terapeuta: terapeuta, aoSair: aoSair),
          ],
        ],
      ),
    );
  }
}

/// Avatar do terapeuta com abertura intuitiva de perfil ao tocar.
class AvatarTerapeuta extends StatelessWidget {
  const AvatarTerapeuta({
    super.key,
    this.terapeuta,
    required this.aoSair,
    this.tamanho = 48,
    this.abrirAoTocar = true,
  });

  final Terapeuta? terapeuta;
  final VoidCallback aoSair;
  final double tamanho;
  final bool abrirAoTocar;

  @override
  Widget build(BuildContext context) {
    if (terapeuta != null) {
      PerfilService.inicializar(terapeuta!.id);
    }
    final nome = terapeuta?.nome ?? '';
    final inicial = nome.isEmpty ? 'T' : nome[0].toUpperCase();

    Widget avatarWidget = ValueListenableBuilder<String?>(
      valueListenable: PerfilService.fotoNotifier,
      builder: (context, foto, _) {
        if (foto != null && foto.isNotEmpty) {
          if (foto.startsWith('data:image')) {
            try {
              final base64Part = foto.split(',').last;
              final bytes = base64Decode(base64Part);
              return ClipOval(
                child: Image.memory(
                  bytes,
                  width: tamanho,
                  height: tamanho,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _avatarCirculo(inicial),
                ),
              );
            } catch (_) {
              return _avatarCirculo(inicial);
            }
          }

          if (foto.startsWith('http://') || foto.startsWith('https://')) {
            return ClipOval(
              child: Image.network(
                foto,
                width: tamanho,
                height: tamanho,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarCirculo(inicial),
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
              width: tamanho,
              height: tamanho,
              decoration: BoxDecoration(
                color: corPreset,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: corPreset.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(iconePreset, color: Colors.white, size: tamanho * 0.5),
            );
          }
        }
        return _avatarCirculo(inicial);
      },
    );

    if (!abrirAoTocar || terapeuta == null) {
      return avatarWidget;
    }

    return Tooltip(
      message: 'Abrir perfil',
      child: InkWell(
        onTap: () => abrirPerfilTerapeuta(context, terapeuta: terapeuta!, aoSair: aoSair),
        customBorder: const CircleBorder(),
        child: avatarWidget,
      ),
    );
  }

  Widget _avatarCirculo(String inicial) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: AppColors.texto,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.texto.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        inicial,
        style: AppText.s(tamanho * 0.4, peso: FontWeight.w700, cor: Colors.white),
      ),
    );
  }
}

/// Título de seção ("Próximo atendimento") com ação opcional à direita.
class TituloSecao extends StatelessWidget {
  const TituloSecao(this.texto, {super.key, this.acao});
  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(child: Text(texto, style: AppText.tituloSecao())),
          ?acao,
        ],
      ),
    );
  }
}

// ======================================================================
// Botões
// ======================================================================

/// Botão principal verde (56px).
class BotaoPrimario extends StatelessWidget {
  const BotaoPrimario({
    super.key,
    required this.rotulo,
    this.icone,
    this.iconeDepois = false,
    required this.aoPressionar,
    this.carregando = false,
    this.fundo = AppColors.primaria,
    this.cor = AppColors.sobrePrimaria,
    this.sombra = true,
  });

  final String rotulo;
  final IconData? icone;
  final bool iconeDepois;
  final VoidCallback? aoPressionar;
  final bool carregando;
  final Color fundo;
  final Color cor;
  final bool sombra;

  @override
  Widget build(BuildContext context) {
    final iconeW = icone == null ? null : Icon(icone, size: 20, color: cor);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: sombra
            ? [
                BoxShadow(
                  color: AppColors.primariaForte.withValues(alpha: 0.7),
                  blurRadius: 20,
                  spreadRadius: -10,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: fundo,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: carregando ? null : aoPressionar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (carregando) ...[
                  Indicador(cor: cor),
                  const SizedBox(width: 8),
                ] else if (iconeW != null && !iconeDepois) ...[
                  iconeW,
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.s(15,
                        peso: FontWeight.w700, altura: 20, cor: cor),
                  ),
                ),
                if (!carregando && iconeW != null && iconeDepois) ...[
                  const SizedBox(width: 8),
                  iconeW,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão secundário com contorno (56px).
class BotaoSecundario extends StatelessWidget {
  const BotaoSecundario({
    super.key,
    required this.rotulo,
    required this.aoPressionar,
    this.escuro = false,
  });

  final String rotulo;
  final VoidCallback? aoPressionar;

  /// Versão para fundo escuro (card "Em andamento").
  final bool escuro;

  @override
  Widget build(BuildContext context) {
    final cor = escuro ? Colors.white : AppColors.texto;
    return SizedBox(
      height: 56,
      child: Material(
        color: escuro ? Colors.transparent : AppColors.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: escuro
                ? Colors.white.withValues(alpha: 0.45)
                : AppColors.contorno,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: aoPressionar,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.s(15, peso: FontWeight.w600, altura: 20, cor: cor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão de texto verde ("Ver agenda", "Esqueci minha senha"...).
class BotaoTexto extends StatelessWidget {
  const BotaoTexto({
    super.key,
    required this.rotulo,
    required this.aoPressionar,
    this.icone,
    this.iconeDepois = false,
    this.cor = AppColors.primariaForte,
  });

  final String rotulo;
  final VoidCallback? aoPressionar;
  final IconData? icone;
  final bool iconeDepois;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final ic = icone == null ? null : Icon(icone, size: 20, color: cor);
    return TextButton(
      onPressed: aoPressionar,
      style: TextButton.styleFrom(
        foregroundColor: cor,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        overlayColor: AppColors.primaria,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ic != null && !iconeDepois) ...[ic, const SizedBox(width: 8)],
          Text(rotulo,
              style: AppText.s(14, peso: FontWeight.w700, altura: 20, cor: cor)),
          if (ic != null && iconeDepois) ...[const SizedBox(width: 8), ic],
        ],
      ),
    );
  }
}

/// Botão redondo de ícone (48px).
class BotaoIcone extends StatelessWidget {
  const BotaoIcone({
    super.key,
    required this.icone,
    required this.aoPressionar,
    required this.dica,
    this.cor = AppColors.texto,
    this.contorno = false,
    this.tamanhoIcone = 24,
  });

  final IconData icone;
  final VoidCallback? aoPressionar;
  final String dica;
  final Color cor;
  final bool contorno;
  final double tamanhoIcone;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: aoPressionar,
      tooltip: dica,
      iconSize: tamanhoIcone,
      color: cor,
      disabledColor: cor.withValues(alpha: 0.3),
      style: IconButton.styleFrom(
        fixedSize: const Size(48, 48),
        backgroundColor: contorno ? AppColors.superficie : null,
        side: contorno ? const BorderSide(color: AppColors.borda) : null,
      ),
      icon: Icon(icone),
    );
  }
}

/// Botão flutuante estendido ("Novo paciente", "Adicionar horário").
class BotaoFlutuante extends StatelessWidget {
  const BotaoFlutuante({
    super.key,
    required this.rotulo,
    required this.icone,
    required this.aoPressionar,
  });

  final String rotulo;
  final IconData icone;
  final VoidCallback aoPressionar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.texto.withValues(alpha: 0.45),
            blurRadius: 20,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: AppColors.primaria,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: aoPressionar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, size: 24, color: AppColors.sobrePrimaria),
                const SizedBox(width: 8),
                Text(
                  rotulo,
                  style: AppText.s(15,
                      peso: FontWeight.w700,
                      altura: 20,
                      cor: AppColors.sobrePrimaria),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicador de carregamento circular pequeno (dentro de botões).
class Indicador extends StatelessWidget {
  const Indicador({super.key, this.cor = AppColors.sobrePrimaria});
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: cor,
        backgroundColor: cor.withValues(alpha: 0.28),
      ),
    );
  }
}

// ======================================================================
// Cards e estados
// ======================================================================

/// Card branco padrão (raio 24, borda clara).
class CardBranco extends StatelessWidget {
  const CardBranco({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.sombra = false,
    this.raio = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool sombra;
  final double raio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(raio),
        border: Border.all(color: AppColors.borda),
        boxShadow: sombra ? sombraCard() : null,
      ),
      child: child,
    );
  }
}

List<BoxShadow> sombraCard([double alpha = 0.25]) => [
      BoxShadow(
        color: AppColors.texto.withValues(alpha: alpha),
        blurRadius: 24,
        spreadRadius: -16,
        offset: const Offset(0, 8),
      ),
    ];

/// Card verde-claro de resumo (topo de Agenda e Disponibilidade).
class CardResumo extends StatelessWidget {
  const CardResumo({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primariaSuave,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(
            right: -64,
            bottom: -110,
            child: AnelEnso(tamanho: 200, espessura: 10, rotacao: 300),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha com ícone verde e texto (dentro dos cards de resumo).
class LinhaInfo extends StatelessWidget {
  const LinhaInfo({
    super.key,
    required this.icone,
    required this.texto,
    this.destaque = false,
  });

  final IconData icone;
  final String texto;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icone, size: 18, color: AppColors.primariaForte),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: AppText.s(
              14,
              altura: 20,
              peso: destaque ? FontWeight.w600 : FontWeight.w400,
              cor: destaque ? AppColors.texto : AppColors.textoSecundario,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pílula branca com contagem ("4 sessões").
class PilulaContagem extends StatelessWidget {
  const PilulaContagem(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        texto,
        style: AppText.s(13,
            peso: FontWeight.w700, altura: 16, cor: AppColors.primariaEscura),
      ),
    );
  }
}

/// Card de estado vazio com o anel ensō ("Dia livre por aqui").
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.texto,
    this.acao,
  });

  final IconData icone;
  final String titulo;
  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return CardBranco(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          SizedBox.square(
            dimension: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const AnelEnso(
                  tamanho: 120,
                  espessura: 9,
                  rotacao: -30,
                  intensidade: 1.6,
                ),
                Icon(icone, size: 40, color: AppColors.primariaForte),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(titulo,
              textAlign: TextAlign.center,
              style: AppText.s(20, peso: FontWeight.w700, altura: 28)),
          const SizedBox(height: 8),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: AppText.s(14, altura: 20, cor: AppColors.textoSuave),
          ),
          if (acao != null) ...[const SizedBox(height: 24), acao!],
        ],
      ),
    );
  }
}

// ======================================================================
// Aviso flutuante (snackbar do protótipo)
// ======================================================================

class Aviso {
  const Aviso({
    required this.texto,
    this.icone = Icons.check_circle_rounded,
    this.acao,
    this.aoAcionar,
  });

  final String texto;
  final IconData icone;
  final String? acao;
  final VoidCallback? aoAcionar;
}

class AvisoFlutuante extends StatelessWidget {
  const AvisoFlutuante({super.key, required this.aviso});
  final Aviso aviso;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        decoration: BoxDecoration(
          color: AppColors.texto,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.texto.withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(aviso.icone, size: 20, color: AppColors.verdeIconeSnack),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  aviso.texto,
                  style: AppText.s(14,
                      peso: FontWeight.w600, altura: 20, cor: Colors.white),
                ),
              ),
            ),
            if (aviso.acao != null)
              TextButton(
                onPressed: aviso.aoAcionar,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: AppColors.verdeClaroSnack,
                ),
                child: Text(
                  aviso.acao!,
                  style: AppText.s(14,
                      peso: FontWeight.w700, cor: AppColors.verdeClaroSnack),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Barra de navegação inferior
// ======================================================================

/// Abas do app: (ícone ativo, ícone inativo, rótulo).
const itensNavegacao = [
  (Icons.home_rounded, Icons.home_outlined, 'Início'),
  (Icons.calendar_month_rounded, Icons.calendar_month_outlined, 'Agenda'),
  (Icons.group_rounded, Icons.group_outlined, 'Pacientes'),
  (Icons.event_available_rounded, Icons.event_available_outlined,
      'Disponibilidade'),
];

/// Barra inferior (celular).
class BarraNavegacao extends StatelessWidget {
  const BarraNavegacao({
    super.key,
    required this.atual,
    required this.aoSelecionar,
  });

  final int atual;
  final ValueChanged<int> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: AppColors.borda)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              for (var i = 0; i < itensNavegacao.length; i++)
                Expanded(child: _item(i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i) {
    final (iconeAtivo, iconeInativo, rotulo) = itensNavegacao[i];
    final ativo = i == atual;
    final cor = ativo ? AppColors.texto : AppColors.textoSuave;
    return Semantics(
      selected: ativo,
      button: true,
      child: InkWell(
        onTap: () => aoSelecionar(i),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              height: 32,
              decoration: BoxDecoration(
                color: ativo ? AppColors.primariaSuave : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(ativo ? iconeAtivo : iconeInativo,
                  size: 24, color: cor),
            ),
            const SizedBox(height: 4),
            Text(
              rotulo,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: AppText.s(
                12,
                altura: 16,
                peso: ativo ? FontWeight.w700 : FontWeight.w500,
                cor: cor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra lateral (computador e tablet deitado).
class BarraLateral extends StatelessWidget {
  const BarraLateral({
    super.key,
    required this.atual,
    required this.aoSelecionar,
    required this.terapeuta,
    required this.aoSair,
  });

  final int atual;
  final ValueChanged<int> aoSelecionar;
  final Terapeuta terapeuta;
  final VoidCallback aoSair;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      decoration: const BoxDecoration(
        color: AppColors.superficie,
        border: Border(right: BorderSide(color: AppColors.borda)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/images/rokuzen_logo.png',
                    height: 44,
                    semanticLabel: 'Rokuzen',
                  ),
                ),
              ),
              const SizedBox(height: 32),
              for (var i = 0; i < itensNavegacao.length; i++) ...[
                if (i > 0) const SizedBox(height: 4),
                _item(i),
              ],
              const Spacer(),
              const Divider(height: 1, color: AppColors.divisor),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => abrirPerfilTerapeuta(
                  context,
                  terapeuta: terapeuta,
                  aoSair: aoSair,
                ),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    children: [
                      AvatarTerapeuta(
                        terapeuta: terapeuta,
                        aoSair: aoSair,
                        abrirAoTocar: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              terapeuta.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.s(15,
                                  peso: FontWeight.w700, altura: 20),
                            ),
                            Text(
                              'Terapeuta · ${terapeuta.unidade}',
                              overflow: TextOverflow.ellipsis,
                              style: AppText.s(12,
                                  altura: 16, cor: AppColors.textoSuave),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textoSuave,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i) {
    final (iconeAtivo, iconeInativo, rotulo) = itensNavegacao[i];
    final ativo = i == atual;
    final cor = ativo ? AppColors.texto : AppColors.textoSuave;
    return Semantics(
      selected: ativo,
      button: true,
      child: Material(
        color: ativo ? AppColors.primariaSuave : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => aoSelecionar(i),
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(ativo ? iconeAtivo : iconeInativo, size: 24, color: cor),
                  const SizedBox(width: 16),
                  Text(
                    rotulo,
                    style: AppText.s(15,
                        altura: 20,
                        peso: ativo ? FontWeight.w700 : FontWeight.w500,
                        cor: cor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
