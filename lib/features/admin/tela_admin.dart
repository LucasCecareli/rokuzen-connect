import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/services/admin_api_service.dart';
import '../../widgets/componentes.dart';
import '../../widgets/responsivo.dart';
import 'aba_agendamentos.dart';
import 'aba_pacientes_admin.dart';
import 'aba_terapeutas.dart';

/// Área exclusiva do administrador (login admrokuzen): agendamentos,
/// terapeutas e pacientes. Separada das telas do terapeuta.
class TelaAdmin extends StatefulWidget {
  const TelaAdmin({super.key, required this.aoSair});
  final VoidCallback aoSair;

  @override
  State<TelaAdmin> createState() => _TelaAdminState();
}

const _itensAdmin = [
  (Icons.event_note_rounded, Icons.event_note_outlined, 'Agendamentos'),
  (Icons.spa_rounded, Icons.spa_outlined, 'Terapeutas'),
  (Icons.group_rounded, Icons.group_outlined, 'Pacientes'),
];

class _TelaAdminState extends State<TelaAdmin> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) {
    final largo = ehTelaLarga(context);
    final abas = [
      AbaAgendamentos(aoSair: widget.aoSair),
      AbaTerapeutas(aoSair: widget.aoSair),
      AbaPacientesAdmin(aoSair: widget.aoSair),
    ];

    return Scaffold(
      backgroundColor: AppColors.fundo,
      body: Row(
        children: [
          if (largo)
            _BarraLateralAdmin(
              atual: _aba,
              aoSelecionar: (i) => setState(() => _aba = i),
              aoSair: widget.aoSair,
            ),
          Expanded(
            key: const ValueKey('conteudo-admin'),
            child: IndexedStack(index: _aba, children: abas),
          ),
        ],
      ),
      bottomNavigationBar: largo
          ? null
          : _BarraInferiorAdmin(
              atual: _aba,
              aoSelecionar: (i) => setState(() => _aba = i),
            ),
    );
  }
}

/// Barra lateral escura do administrador (computador).
class _BarraLateralAdmin extends StatelessWidget {
  const _BarraLateralAdmin({
    required this.atual,
    required this.aoSelecionar,
    required this.aoSair,
  });

