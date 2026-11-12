import '../../core/formatadores.dart';

/// Status de um atendimento.
enum StatusAtendimento {
  confirmado,
  pendente,
  andamento,
  concluido,
  cancelado,
  faltou;

  String get rotulo => switch (this) {
        StatusAtendimento.confirmado => 'Confirmado',
        StatusAtendimento.pendente => 'Pendente',
        StatusAtendimento.andamento => 'Em andamento',
        StatusAtendimento.concluido => 'Concluído',
        StatusAtendimento.cancelado => 'Cancelado',
        StatusAtendimento.faltou => 'Faltou',
      };

  /// Cancelado ou falta: não conta nas sessões do dia.
  bool get inativo =>
      this == StatusAtendimento.cancelado || this == StatusAtendimento.faltou;

  /// Ainda vai acontecer (ou está acontecendo).
  bool get emAberto =>
      this == StatusAtendimento.confirmado ||
      this == StatusAtendimento.pendente ||
      this == StatusAtendimento.andamento;
}

/// Serviços oferecidos pela Rokuzen e as durações aceitas no agendamento.
enum Servico {
  quickMassage('Quick Massage', [15, 30]),
  // Na Maca o cliente não escolhe modalidade (Shiatsu, Anmá, Ventosa ou
  // Relaxante): o app mostra apenas "Maca".
  maca('Maca', [30, 45, 60, 90, 120]),
  // Pode receber o adicional de Auriculoterapia (10 min) em combo.
  reflexologiaPodal('Reflexologia Podal', [20, 30, 40, 60]),
  auriculoterapia('Auriculoterapia', [10]);

  const Servico(this.nome, this.duracoes);
  final String nome;
  final List<int> duracoes;
}

/// Unidades da Rokuzen.
abstract final class Unidades {
  static const goldenSquare = 'Golden Square';
  static const grandPlaza = 'Grand Plaza';
  static const moocaPlaza = 'Mooca Plaza';
  static const westPlaza = 'West Plaza';
}

class Terapeuta {
  const Terapeuta({
    required this.id,
    required this.nome,
    required this.unidade,
    required this.inicioTurno,
    required this.fimTurno,
    this.escala = const {},
  });

  final String id;
  final String nome;
  final String unidade;

  /// Turno de segunda a sábado, em minutos desde a meia-noite
  /// (10h–16h, 13h–19h ou 16h–22h).
  final int inicioTurno;
  final int fimTurno;

  String get primeiroNome {
    final partes = nome.split(' ').where((s) => s.isNotEmpty).toList();
    if (partes.length > 1 && partes.first.toLowerCase() == 'terapeuta') {
      return partes[1];
    }
    return partes.isNotEmpty ? partes.first : 'Terapeuta';
  }

  /// Expediente de cada dia vindo da escala da Rokuzen (chave: o dia, sem
  /// horário). Dias fora da escala usam o turno padrão.
  final Map<DateTime, (int, int)> escala;

  Terapeuta comEscala(Map<DateTime, (int, int)> escala) => Terapeuta(
        id: id,
        nome: nome,
        unidade: unidade,
        inicioTurno: inicioTurno,
        fimTurno: fimTurno,
        escala: escala,
      );

  /// Turno do dia: o da escala, se houver; senão o padrão (no domingo,
  /// das 14h às 20h).
  (int inicio, int fim) turnoDe(DateTime dia) {
    final daEscala = escala[DateTime(dia.year, dia.month, dia.day)];
    if (daEscala != null) return daEscala;
    return dia.weekday == DateTime.sunday
        ? (14 * 60, 20 * 60)
        : (inicioTurno, fimTurno);
  }

  String turnoTexto(DateTime dia) {
    final (ini, fim) = turnoDe(dia);
    return '${horaDeMinutos(ini)} – ${horaDeMinutos(fim)}';
  }

  /// Expediente da semana agrupando dias seguidos com o mesmo horário.
  /// Ex.: "Seg–sáb 09:00 – 18:00 · Dom 14:00 – 20:00".
  String resumoSemana(DateTime inicioSemana) {
    const nomes = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final grupos = <(int primeiro, int ultimo, String turno)>[];
    for (var i = 0; i < 7; i++) {
      final d = DateTime(
          inicioSemana.year, inicioSemana.month, inicioSemana.day + i);
      final t = turnoTexto(d);
      if (grupos.isNotEmpty && grupos.last.$3 == t) {
        grupos[grupos.length - 1] = (grupos.last.$1, i, t);
      } else {
        grupos.add((i, i, t));
      }
    }
    return grupos.map((g) {
      final dias = g.$1 == g.$2
          ? nomes[g.$1]
          : '${nomes[g.$1]}–${nomes[g.$2].toLowerCase()}';
      return '$dias ${g.$3}';
    }).join(' · ');
  }
}

