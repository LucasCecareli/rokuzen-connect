import 'package:flutter/services.dart';

/// Funções de formatação de datas, horas e textos em português do Brasil.

const meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho',
  'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];
const mesesAbrev = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out',
  'nov', 'dez',
];

// Índices pelo DateTime.weekday (1 = segunda ... 7 = domingo).
const _diasCompletos = [
  'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira',
  'Sexta-feira', 'Sábado', 'Domingo',
];
const _diasCurtos = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const _diasSiglas = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
const _diasMinusculos = [
  'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo',
];

/// Iniciais dos dias para calendários que começam no domingo.
const iniciaisSemanaDomingo = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

String diaSemanaCompleto(DateTime d) => _diasCompletos[d.weekday - 1];
String diaSemanaCurto(DateTime d) => _diasCurtos[d.weekday - 1];
String diaSemanaSigla(DateTime d) => _diasSiglas[d.weekday - 1];
String diaSemanaMinusculo(DateTime d) => _diasMinusculos[d.weekday - 1];

String doisDigitos(int n) => n.toString().padLeft(2, '0');

/// "14:00"
String hora(DateTime d) => '${doisDigitos(d.hour)}:${doisDigitos(d.minute)}';

/// Minutos desde a meia-noite → "14:00"
String horaDeMinutos(int minutos) =>
    '${doisDigitos(minutos ~/ 60)}:${doisDigitos(minutos % 60)}';

/// "14:00" → minutos desde a meia-noite
int minutosDeHora(String hhmm) {
  final partes = hhmm.split(':');
  return int.parse(partes[0]) * 60 + int.parse(partes[1]);
}

int minutosDoDia(DateTime d) => d.hour * 60 + d.minute;

DateTime soData(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime somarDias(DateTime d, int dias) =>
    DateTime(d.year, d.month, d.day + dias);

bool mesmoDia(DateTime? a, DateTime? b) =>
    a != null &&
    b != null &&
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day;

/// Segunda-feira da semana de [d].
DateTime inicioDaSemana(DateTime d) => somarDias(soData(d), -(d.weekday - 1));

/// "02/10/2026"
String dataCurta(DateTime d) =>
    '${doisDigitos(d.day)}/${doisDigitos(d.month)}/${d.year}';

/// "2 de outubro"
String diaEMes(DateTime d) => '${d.day} de ${meses[d.month - 1]}';

/// "Sexta-feira, 2 de outubro"
String dataPorExtenso(DateTime d) => '${diaSemanaCompleto(d)}, ${diaEMes(d)}';

/// "25 SET 2026"
String dataEtiqueta(DateTime d) =>
    '${doisDigitos(d.day)} ${mesesAbrev[d.month - 1].toUpperCase()} ${d.year}';

/// "Outubro 2026"
String mesAno(DateTime d) => '${capitalizar(meses[d.month - 1])} ${d.year}';

/// "28 set – 4 out" ou "5 – 11 out"
String intervaloDatas(DateTime inicio, DateTime fim) {
  if (inicio.month == fim.month) {
    return '${inicio.day} – ${fim.day} ${mesesAbrev[fim.month - 1]}';
  }
  return '${inicio.day} ${mesesAbrev[inicio.month - 1]} – '
      '${fim.day} ${mesesAbrev[fim.month - 1]}';
}

/// 45 → "45 min", 90 → "1h30", 120 → "2h"
String duracaoTexto(int minutos) {
  if (minutos < 60) return '$minutos min';
  final resto = minutos % 60;
  return '${minutos ~/ 60}h${resto > 0 ? doisDigitos(resto) : ''}';
}

/// "em 25 min", "em 1h30", "Agora"
String contagemRegressiva(int minutos) {
  if (minutos <= 0) return 'Agora';
  if (minutos < 60) return 'em $minutos min';
  final resto = minutos % 60;
  return 'em ${minutos ~/ 60}h${resto > 0 ? doisDigitos(resto) : ''}';
}

String sessoesTexto(int n) => '$n ${n == 1 ? 'sessão' : 'sessões'}';

String capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "Ana Paula Martins" → "AP"
String iniciais(String nome) {
  final partes =
      nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  return partes.take(2).map((p) => p[0]).join().toUpperCase();
}

String apenasDigitos(String s) => s.replaceAll(RegExp(r'\D'), '');

/// Remove acentos e deixa minúsculo, para comparar textos na busca.
String normalizar(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const para = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  final buffer = StringBuffer();
  for (final ch in s.split('')) {
    final i = de.indexOf(ch);
    buffer.write(i >= 0 ? para[i] : ch);
  }
  return buffer.toString().toLowerCase();
}

/// "11999991234" → "(11) 99999-1234"
String mascaraTelefone(String valor) {
  final d = apenasDigitos(valor);
  final digitos = d.length > 11 ? d.substring(0, 11) : d;
  if (digitos.isEmpty) return '';
  if (digitos.length <= 2) return '($digitos';
  if (digitos.length <= 7) {
    return '(${digitos.substring(0, 2)}) ${digitos.substring(2)}';
  }
  return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 7)}-'
      '${digitos.substring(7)}';
}

/// Aplica a máscara de telefone enquanto o usuário digita.
class MascaraTelefoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = mascaraTelefone(newValue.text);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
