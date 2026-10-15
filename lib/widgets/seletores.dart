import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/formatadores.dart';
import 'componentes.dart';
import 'decoracao.dart';

/// Moldura comum dos diálogos de seleção (cantos de 28px).
class _MolduraDialogo extends StatelessWidget {
  const _MolduraDialogo({required this.rotulo, required this.children});
  final String rotulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.superficie,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Semantics(
          label: rotulo,
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

Widget _rodapeDialogo(BuildContext context, {VoidCallback? aoConfirmar}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        BotaoTexto(
          rotulo: 'Cancelar',
          aoPressionar: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8),
        Opacity(
          opacity: aoConfirmar == null ? 0.4 : 1,
          child: BotaoTexto(rotulo: 'OK', aoPressionar: aoConfirmar),
        ),
      ],
    ),
  );
}

// ======================================================================
// Seletor de data
// ======================================================================

/// Abre o calendário do app e devolve a data escolhida.
///
/// [comAnos] habilita a grade de anos (data de nascimento).
Future<DateTime?> escolherData(
  BuildContext context, {
  required String rotulo,
  DateTime? inicial,
  required DateTime hoje,
  DateTime? minima,
  DateTime? maxima,
  bool comAnos = false,
  bool mostrarAno = false,
}) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: AppColors.veu,
    builder: (_) => _SeletorData(
      rotulo: rotulo,
      inicial: inicial,
      hoje: soData(hoje),
      minima: minima == null ? null : soData(minima),
      maxima: maxima == null ? null : soData(maxima),
      comAnos: comAnos,
      mostrarAno: mostrarAno,
    ),
  );
}

class _SeletorData extends StatefulWidget {
  const _SeletorData({
    required this.rotulo,
    required this.inicial,
    required this.hoje,
    required this.minima,
    required this.maxima,
    required this.comAnos,
    required this.mostrarAno,
  });

  final String rotulo;
  final DateTime? inicial;
  final DateTime hoje;
  final DateTime? minima;
  final DateTime? maxima;
  final bool comAnos;
  final bool mostrarAno;

  @override
  State<_SeletorData> createState() => _SeletorDataState();
}

