import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/formatadores.dart';
import '../../data/models/modelos.dart';
import '../../data/repositorio.dart';
import '../../widgets/campos.dart';
import '../../widgets/componentes.dart';
import '../../widgets/folhas.dart';
import '../../widgets/seletores.dart';

/// Resultado do formulário, para a tela mostrar o aviso certo.
class ResultadoDisponibilidade {
  const ResultadoDisponibilidade({
    required this.mensagem,
    required this.data,
    this.removida,
  });

  final String mensagem;

  /// Dia a selecionar no calendário depois de salvar.
  final DateTime data;

  /// Preenchido quando o horário foi excluído (permite "Desfazer").
  final Disponibilidade? removida;
}

/// Abre o formulário para adicionar (ou editar, se [existente] vier
/// preenchido) um horário de atendimento particular.
///
/// As alterações ficam só na memória do aparelho por enquanto.
Future<ResultadoDisponibilidade?> abrirFormularioDisponibilidade(
  BuildContext context, {
  required Terapeuta terapeuta,
  required DateTime data,
  required DateTime agora,
  required List<Disponibilidade> cadastradas,
  Disponibilidade? existente,
}) {
  return abrirFolha<ResultadoDisponibilidade>(
    context,
    builder: (_) => _FolhaDisponibilidade(
      terapeuta: terapeuta,
      dataInicial: soData(data),
      agora: agora,
      cadastradas: cadastradas,
      existente: existente,
    ),
  );
}

class _FolhaDisponibilidade extends StatefulWidget {
  const _FolhaDisponibilidade({
    required this.terapeuta,
    required this.dataInicial,
    required this.agora,
    required this.cadastradas,
    this.existente,
  });

  final Terapeuta terapeuta;
  final DateTime dataInicial;
  final DateTime agora;
  final List<Disponibilidade> cadastradas;
  final Disponibilidade? existente;

  @override
  State<_FolhaDisponibilidade> createState() => _FolhaDisponibilidadeState();
}

enum _Alvo { data, inicio, fim, termino }

class _FolhaDisponibilidadeState extends State<_FolhaDisponibilidade> {
  late DateTime _data = widget.dataInicial;
  late int? _inicio = widget.existente?.inicio;
  late int? _fim = widget.existente?.fim;
  bool _repetir = false;
  // Dias da semana no padrão do calendário: 0 = domingo ... 6 = sábado.
  late Set<int> _dias = {widget.dataInicial.weekday % 7};
  late DateTime _termino = somarDias(widget.dataInicial, 28);
  String? _erro;
  bool _salvando = false;
  _Alvo? _alvoAberto;

  bool get _editando => widget.existente != null;
  DateTime get _hoje => soData(widget.agora);

  static bool _sobrepoe(int a1, int a2, int b1, int b2) => a1 < b2 && b1 < a2;

  List<Disponibilidade> _doDia(DateTime dia) => widget.cadastradas
      .where((d) => mesmoDia(d.data, dia) && d.id != widget.existente?.id)
      .toList();

  List<DateTime> _ocorrencias() {
    if (!_repetir) return [_data];
    final lista = <DateTime>[];
    for (var d = _data; !d.isAfter(_termino); d = somarDias(d, 1)) {
      if (_dias.contains(d.weekday % 7)) lista.add(d);
    }
    return lista;
  }

  String? _validar() {
    final ini = _inicio, fim = _fim;
    if (ini == null || fim == null) {
      if (ini == null && fim == null) return 'Escolha o horário inicial e o final.';
      return ini == null ? 'Escolha o horário inicial.' : 'Escolha o horário final.';
    }
    if (fim <= ini) return 'O horário final deve ser maior que o inicial.';
    if (_repetir && _dias.isEmpty) return 'Escolha pelo menos um dia da semana.';
    if (_repetir && _termino.isBefore(_data)) {
      return 'A data de término deve ser depois da data inicial.';
    }
    final datas = _ocorrencias();
    if (datas.isEmpty) return 'Nenhum dia escolhido cai dentro do período.';
    for (final d in datas) {
      final marca = _repetir
          ? ' (${diaSemanaCurto(d).toLowerCase()}, ${doisDigitos(d.day)}/${doisDigitos(d.month)})'
          : '';
      if (mesmoDia(d, _hoje) && ini < minutosDoDia(widget.agora)) {
        return 'Este horário já passou. Escolha um horário a partir de agora.';
      }
      final (tIni, tFim) = widget.terapeuta.turnoDe(d);
      if (_sobrepoe(ini, fim, tIni, tFim)) {
        return 'Este horário coincide com seu expediente das '
            '${horaDeMinutos(tIni)} às ${horaDeMinutos(tFim)}$marca.';
      }
      for (final o in _doDia(d)) {
        if (_sobrepoe(ini, fim, o.inicio, o.fim)) {
          final faixa = '${horaDeMinutos(o.inicio)} – ${horaDeMinutos(o.fim)}';
          return o.reservado
              ? 'Este horário coincide com o horário reservado de '
                  '${o.clienteReservado} ($faixa)$marca.'
              : 'Este horário coincide com outra disponibilidade ($faixa)$marca.';
        }
      }
    }
    return null;
  }