  final int atual;
  final ValueChanged<int> aoSelecionar;
  final VoidCallback aoSair;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      color: AppColors.texto,
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.superficie,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  'assets/images/rokuzen_logo.png',
                  height: 36,
                  semanticLabel: 'Rokuzen',
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'ADMINISTRAÇÃO',
                  style: AppText.sobretitulo(AppColors.verdeClaroSnack),
                ),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < _itensAdmin.length; i++) ...[
                if (i > 0) const SizedBox(height: 4),
                _item(i),
              ],
              const Spacer(),
              Divider(
                  height: 1,
                  color: AppColors.textoSobreEscuro.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const AvatarIniciais(
                    iniciais: 'AD',
                    tamanho: 44,
                    fundo: AppColors.primaria,
                    cor: AppColors.sobrePrimaria,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SessaoAdmin.nome ?? 'Administrador',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.s(15,
                              peso: FontWeight.w700,
                              altura: 20,
                              cor: Colors.white),
                        ),
                        Text(
                          'Acesso administrativo',
                          style: AppText.s(12,
                              altura: 16, cor: AppColors.textoSobreEscuro),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: aoSair,
                icon: const Icon(Icons.logout_rounded,
                    size: 18, color: AppColors.textoSobreEscuro2),
                label: Text('Sair',
                    style: AppText.s(14,
                        peso: FontWeight.w600,
                        cor: AppColors.textoSobreEscuro2)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  side: BorderSide(
                      color: AppColors.textoSobreEscuro.withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i) {
    final (iconeAtivo, iconeInativo, rotulo) = _itensAdmin[i];
    final ativo = i == atual;
    return Semantics(
      selected: ativo,
      button: true,
      child: Material(
        color: ativo
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => aoSelecionar(i),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(ativo ? iconeAtivo : iconeInativo,
                    size: 22,
                    color: ativo
                        ? AppColors.verdeClaroSnack
                        : AppColors.textoSobreEscuro),
                const SizedBox(width: 14),
                Text(
                  rotulo,
                  style: AppText.s(15,
                      peso: ativo ? FontWeight.w700 : FontWeight.w500,
                      cor: ativo ? Colors.white : AppColors.textoSobreEscuro),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra inferior do administrador (celular).
class _BarraInferiorAdmin extends StatelessWidget {
  const _BarraInferiorAdmin({required this.atual, required this.aoSelecionar});
  final int atual;
  final ValueChanged<int> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.texto,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < _itensAdmin.length; i++)
                Expanded(child: _item(i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i) {
    final (iconeAtivo, iconeInativo, rotulo) = _itensAdmin[i];
    final ativo = i == atual;
    final cor = ativo ? AppColors.verdeClaroSnack : AppColors.textoSobreEscuro;
    return Semantics(
      selected: ativo,
      button: true,
      child: InkWell(
        onTap: () => aoSelecionar(i),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ativo ? iconeAtivo : iconeInativo, size: 24, color: cor),
            const SizedBox(height: 4),
            Text(
              rotulo,
              style: AppText.s(12,
                  altura: 16,
                  peso: ativo ? FontWeight.w700 : FontWeight.w500,
                  cor: ativo ? Colors.white : cor),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Peças compartilhadas pelas abas do administrador
// =====================================================================

/// Cabeçalho das abas do administrador. No celular mostra o botão "Sair".
class CabecalhoAdmin extends StatelessWidget {
  const CabecalhoAdmin({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.aoSair,
  });

  final String titulo;
  final String subtitulo;
  final VoidCallback aoSair;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ADMINISTRAÇÃO', style: AppText.sobretitulo()),
                const SizedBox(height: 4),
                Text(titulo, style: AppText.tituloTela()),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: AppText.s(14, altura: 20, cor: AppColors.textoSuave),
                ),
              ],
            ),
          ),
          if (!ehTelaLarga(context))
            BotaoIcone(
              icone: Icons.logout_rounded,
              dica: 'Sair',
              cor: AppColors.textoSuave,
              aoPressionar: aoSair,
            ),
        ],
      ),
    );
  }
}

/// Mensagem rápida na parte de baixo da tela.
void avisarAdmin(BuildContext context, String texto, {bool erro = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: erro ? AppColors.erroTexto : null,
    ));
}

/// Pop-up de confirmação (excluir, cancelar...). Devolve true ao confirmar.
Future<bool> confirmarAdmin(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String rotuloConfirmar,
  IconData icone = Icons.warning_amber_rounded,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.veu,
    builder: (contexto) => Dialog(
      backgroundColor: AppColors.superficie,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.ausenteFundo,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icone, color: AppColors.ausente, size: 28),
                ),
              ),
              const SizedBox(height: 16),
              Text(titulo,
                  textAlign: TextAlign.center,
                  style: AppText.s(20, peso: FontWeight.w700, altura: 28)),
              const SizedBox(height: 8),
              Text(texto,
                  textAlign: TextAlign.center,
                  style: AppText.s(15, altura: 22, cor: AppColors.textoSuave)),
              const SizedBox(height: 24),
              BotaoPrimario(
                rotulo: rotuloConfirmar,
                fundo: AppColors.ausente,
                cor: Colors.white,
                sombra: false,
                aoPressionar: () => Navigator.of(contexto).pop(true),
              ),
              const SizedBox(height: 12),
              BotaoSecundario(
                rotulo: 'Voltar',
                aoPressionar: () => Navigator.of(contexto).pop(false),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return ok ?? false;
}

/// Opção selecionável (unidade, serviço, duração, horário...).
class OpcaoAdmin extends StatelessWidget {
  const OpcaoAdmin({
    super.key,
    required this.rotulo,
    required this.selecionada,
    required this.aoTocar,
    this.detalhe,
    this.habilitada = true,
  });

  final String rotulo;
  final String? detalhe;
  final bool selecionada;
  final bool habilitada;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cor = !habilitada
        ? AppColors.placeholder
        : selecionada
            ? AppColors.primariaEscura
            : AppColors.texto;
    return Semantics(
      button: true,
      selected: selecionada,
      enabled: habilitada,
      child: Opacity(
        opacity: habilitada ? 1 : 0.5,
        child: Material(
          color: selecionada ? AppColors.primariaSuave : AppColors.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selecionada ? AppColors.primariaForte : AppColors.borda,
              width: selecionada ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: habilitada ? aoTocar : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotulo,
                    style: AppText.s(14,
                        peso: selecionada ? FontWeight.w700 : FontWeight.w600,
                        altura: 20,
                        cor: cor,
                        numerosTabulares: true),
                  ),
                  if (detalhe != null)
                    Text(
                      detalhe!,
                      style: AppText.s(12,
                          altura: 16, cor: AppColors.textoSuave),
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

/// Faixa de erro com "Tentar novamente".
class ErroAdmin extends StatelessWidget {
  const ErroAdmin({super.key, required this.mensagem, required this.aoTentar});
  final String mensagem;
  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.erroFundo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.erro, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(mensagem,
                style: AppText.s(14, altura: 20, cor: AppColors.erroTexto)),
          ),
          BotaoTexto(
            rotulo: 'Tentar novamente',
            cor: AppColors.erroTexto,
            aoPressionar: aoTentar,
          ),
        ],
      ),
    );
  }
}