class _SeletorDataState extends State<_SeletorData> {
  late DateTime? _selecionada = widget.inicial;
  late int _ano = (widget.inicial ?? DateTime(1990)).year;
  late int _mes = (widget.inicial ?? DateTime(1990)).month;
  // Sem data inicial na data de nascimento: começa pela grade de anos.
  late bool _anos = widget.comAnos && widget.inicial == null;
  final _rolagemAnos = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.inicial == null && !widget.comAnos) {
      _ano = widget.hoje.year;
      _mes = widget.hoje.month;
    }
    if (_anos) _rolarAnos();
  }

  @override
  void dispose() {
    _rolagemAnos.dispose();
    super.dispose();
  }

  void _rolarAnos() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_rolagemAnos.hasClients) return;
      final linha = (widget.hoje.year - _ano) ~/ 3;
      _rolagemAnos.jumpTo((linha * 56.0 - 112).clamp(0.0, _rolagemAnos.position.maxScrollExtent).toDouble());
    });
  }

  bool get _podeVoltar {
    final min = widget.minima;
    if (min == null) return true;
    return _ano > min.year || (_ano == min.year && _mes > min.month);
  }

  bool get _podeAvancar {
    final max = widget.maxima;
    if (max == null) return true;
    return _ano < max.year || (_ano == max.year && _mes < max.month);
  }

  void _mudarMes(int delta) {
    setState(() {
      final d = DateTime(_ano, _mes + delta);
      _ano = d.year;
      _mes = d.month;
    });
  }

  String get _titulo {
    final d = _selecionada;
    if (d == null) return 'Selecione a data';
    final base = '${diaSemanaCurto(d)}, ${d.day} de ${mesesAbrev[d.month - 1]}.';
    return widget.mostrarAno ? '$base de ${d.year}' : base;
  }

  @override
  Widget build(BuildContext context) {
    final mesTexto = '${capitalizar(meses[_mes - 1])} de $_ano';
    return _MolduraDialogo(
      rotulo: widget.rotulo,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borda)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.rotulo,
                  style: AppText.s(12,
                      peso: FontWeight.w600,
                      altura: 16,
                      cor: AppColors.textoSuave)),
              const SizedBox(height: 24),
              Text(
                _titulo,
                style: AppText.s(28,
                    peso: FontWeight.w700,
                    altura: 36,
                    espacamento: -0.4,
                    cor: _selecionada == null
                        ? AppColors.textoSuave
                        : AppColors.texto),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
          child: Row(
            children: [
              if (widget.comAnos)
                TextButton(
                  onPressed: () {
                    setState(() => _anos = !_anos);
                    if (_anos) _rolarAnos();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.texto,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Row(
                    children: [
                      Text(mesTexto,
                          style: AppText.s(14, peso: FontWeight.w700, altura: 20)),
                      Icon(
                        _anos
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        size: 20,
                        color: AppColors.textoSuave,
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(mesTexto,
                      style: AppText.s(14, peso: FontWeight.w700, altura: 20)),
                ),
              const Spacer(),
              if (!_anos) ...[
                BotaoIcone(
                  icone: Icons.chevron_left_rounded,
                  dica: 'Mês anterior',
                  aoPressionar: _podeVoltar ? () => _mudarMes(-1) : null,
                ),
                BotaoIcone(
                  icone: Icons.chevron_right_rounded,
                  dica: 'Próximo mês',
                  aoPressionar: _podeAvancar ? () => _mudarMes(1) : null,
                ),
              ],
            ],
          ),
        ),
        if (_anos) _gradeAnos() else _gradeDias(),
        _rodapeDialogo(
          context,
          aoConfirmar: _selecionada == null
              ? null
              : () => Navigator.of(context).pop(_selecionada),
        ),
      ],
    );
  }

  Widget _gradeDias() {
    final primeiro = DateTime(_ano, _mes, 1);
    final deslocamento = primeiro.weekday % 7; // domingo = 0
    final diasNoMes = DateTime(_ano, _mes + 1, 0).day;
    final celulas = <Widget>[
      for (var i = 0; i < deslocamento; i++) const SizedBox(height: 48),
      for (var d = 1; d <= diasNoMes; d++) _celulaDia(DateTime(_ano, _mes, d)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              for (final l in iniciaisSemanaDomingo)
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: Text(l,
                          style: AppText.s(13,
                              peso: FontWeight.w600,
                              cor: AppColors.textoSuave)),
                    ),
                  ),
                ),
            ],
          ),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 48,
            ),
            children: celulas,
          ),
        ],
      ),
    );
  }

  Widget _celulaDia(DateTime dia) {
    final selecionado = mesmoDia(dia, _selecionada);
    final hoje = mesmoDia(dia, widget.hoje);
    final desabilitado = (widget.minima != null && dia.isBefore(widget.minima!)) ||
        (widget.maxima != null && dia.isAfter(widget.maxima!));
    return _CirculoDia(
      numero: '${dia.day}',
      selecionado: selecionado,
      hoje: hoje,
      desabilitado: desabilitado,
      rotulo: '${dia.day} de ${meses[dia.month - 1]} de ${dia.year}',
      aoTocar: () => setState(() => _selecionada = dia),
    );
  }

  Widget _gradeAnos() {
    final anoMax = widget.maxima?.year ?? widget.hoje.year + 5;
    final anoMin = widget.minima?.year ?? 1920;
    final anos = [for (var a = anoMax; a >= anoMin; a--) a];
    return SizedBox(
      height: 336,
      child: GridView.builder(
        controller: _rolagemAnos,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisExtent: 56,
        ),
        itemCount: anos.length,
        itemBuilder: (context, i) {
          final a = anos[i];
          final sel = a == _ano;
          final atual = a == widget.hoje.year;
          return Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() {
                _ano = a;
                if (widget.maxima != null &&
                    a == widget.maxima!.year &&
                    _mes > widget.maxima!.month) {
                  _mes = widget.maxima!.month;
                }
                _anos = false;
              }),
              child: Container(
                width: 72,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? AppColors.primaria : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: atual && !sel
                      ? Border.all(color: AppColors.primariaForte)
                      : null,
                ),
                child: Text(
                  '$a',
                  style: AppText.s(15,
                      peso: sel ? FontWeight.w700 : FontWeight.w500,
                      cor: sel ? AppColors.sobrePrimaria : AppColors.texto),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Dia de calendário: círculo de 40px dentro de uma área de 48px.
class _CirculoDia extends StatelessWidget {
  const _CirculoDia({
    required this.numero,
    required this.selecionado,
    required this.hoje,
    required this.desabilitado,
    required this.rotulo,
    required this.aoTocar,
  });

  final String numero;
  final bool selecionado;
  final bool hoje;
  final bool desabilitado;
  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cor = selecionado
        ? AppColors.sobrePrimaria
        : desabilitado
            ? AppColors.alca
            : hoje
                ? AppColors.primariaForte
                : AppColors.texto;
    return Semantics(
      button: true,
      selected: selecionado,
      label: rotulo,
      child: InkWell(
        onTap: desabilitado ? null : aoTocar,
        customBorder: const CircleBorder(),
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selecionado ? AppColors.primaria : Colors.transparent,
              shape: BoxShape.circle,
              border: hoje && !selecionado
                  ? Border.all(color: AppColors.primariaForte)
                  : null,
            ),
            child: Text(
              numero,
              style: AppText.s(14,
                  altura: 20,
                  peso: selecionado || hoje ? FontWeight.w700 : FontWeight.w500,
                  cor: cor),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// Seletor de horário (intervalos de 30 minutos)
// ======================================================================

/// Horários oferecidos: das 06:00 às 23:30, de 30 em 30 minutos.
final horariosDisponiveis = [for (var i = 0; i < 36; i++) 360 + i * 30];

/// Abre a grade de horários e devolve o horário escolhido (minutos).
Future<int?> escolherHorario(
  BuildContext context, {
  required String rotulo,
  required String diaTexto,
  int? inicial,
  required bool Function(int minutos) desabilitado,
  required bool Function(int minutos) conflito,
}) {
  return showDialog<int>(
    context: context,
    barrierColor: AppColors.veu,
    builder: (_) => _SeletorHorario(
      rotulo: rotulo,
      diaTexto: diaTexto,
      inicial: inicial,
      desabilitado: desabilitado,
      conflito: conflito,
    ),
  );
}

class _SeletorHorario extends StatefulWidget {
  const _SeletorHorario({
    required this.rotulo,
    required this.diaTexto,
    required this.inicial,
    required this.desabilitado,
    required this.conflito,
  });

  final String rotulo;
  final String diaTexto;
  final int? inicial;
  final bool Function(int) desabilitado;
  final bool Function(int) conflito;

  @override
  State<_SeletorHorario> createState() => _SeletorHorarioState();
}

class _SeletorHorarioState extends State<_SeletorHorario> {
  late int? _valor = widget.inicial;
  final _rolagem = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_rolagem.hasClients) return;
      final alvo = widget.inicial ?? 17 * 60;
      final i = horariosDisponiveis.indexOf(alvo).clamp(0, horariosDisponiveis.length - 1);
      _rolagem.jumpTo(((i ~/ 4) * 48.0 - 96)
          .clamp(0.0, _rolagem.position.maxScrollExtent)
          .toDouble());
    });
  }

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _MolduraDialogo(
      rotulo: widget.rotulo,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borda)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.rotulo,
                  style: AppText.s(12,
                      peso: FontWeight.w600,
                      altura: 16,
                      cor: AppColors.textoSuave)),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      _valor == null ? '--:--' : horaDeMinutos(_valor!),
                      style: AppText.s(40,
                          peso: FontWeight.w700,
                          altura: 48,
                          espacamento: -0.6,
                          numerosTabulares: true,
                          cor: _valor == null
                              ? AppColors.textoSuave
                              : AppColors.texto),
                    ),
                  ),
                  Text(widget.diaTexto,
                      style: AppText.s(13,
                          altura: 18, cor: AppColors.textoSuave)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: FundoListrado(
                      raio: 4,
                      larguraListra: 3,
                      child: SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Coincide com expediente ou horário já cadastrado',
                      style: AppText.s(12,
                          altura: 16, cor: AppColors.textoSecundario),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 288,
          child: GridView.builder(
            controller: _rolagem,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisExtent: 48,
            ),
            itemCount: horariosDisponiveis.length,
            itemBuilder: (context, i) => _celula(horariosDisponiveis[i]),
          ),
        ),
        const Divider(height: 1, color: AppColors.borda),
        _rodapeDialogo(
          context,
          aoConfirmar:
              _valor == null ? null : () => Navigator.of(context).pop(_valor),
        ),
      ],
    );
  }

  Widget _celula(int t) {
    final sel = _valor == t;
    final dis = widget.desabilitado(t);
    final conf = !dis && widget.conflito(t);
    final rotulo = horaDeMinutos(t);
    final texto = Text(
      rotulo,
      style: AppText.s(14,
          altura: 20,
          peso: sel ? FontWeight.w700 : FontWeight.w500,
          numerosTabulares: true,
          cor: sel
              ? AppColors.sobrePrimaria
              : dis
                  ? AppColors.alca
                  : conf
                      ? AppColors.textoSecundario
                      : AppColors.texto),
    );
    Widget caixa;
    if (conf && !sel) {
      caixa = FundoListrado(
        raio: 8,
        larguraListra: 6,
        child: SizedBox(height: 40, child: Center(child: texto)),
      );
    } else {
      caixa = Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? AppColors.primaria : AppColors.superficie,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: sel ? AppColors.primaria : AppColors.borda),
        ),
        child: texto,
      );
    }
    return Semantics(
      button: true,
      selected: sel,
      label: conf
          ? '$rotulo — coincide com expediente ou horário cadastrado'
          : rotulo,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: dis ? null : () => setState(() => _valor = t),
          child: Center(child: caixa),
        ),
      ),
    );
  }
}