  Future<void> _escolherData({required bool termino}) async {
    if (_salvando) return;
    setState(() => _alvoAberto = termino ? _Alvo.termino : _Alvo.data);
    final escolhida = await escolherData(
      context,
      rotulo: termino ? 'Termina em' : 'Data da disponibilidade',
      inicial: termino ? _termino : _data,
      hoje: widget.agora,
      minima: termino ? _data : _hoje,
    );
    if (!mounted) return;
    setState(() {
      _alvoAberto = null;
      if (escolhida == null) return;
      _erro = null;
      if (termino) {
        _termino = escolhida;
      } else {
        _data = escolhida;
        if (!_repetir) _dias = {escolhida.weekday % 7};
        if (_termino.isBefore(escolhida)) _termino = somarDias(escolhida, 28);
      }
    });
  }

  Future<void> _escolherHorario({required bool fim}) async {
    if (_salvando) return;
    setState(() => _alvoAberto = fim ? _Alvo.fim : _Alvo.inicio);
    final existentes = _doDia(_data);
    final (tIni, tFim) = widget.terapeuta.turnoDe(_data);
    final ehHoje = mesmoDia(_data, _hoje);
    final agoraMin = minutosDoDia(widget.agora);
    final escolhido = await escolherHorario(
      context,
      rotulo: fim ? 'Horário final' : 'Horário inicial',
      diaTexto:
          '${diaSemanaCurto(_data)}, ${_data.day} de ${mesesAbrev[_data.month - 1]}.',
      inicial: fim ? (_fim ?? (_inicio == null ? null : _inicio! + 60)) : _inicio,
      desabilitado: (t) =>
          (fim && _inicio != null && t <= _inicio!) ||
          (!fim && ehHoje && t < agoraMin),
      conflito: (t) {
        final a = fim ? t - 30 : t;
        final b = fim ? t : t + 30;
        return _sobrepoe(a, b, tIni, tFim) ||
            existentes.any((o) => _sobrepoe(a, b, o.inicio, o.fim));
      },
    );
    if (!mounted) return;
    setState(() {
      _alvoAberto = null;
      if (escolhido == null) return;
      _erro = null;
      if (fim) {
        _fim = escolhido;
      } else {
        _inicio = escolhido;
      }
    });
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    final erro = _validar();
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    setState(() {
      _erro = null;
      _salvando = true;
    });
    await Future.delayed(const Duration(milliseconds: 1200));
    final datas = _ocorrencias();
    final ini = _inicio!, fim = _fim!;
    String mensagem;
    if (_editando) {
      await repositorio.atualizarDisponibilidade(
        widget.existente!.copyWith(data: _data, inicio: ini, fim: fim),
      );
      final extras = datas.where((d) => !mesmoDia(d, _data)).toList();
      if (extras.isNotEmpty) {
        await repositorio.adicionarDisponibilidades([
          for (final d in extras)
            Disponibilidade(id: repositorio.novoId(), data: d, inicio: ini, fim: fim),
        ]);
      }
      mensagem = 'Horário atualizado';
    } else {
      await repositorio.adicionarDisponibilidades([
        for (final d in datas)
          Disponibilidade(
              id: repositorio.novoId(), data: d, inicio: ini, fim: fim, nova: true),
      ]);
      mensagem = datas.length > 1
          ? '${datas.length} horários adicionados'
          : 'Disponibilidade adicionada';
    }
    if (mounted) {
      Navigator.of(context)
          .pop(ResultadoDisponibilidade(mensagem: mensagem, data: _data));
    }
  }