class Paciente {
  const Paciente({
    required this.id,
    required this.nome,
    required this.telefone,
    this.email,
    this.nascimento,
    this.novo = false,
  });

  final String id;
  final String nome;
  final String telefone;
  final String? email;
  final DateTime? nascimento;

  /// Cadastrado agora pelo app (mostra o selo "Novo" na lista).
  final bool novo;

  Paciente copyWith({
    String? nome,
    String? telefone,
    String? email,
    DateTime? nascimento,
  }) {
    return Paciente(
      id: id,
      nome: nome ?? this.nome,
      telefone: telefone ?? this.telefone,
      email: email ?? this.email,
      nascimento: nascimento ?? this.nascimento,
      novo: novo,
    );
  }
}

class Atendimento {
  const Atendimento({
    required this.id,
    required this.pacienteId,
    required this.pacienteNome,
    required this.inicio,
    required this.servico,
    required this.duracao,
    this.adicionalAuriculo = 0,
    required this.unidade,
    required this.sala,
    required this.status,
    this.iniciadoEm,
  });

  final String id;
  final String pacienteId;
  final String pacienteNome;
  final DateTime inicio;
  final Servico servico;

  /// Duração do serviço principal, em minutos.
  final int duracao;

  /// Minutos do adicional de Auriculoterapia (só na Reflexologia Podal).
  final int adicionalAuriculo;
  final String unidade;
  final String sala;
  final StatusAtendimento status;

  /// Hora real em que a terapeuta tocou em "Iniciar atendimento" (pode ser
  /// diferente do horário marcado). Usada na barra de progresso.
  final DateTime? iniciadoEm;

  bool get temAdicional => adicionalAuriculo > 0;
  int get duracaoTotal => duracao + adicionalAuriculo;
  DateTime get fim => inicio.add(Duration(minutes: duracaoTotal));

  /// "Maca · 60 min"
  String get servicoTexto => '${servico.nome} · $duracao min';

  /// "+ Auriculoterapia 10 min"
  String get adicionalTexto => '+ Auriculoterapia $adicionalAuriculo min';

  /// "Reflexologia Podal · 30 min + Auriculoterapia 10 min"
  String get servicoCompleto =>
      servicoTexto + (temAdicional ? ' + Auriculoterapia $adicionalAuriculo min' : '');

  /// "14:00 – 15:00 · 60 min"
  String get horarioTexto =>
      '${hora(inicio)} – ${hora(fim)} · $duracaoTotal min';

  /// "Mooca Plaza · Sala 3" (ou só a unidade, quando não há sala).
  String get localTexto => sala.isEmpty ? unidade : '$unidade · $sala';

  Atendimento comStatus(StatusAtendimento novo) => Atendimento(
        id: id,
        pacienteId: pacienteId,
        pacienteNome: pacienteNome,
        inicio: inicio,
        servico: servico,
        duracao: duracao,
        adicionalAuriculo: adicionalAuriculo,
        unidade: unidade,
        sala: sala,
        status: novo,
        iniciadoEm: iniciadoEm,
      );
}

/// Resumo usado na lista de pacientes.
class PacienteResumo {
  const PacienteResumo({
    required this.paciente,
    this.ultimaSessao,
    this.atendimentoHoje,
  });

  final Paciente paciente;
  final DateTime? ultimaSessao;

  /// Próximo atendimento do paciente hoje (para o selo "Hoje · 14:00").
  final Atendimento? atendimentoHoje;
}

/// Horário livre que o terapeuta oferece para atendimentos particulares.
class Disponibilidade {
  const Disponibilidade({
    required this.id,
    required this.data,
    required this.inicio,
    required this.fim,
    this.clienteReservado,
    this.nova = false,
  });

  final int id;

  /// Dia (sem horário).
  final DateTime data;

  /// Início e fim em minutos desde a meia-noite.
  final int inicio;
  final int fim;

  /// Nome do cliente, quando o horário já foi reservado.
  final String? clienteReservado;

  /// Acabou de ser adicionada (fundo destacado).
  final bool nova;

  bool get reservado => clienteReservado != null;
  int get duracao => fim - inicio;

  Disponibilidade copyWith({DateTime? data, int? inicio, int? fim, bool? nova}) {
    return Disponibilidade(
      id: id,
      data: data ?? this.data,
      inicio: inicio ?? this.inicio,
      fim: fim ?? this.fim,
      clienteReservado: clienteReservado,
      nova: nova ?? this.nova,
    );
  }
}
