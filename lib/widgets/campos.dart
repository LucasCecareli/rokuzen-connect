import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';

/// Cores de um campo conforme foco e erro (iguais ao protótipo).
class EstiloCampo {
  EstiloCampo({required bool foco, required bool erro})
      : borda = erro
            ? AppColors.erro
            : foco
                ? AppColors.primariaForte
                : AppColors.contorno,
        fundo = foco ? AppColors.superficie : AppColors.fundoCampo,
        rotulo = erro
            ? AppColors.erro
            : foco
                ? AppColors.primariaForte
                : AppColors.texto,
        icone = erro
            ? AppColors.erro
            : foco
                ? AppColors.primariaForte
                : AppColors.textoSuave,
        sombra = [
          if (erro || foco)
            BoxShadow(
              color: erro
                  ? AppColors.erro.withValues(alpha: 0.14)
                  : AppColors.primaria.withValues(alpha: 0.26),
              spreadRadius: foco ? 4 : 0,
            ),
        ],
        larguraBorda = (erro || foco) ? 2.0 : 1.0;

  final Color borda;
  final Color fundo;
  final Color rotulo;
  final Color icone;
  final List<BoxShadow> sombra;
  final double larguraBorda;

  BoxDecoration decoracao({Color? fundoFixo}) => BoxDecoration(
        color: fundoFixo ?? fundo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borda, width: larguraBorda),
        boxShadow: sombra,
      );
}

/// Rótulo de campo com indicação opcional "Obrigatório"/"Opcional".
class RotuloCampo extends StatelessWidget {
  const RotuloCampo(this.texto, {super.key, this.cor, this.indicacao});
  final String texto;
  final Color? cor;
  final String? indicacao;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            texto,
            style: AppText.s(14,
                peso: FontWeight.w600, altura: 20, cor: cor ?? AppColors.texto),
          ),
        ),
        if (indicacao != null)
          Text(
            indicacao!,
            style: AppText.s(
              12,
              altura: 16,
              peso: indicacao == 'Obrigatório'
                  ? FontWeight.w600
                  : FontWeight.w500,
              cor: AppColors.textoSuave,
            ),
          ),
      ],
    );
  }
}

/// Mensagem de erro abaixo do campo.
class ErroCampo extends StatelessWidget {
  const ErroCampo(this.texto, {super.key, this.comIcone = true});
  final String texto;
  final bool comIcone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comIcone) ...[
            const Icon(Icons.error_rounded, size: 16, color: AppColors.erro),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              texto,
              style: AppText.s(12,
                  altura: 16,
                  peso: comIcone ? FontWeight.w600 : FontWeight.w400,
                  cor: AppColors.erro),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de texto no estilo do protótipo: rótulo, caixa de 56px com ícone e
/// mensagem de erro.
class CampoTexto extends StatefulWidget {
  const CampoTexto({
    super.key,
    required this.rotulo,
    required this.controller,
    required this.icone,
    this.dica,
    this.erro,
    this.indicacao,
    this.teclado,
    this.formatadores,
    this.ocultar = false,
    this.sufixo,
    this.habilitado = true,
    this.aoMudar,
    this.acaoTeclado,
    this.aoEnviar,
    this.autofill,
    this.erroComIcone = true,
    this.focusNode,
  });

  final String rotulo;
  final TextEditingController controller;
  final IconData icone;
  final String? dica;
  final String? erro;
  final String? indicacao;
  final TextInputType? teclado;
  final List<TextInputFormatter>? formatadores;
  final bool ocultar;
  final Widget? sufixo;
  final bool habilitado;
  final ValueChanged<String>? aoMudar;
  final TextInputAction? acaoTeclado;
  final ValueChanged<String>? aoEnviar;
  final Iterable<String>? autofill;
  final bool erroComIcone;
  final FocusNode? focusNode;

  @override
  State<CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  FocusNode? _proprio;
  FocusNode get _foco => widget.focusNode ?? (_proprio ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _foco.addListener(_atualizar);
  }

  @override
  void dispose() {
    _foco.removeListener(_atualizar);
    _proprio?.dispose();
    super.dispose();
  }

  void _atualizar() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // `erro` vazio ("" ou " ") só pinta o campo de vermelho, sem mensagem.
    final temErro = widget.erro != null;
    final mensagem = widget.erro?.trim() ?? '';
    final e = EstiloCampo(foco: _foco.hasFocus, erro: temErro);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RotuloCampo(widget.rotulo, cor: e.rotulo, indicacao: widget.indicacao),
        const SizedBox(height: 8),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: widget.habilitado ? 1 : 0.6,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 56,
            padding: EdgeInsets.only(left: 16, right: widget.sufixo == null ? 16 : 4),
            decoration: e.decoracao(),
            child: Row(
              children: [
                Icon(widget.icone, size: 22, color: e.icone),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _foco,
                    enabled: widget.habilitado,
                    obscureText: widget.ocultar,
                    keyboardType: widget.teclado,
                    inputFormatters: widget.formatadores,
                    textInputAction: widget.acaoTeclado,
                    onChanged: widget.aoMudar,
                    onSubmitted: widget.aoEnviar,
                    autofillHints: widget.autofill,
                    style: AppText.s(16, peso: FontWeight.w500, altura: 24),
                    decoration: InputDecoration.collapsed(
                      hintText: widget.dica,
                      hintStyle: AppText.s(16,
                          peso: FontWeight.w500,
                          altura: 24,
                          cor: AppColors.placeholder),
                    ),
                  ),
                ),
                if (widget.sufixo != null) widget.sufixo!,
              ],
            ),
          ),
        ),
        if (mensagem.isNotEmpty) ...[
          const SizedBox(height: 8),
          ErroCampo(mensagem, comIcone: widget.erroComIcone),
        ],
      ],
    );
  }
}