  Future<void> _excluir() async {
    final d = widget.existente;
    if (d == null || _salvando) return;
    await repositorio.removerDisponibilidade(d.id);
    if (mounted) {
      Navigator.of(context).pop(ResultadoDisponibilidade(
        mensagem: 'Horário removido',
        data: d.data,
        removida: d,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ini = _inicio, fim = _fim;
    final duracao =
        (ini != null && fim != null && fim > ini) ? fim - ini : null;
    final ocorrencias = _repetir ? _ocorrencias() : const <DateTime>[];

    return PopScope(
      canPop: !_salvando,
      child: FolhaFormulario(
        titulo: _editando ? 'Editar disponibilidade' : 'Adicionar disponibilidade',
        subtitulo: 'Defina um período livre para atendimentos particulares.',
        aoFechar: _salvando ? null : () => Navigator.of(context).pop(),
        children: [
          RotuloCampo('Data',
              cor: _alvoAberto == _Alvo.data ? AppColors.primariaForte : null),
          const SizedBox(height: 8),
          CampoSeletor(
            icone: Icons.calendar_today_rounded,
            valor: dataPorExtenso(_data),
            iconeFinal: Icons.edit_calendar_outlined,
            foco: _alvoAberto == _Alvo.data,
            habilitado: !_salvando,
            rotuloAcessivel: 'Data',
            aoTocar: () => _escolherData(termino: false),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _campoHorario(fim: false)),
              const SizedBox(width: 16),
              Expanded(child: _campoHorario(fim: true)),
            ],
          ),
          if (_erro != null) ...[
            const SizedBox(height: 8),
            Semantics(liveRegion: true, child: ErroCampo(_erro!)),
          ],
          if (_erro == null && duracao != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  const Icon(Icons.timelapse_rounded,
                      size: 16, color: AppColors.primariaForte),
                  const SizedBox(width: 4),
                  Text('Duração: ${duracaoTexto(duracao)}',
                      style: AppText.s(12,
                          peso: FontWeight.w600,
                          altura: 16,
                          cor: AppColors.primariaForte)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _repetir ? AppColors.hover : AppColors.fundoCampo,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _salvando
                      ? null
                      : () => setState(() {
                            _repetir = !_repetir;
                            _erro = null;
                          }),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Repetir semanalmente',
                                  style: AppText.s(15,
                                      peso: FontWeight.w600, altura: 20)),
                              const SizedBox(height: 2),
                              Text('Mesmo horário nos dias escolhidos',
                                  style: AppText.s(13,
                                      altura: 18, cor: AppColors.textoSuave)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Interruptor(
                          valor: _repetir,
                          aoMudar: _salvando
                              ? null
                              : (v) => setState(() {
                                    _repetir = v;
                                    _erro = null;
                                  }),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_repetir) ...[
                  const SizedBox(height: 16),
                  Text('Dias da semana',
                      style: AppText.s(14, peso: FontWeight.w600, altura: 20)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++) Expanded(child: _botaoDia(i)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RotuloCampo('Termina em',
                      cor: _alvoAberto == _Alvo.termino
                          ? AppColors.primariaForte
                          : null),
                  const SizedBox(height: 8),
                  CampoSeletor(
                    icone: Icons.event_repeat_rounded,
                    valor: dataCurta(_termino),
                    iconeFinal: Icons.edit_calendar_outlined,
                    foco: _alvoAberto == _Alvo.termino,
                    habilitado: !_salvando,
                    fundoFixo: AppColors.superficie,
                    rotuloAcessivel: 'Termina em',
                    aoTocar: () => _escolherData(termino: true),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      ocorrencias.isEmpty
                          ? 'Nenhuma ocorrência no período'
                          : '${ocorrencias.length} '
                              '${ocorrencias.length == 1 ? 'ocorrência' : 'ocorrências'}, '
                              'de ${dataCurta(_data).substring(0, 5)} a '
                              '${dataCurta(_termino).substring(0, 5)}',
                      style: AppText.s(12,
                          peso: FontWeight.w600,
                          altura: 16,
                          cor: ocorrencias.isEmpty
                              ? AppColors.textoSuave
                              : AppColors.primariaForte),
                    ),
                  ),
                ],
              ],
            ),
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
                flex: 14,
                child: BotaoPrimario(
                  rotulo: _salvando
                      ? 'Salvando…'
                      : _editando
                          ? 'Salvar'
                          : 'Adicionar',
                  carregando: _salvando,
                  aoPressionar: _salvar,
                ),
              ),
            ],
          ),
          if (_editando) ...[
            const SizedBox(height: 8),
            Center(
              child: BotaoTexto(
                rotulo: 'Excluir horário',
                icone: Icons.delete_outline_rounded,
                cor: AppColors.erro,
                aoPressionar: _salvando ? null : _excluir,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _campoHorario({required bool fim}) {
    final valor = fim ? _fim : _inicio;
    final alvo = fim ? _Alvo.fim : _Alvo.inicio;
    final rotulo = fim ? 'Horário final' : 'Horário inicial';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RotuloCampo(
          rotulo,
          cor: _erro != null
              ? AppColors.erro
              : _alvoAberto == alvo
                  ? AppColors.primariaForte
                  : null,
        ),
        const SizedBox(height: 8),
        CampoSeletor(
          icone: Icons.schedule_rounded,
          valor: valor == null ? '--:--' : horaDeMinutos(valor),
          vazio: valor == null,
          negrito: true,
          foco: _alvoAberto == alvo,
          erro: _erro != null,
          habilitado: !_salvando,
          rotuloAcessivel: rotulo,
          aoTocar: () => _escolherHorario(fim: fim),
        ),
      ],
    );
  }

  Widget _botaoDia(int i) {
    final ligado = _dias.contains(i);
    const nomes = [
      'Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira',
      'Quinta-feira', 'Sexta-feira', 'Sábado',
    ];
    return Semantics(
      button: true,
      selected: ligado,
      label: nomes[i],
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _salvando
            ? null
            : () => setState(() {
                  _erro = null;
                  if (ligado) {
                    _dias = {..._dias}..remove(i);
                  } else {
                    _dias = {..._dias, i};
                  }
                }),
        child: SizedBox(
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ligado ? AppColors.primaria : AppColors.superficie,
                shape: BoxShape.circle,
                border: Border.all(
                    color: ligado ? AppColors.primaria : AppColors.contorno),
              ),
              child: Text(
                iniciaisSemanaDomingo[i],
                style: AppText.s(14,
                    peso: FontWeight.w700,
                    altura: 20,
                    cor: ligado ? AppColors.sobrePrimaria : AppColors.texto),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
