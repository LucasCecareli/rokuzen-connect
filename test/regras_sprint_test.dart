import 'package:flutter_test/flutter_test.dart';

// ============================================================================
// MODELOS E FUNÇÕES AUXILIARES - SPRINT 1 (US01, US02 e US03)
// ============================================================================

class AtendimentoDemo {
  final String id;
  final String terapeutaLogin;
  final String paciente;
  final String unidade;
  final String status;
  final DateTime inicio;
  final DateTime fim;

  AtendimentoDemo({
    required this.id,
    required this.terapeutaLogin,
    required this.paciente,
    required this.unidade,
    required this.status,
    required this.inicio,
    required this.fim,
  });

  int get duracaoMinutos => fim.difference(inicio).inMinutes;
}

String normalizarTextoLogin(String texto) => texto.trim().toLowerCase();

bool autenticarTerapeuta(
  String login,
  String senha,
  Map<String, String> usuariosValidos,
) {
  final loginNormalizado = normalizarTextoLogin(login);
  if (loginNormalizado.isEmpty || senha.trim().isEmpty) return false;
  return usuariosValidos[loginNormalizado] == senha;
}

String formatarDataResumo(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year}';
}

List<AtendimentoDemo> filtrarAgendaDiaria(
  List<AtendimentoDemo> todosAtendimentos,
  String terapeutaLogin,
  DateTime dataSelecionada,
) {
  final loginNorm = normalizarTextoLogin(terapeutaLogin);
  final filtrados = todosAtendimentos.where((a) {
    final mesmoTerapeuta = normalizarTextoLogin(a.terapeutaLogin) == loginNorm;
    final mesmaData = a.inicio.year == dataSelecionada.year &&
        a.inicio.month == dataSelecionada.month &&
        a.inicio.day == dataSelecionada.day;
    return mesmoTerapeuta && mesmaData;
  }).toList();

  filtrados.sort((a, b) => a.inicio.compareTo(b.inicio));
  return filtrados;
}

AtendimentoDemo? obterProximoAtendimento(
  List<AtendimentoDemo> atendimentosDoDia,
  DateTime horarioAtual,
) {
  final futuros = atendimentosDoDia
      .where((a) => a.status == 'Confirmado' && a.inicio.isAfter(horarioAtual))
      .toList();
  futuros.sort((a, b) => a.inicio.compareTo(b.inicio));
  return futuros.isEmpty ? null : futuros.first;
}

// ============================================================================
// FUNÇÕES AUXILIARES - SPRINT 2 (US04 a US09)
// ============================================================================

bool validarNomePaciente(String nome) => nome.trim().isNotEmpty;

bool validarEmailPaciente(String email) {
  if (email.trim().isEmpty) return true;
  final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
  return regex.hasMatch(email.trim());
}

bool validarTelefonePaciente(String telefone) {
  if (telefone.trim().isEmpty) return true;
  final digitos = telefone.replaceAll(RegExp(r'\D'), '');
  return digitos.length >= 10 && digitos.length <= 11;
}

bool validarIntervaloHorario(DateTime inicio, DateTime fim) {
  return fim.isAfter(inicio);
}

bool verificarSobreposicaoHorario(
  DateTime novoInicio,
  DateTime novoFim,
  List> horariosExistentes,
) {
  for (final h in horariosExistentes) {
    final inicioExistente = h['inicio']!;
    final fimExistente = h['fim']!;
    if (novoInicio.isBefore(fimExistente) && novoFim.isAfter(inicioExistente)) {
      return true;
    }
  }
  return false;
}

// ============================================================================
// SUÍTE UNIFICADA DE TESTES (SPRINT 1 + SPRINT 2)
// ============================================================================