/// Campo que abre um seletor ao ser tocado (data, horário).
class CampoSeletor extends StatelessWidget {
  const CampoSeletor({
    super.key,
    required this.icone,
    required this.valor,
    required this.aoTocar,
    this.vazio = false,
    this.iconeFinal,
    this.foco = false,
    this.erro = false,
    this.habilitado = true,
    this.fundoFixo,
    this.negrito = false,
    this.rotuloAcessivel,
  });

  final IconData icone;
  final String valor;
  final VoidCallback aoTocar;
  final bool vazio;
  final IconData? iconeFinal;
  final bool foco;
  final bool erro;
  final bool habilitado;
  final Color? fundoFixo;
  final bool negrito;
  final String? rotuloAcessivel;

  @override
  Widget build(BuildContext context) {
    final e = EstiloCampo(foco: foco, erro: erro);
    return Semantics(
      button: true,
      label: rotuloAcessivel,
      child: Opacity(
        opacity: habilitado ? 1 : 0.6,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: habilitado ? aoTocar : null,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 56,
              padding: EdgeInsets.only(left: 16, right: iconeFinal == null ? 16 : 4),
              decoration: e.decoracao(fundoFixo: fundoFixo),
              child: Row(
                children: [
                  Icon(icone, size: 22, color: e.icone),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      valor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.s(
                        16,
                        altura: 24,
                        peso: negrito ? FontWeight.w600 : FontWeight.w500,
                        cor: vazio ? AppColors.placeholder : AppColors.texto,
                        numerosTabulares: true,
                      ),
                    ),
                  ),
                  if (iconeFinal != null)
                    SizedBox.square(
                      dimension: 48,
                      child: Icon(iconeFinal,
                          size: 22, color: AppColors.primariaForte),
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

/// Interruptor no estilo Material 3 do protótipo (trilho verde com ✓).
class Interruptor extends StatelessWidget {
  const Interruptor({super.key, required this.valor, required this.aoMudar});
  final bool valor;
  final ValueChanged<bool>? aoMudar;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: valor,
      onChanged: aoMudar,
      thumbIcon: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? const Icon(Icons.check_rounded, color: AppColors.primariaEscura)
            : null,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.contorno,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primariaForte
            : const Color(0xFFF2EEE9),
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primariaForte
            : AppColors.contorno,
      ),
    );
  }
}