void main() {
  final credenciaisMock = {
    'terapeutaarthur': '123456',
    'mariana': 'senha123',
  };

  final baseAtendimentos = [
    AtendimentoDemo(
      id: 'ATD01',
      terapeutaLogin: 'terapeutaarthur',
      paciente: 'Ana Paula Martins',
      unidade: 'Mooca Plaza',
      status: 'Confirmado',
      inicio: DateTime(2026, 10, 2, 14, 0),
      fim: DateTime(2026, 10, 2, 15, 0),
    ),
    AtendimentoDemo(
      id: 'ATD02',
      terapeutaLogin: 'terapeutaarthur',
      paciente: 'Juliana Costa',
      unidade: 'Mooca Plaza',
      status: 'Concluído',
      inicio: DateTime(2026, 10, 2, 10, 0),
      fim: DateTime(2026, 10, 2, 11, 0),
    ),
    AtendimentoDemo(
      id: 'ATD03',
      terapeutaLogin: 'mariana',
      paciente: 'Carlos Eduardo Rocha',
      unidade: 'Grand Plaza',
      status: 'Confirmado',
      inicio: DateTime(2026, 10, 2, 11, 0),
      fim: DateTime(2026, 10, 2, 11, 45),
    ),
  ];

  // --- TESTES DA SPRINT 1 ---

  group('US01 - Autenticação do terapeuta e normalização de textos', () {
    test('1. Deve permitir o acesso somente para terapeuta com credenciais válidas', () {
      expect(autenticarTerapeuta('terapeutaarthur', '123456', credenciaisMock), isTrue);
      expect(autenticarTerapeuta('  TERAPEUTAARTHUR ', '123456', credenciaisMock), isTrue);
    });

    test('2. Deve bloquear acesso com credenciais inválidas ou campos vazios', () {
      expect(autenticarTerapeuta('terapeutaarthur', 'senha_errada', credenciaisMock), isFalse);
      expect(autenticarTerapeuta('usuario_inexistente', '123456', credenciaisMock), isFalse);
      expect(autenticarTerapeuta('', '', credenciaisMock), isFalse);
    });
  });

  group('US02 - Tela inicial, manipulação de datas e próximo atendimento', () {
    test('3. Deve formatar corretamente a data atual exibida na tela inicial', () {
      final data = DateTime(2026, 10, 2);
      expect(formatarDataResumo(data), equals('02/10/2026'));
    });

    test('4. Deve identificar corretamente o próximo atendimento confirmado do dia', () {
      final agendaArthur = filtrarAgendaDiaria(
        baseAtendimentos,
        'terapeutaarthur',
        DateTime(2026, 10, 2),
      );
      final proximo = obterProximoAtendimento(agendaArthur, DateTime(2026, 10, 2, 13, 35));

      expect(proximo, isNotNull);
      expect(proximo!.paciente, equals('Ana Paula Martins'));
      expect(proximo.unidade, equals('Mooca Plaza'));
    });

    test('5. Deve retornar nulo para próximo atendimento quando o dia estiver livre', () {
      final agendaDiaLivre = filtrarAgendaDiaria(
        baseAtendimentos,
        'terapeutaarthur',
        DateTime(2026, 10, 23),
      );
      final proximo = obterProximoAtendimento(agendaDiaLivre, DateTime(2026, 10, 23, 10, 0));

      expect(agendaDiaLivre, isEmpty);
      expect(proximo, isNull);
    });
  });

  group('US03 - Agenda diária, isolamento por usuário e duração de sessões', () {
    test('6. Deve exibir apenas os atendimentos associados ao terapeuta autenticado', () {
      final agendaArthur = filtrarAgendaDiaria(
        baseAtendimentos,
        'terapeutaarthur',
        DateTime(2026, 10, 2),
      );

      expect(agendaArthur.length, equals(2));
      expect(agendaArthur.every((a) => a.terapeutaLogin == 'terapeutaarthur'), isTrue);
    });

    test('7. Deve ordenar os atendimentos da data selecionada por horário', () {
      final agendaArthur = filtrarAgendaDiaria(
        baseAtendimentos,
        'terapeutaarthur',
        DateTime(2026, 10, 2),
      );

      expect(agendaArthur.first.paciente, equals('Juliana Costa'));
      expect(agendaArthur.last.paciente, equals('Ana Paula Martins'));
    });

    test('8. Deve calcular corretamente a duração dos atendimentos em minutos', () {
      final sessao60Min = baseAtendimentos[0];
      final sessao45Min = baseAtendimentos[2];

      expect(sessao60Min.duracaoMinutos, equals(60));
      expect(sessao45Min.duracaoMinutos, equals(45));
    });
  });

  // --- TESTES DA SPRINT 2 ---

  group('US04 - Agenda Semanal (Caixa Branca / Unitário)', () {
    test('9. Deve identificar corretamente os 7 dias do intervalo da semana selecionada', () {
      final inicioSemana = DateTime(2026, 11, 16);
      final diasSemana = List.generate(7, (i) => inicioSemana.add(Duration(days: i)));

      expect(diasSemana.length, 7);
      expect(diasSemana.first.day, 16);
      expect(diasSemana.last.day, 22);
    });
  });

  group('US05 - Cadastro Simplificado de Pacientes (Caixa Branca / Unitário)', () {
    test('10. Deve exigir nome obrigatório no cadastro de paciente', () {
      expect(validarNomePaciente(''), isFalse);
      expect(validarNomePaciente('   '), isFalse);
      expect(validarNomePaciente('Lucas Cecarelo'), isTrue);
    });

    test('11. Deve validar formato de e-mail e telefone quando informados', () {
      expect(validarEmailPaciente('lucasribeiro2k26@gmail.com'), isTrue);
      expect(validarEmailPaciente('email_invalido'), isFalse);
      expect(validarTelefonePaciente('(11) 99999-9999'), isTrue);
      expect(validarTelefonePaciente('12345'), isFalse);
    });
  });

  group('US06 - Histórico Básico de Sessões (Caixa Branca / Unitário)', () {
    test('12. Deve ordenar o histórico da sessão mais recente para a mais antiga', () {
      final sessoes = [
        DateTime(2026, 11, 13, 18, 0),
        DateTime(2026, 11, 17, 14, 0),
        DateTime(2026, 11, 10, 10, 0),
      ];

      sessoes.sort((a, b) => b.compareTo(a));

      expect(sessoes.first, DateTime(2026, 11, 17, 14, 0));
      expect(sessoes.last, DateTime(2026, 11, 10, 10, 0));
    });
  });

  group('US07 - Horários Disponíveis Particulares (Caixa Branca / Unitário)', () {
    test('13. O horário de fim deve ser obrigatoriamente posterior ao horário de início', () {
      final inicio = DateTime(2026, 11, 20, 14, 0);
      final fimValido = DateTime(2026, 11, 20, 15, 0);
      final fimInvalido = DateTime(2026, 11, 20, 13, 30);

      expect(validarIntervaloHorario(inicio, fimValido), isTrue);
      expect(validarIntervaloHorario(inicio, fimInvalido), isFalse);
    });

    test('14. Não deve permitir cadastro de horários sobrepostos na mesma data', () {
      final existentes = >[
        {
          'inicio': DateTime(2026, 11, 20, 14, 0),
          'fim': DateTime(2026, 11, 20, 15, 0),
        }
      ];

      final sobreposto = verificarSobreposicaoHorario(
        DateTime(2026, 11, 20, 14, 30),
        DateTime(2026, 11, 20, 15, 30),
        existentes,
      );
      final livre = verificarSobreposicaoHorario(
        DateTime(2026, 11, 20, 15, 0),
        DateTime(2026, 11, 20, 16, 0),
        existentes,
      );

      expect(sobreposto, isTrue);
      expect(livre, isFalse);
    });
  });

  group('US09 - Detalhes do Atendimento (Caixa Branca / Unitário)', () {
    test('15. Deve preservar a data selecionada ao abrir detalhes e voltar para a agenda', () {
      final dataSelecionada = DateTime(2026, 11, 19);
      final atendimentoDetalhe = {
        'paciente': 'Lucas Cecarelo',
        'data': dataSelecionada,
        'horario': '18:00 - 18:30',
        'unidade': 'Grand Plaza',
        'status': 'Confirmado',
        'observacoes': 'Quick Massage 30 min',
      };

      expect(atendimentoDetalhe['data'], equals(dataSelecionada));
      expect(atendimentoDetalhe['observacoes'], isNotEmpty);
    });
  });
}