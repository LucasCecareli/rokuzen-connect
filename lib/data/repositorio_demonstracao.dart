import '../core/app_config.dart';
import '../core/formatadores.dart';
import 'models/modelos.dart';
import 'repositorio.dart';

/// Dados de exemplo, iguais aos do protótipo da ferramenta de design.
///
/// Tudo fica em memória: ao fechar o app, as alterações se perdem. Nada é lido
/// nem gravado no banco da Rokuzen por esta classe.
class RepositorioDemonstracao extends RokuzenRepository {
  RepositorioDemonstracao() {
    _pacientes.addAll(_pacientesIniciais());
    _atendimentos.addAll(_atendimentosIniciais());
    _disponibilidades.addAll(_disponibilidadesIniciais());
  }

  final List<Paciente> _pacientes = [];
  final List<Atendimento> _atendimentos = [];
  final List<Disponibilidade> _disponibilidades = [];
  int _ultimoId = 1000;

  static const _terapeuta = Terapeuta(
    id: 1,
    nome: 'Mariana',
    unidade: Unidades.moocaPlaza,
    inicioTurno: 10 * 60,
    fimTurno: 16 * 60,
  );

  Future<void> _atraso() => Future.delayed(AppConfig.atrasoSimulado);

  // ---------------------------------------------------------------- leitura

  @override
  Future<Terapeuta> buscarTerapeuta() async => _terapeuta;

  @override
  Future<List<Atendimento>> buscarAtendimentos(
    DateTime inicio,
    DateTime fim,
  ) async {
    await _atraso();
    return _ordenados(_atendimentos.where(
      (a) => !a.inicio.isBefore(inicio) && a.inicio.isBefore(fim),
    ));
  }

  @override
  Future<Atendimento?> buscarProximoAtendimento(DateTime aPartirDe) async {
    final futuros = _ordenados(_atendimentos.where(
      (a) => a.status.emAberto && !a.inicio.isBefore(aPartirDe),
    ));
    return futuros.isEmpty ? null : futuros.first;
  }

  @override
  Future<List<PacienteResumo>> buscarPacientes(DateTime agora) async {
    await _atraso();
    final hoje = soData(agora);
    return _pacientes.map((p) {
      final doPaciente = _atendimentos.where((a) => a.pacienteId == p.id);
      DateTime? ultima;
      for (final a in doPaciente) {
        if (a.status == StatusAtendimento.concluido &&
            (ultima == null || a.inicio.isAfter(ultima))) {
          ultima = a.inicio;
        }
      }
      final hojeEmAberto = _ordenados(doPaciente.where(
        (a) => mesmoDia(a.inicio, hoje) && a.status.emAberto,
      ));
      return PacienteResumo(
        paciente: p,
        ultimaSessao: ultima,
        atendimentoHoje: hojeEmAberto.isEmpty ? null : hojeEmAberto.first,
      );
    }).toList();
  }

  @override
  Future<Paciente?> buscarPaciente(int id) async {
    for (final p in _pacientes) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<List<Atendimento>> buscarAtendimentosDoPaciente(int pacienteId) async {
    await _atraso();
    return _ordenados(_atendimentos.where((a) => a.pacienteId == pacienteId))
        .reversed
        .toList();
  }

  @override
  Future<List<Disponibilidade>> buscarDisponibilidades() async {
    await _atraso();
    return List.of(_disponibilidades);
  }

  // ------------------------------------------- ações locais (só em memória)

  @override
  int novoId() => ++_ultimoId;

  @override
  Future<void> alterarStatus(int atendimentoId, StatusAtendimento status) async {
    final i = _atendimentos.indexWhere((a) => a.id == atendimentoId);
    if (i < 0) return;
    _atendimentos[i] = _atendimentos[i].comStatus(status);
    notifyListeners();
  }

  @override
  Future<Paciente> cadastrarPaciente({
    required String nome,
    required String telefone,
    String? email,
    DateTime? nascimento,
  }) async {
    final paciente = Paciente(
      id: novoId(),
      nome: nome,
      telefone: telefone,
      email: email,
      nascimento: nascimento,
      novo: true,
    );
    _pacientes.insert(0, paciente);
    notifyListeners();
    return paciente;
  }

  @override
  Future<Paciente> editarPaciente(Paciente paciente) async {
    final i = _pacientes.indexWhere((p) => p.id == paciente.id);
    if (i >= 0) _pacientes[i] = paciente;
    // Mantém o nome atualizado nos atendimentos do paciente.
    for (var k = 0; k < _atendimentos.length; k++) {
      final a = _atendimentos[k];
      if (a.pacienteId == paciente.id) {
        _atendimentos[k] = Atendimento(
          id: a.id,
          pacienteId: a.pacienteId,
          pacienteNome: paciente.nome,
          inicio: a.inicio,
          servico: a.servico,
          duracao: a.duracao,
          adicionalAuriculo: a.adicionalAuriculo,
          unidade: a.unidade,
          sala: a.sala,
          status: a.status,
        );
      }
    }
    notifyListeners();
    return paciente;
  }

  @override
  Future<void> adicionarDisponibilidades(List<Disponibilidade> novas) async {
    _disponibilidades.addAll(novas);
    notifyListeners();
  }

  @override
  Future<void> atualizarDisponibilidade(Disponibilidade d) async {
    final i = _disponibilidades.indexWhere((x) => x.id == d.id);
    if (i >= 0) {
      _disponibilidades[i] = d;
    } else {
      _disponibilidades.add(d);
    }
    notifyListeners();
  }

  @override
  Future<void> removerDisponibilidade(int id) async {
    _disponibilidades.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  @override
  Future<void> restaurarDisponibilidade(Disponibilidade d) async {
    if (!_disponibilidades.any((x) => x.id == d.id)) _disponibilidades.add(d);
    notifyListeners();
  }

  List<Atendimento> _ordenados(Iterable<Atendimento> lista) =>
      lista.toList()..sort((a, b) => a.inicio.compareTo(b.inicio));

  // ------------------------------------------------------- dados de exemplo

  static List<Paciente> _pacientesIniciais() => const [
        Paciente(id: 1, nome: 'Ana Paula Martins', telefone: '(11) 99999-1234', email: 'ana@email.com'),
        Paciente(id: 2, nome: 'Ricardo Mendes', telefone: '(11) 98765-4321'),
        Paciente(id: 3, nome: 'Juliana Costa', telefone: '(11) 97654-3210'),
        Paciente(id: 4, nome: 'Carlos Eduardo Rocha', telefone: '(11) 98888-4321'),
        Paciente(id: 5, nome: 'Roberto Lima', telefone: '(11) 96543-2109'),
        Paciente(id: 6, nome: 'Fernanda Lima', telefone: '(11) 97777-8899'),
        Paciente(id: 7, nome: 'João Santos', telefone: '(11) 95555-0101'),
        Paciente(id: 8, nome: 'Carlos Silva', telefone: '(11) 94444-0202'),
        Paciente(id: 9, nome: 'Marina Alves', telefone: '(11) 93333-0303'),
        Paciente(id: 10, nome: 'Beatriz Costa', telefone: '(11) 92222-0404'),
        Paciente(id: 11, nome: 'Paulo Nunes', telefone: '(11) 91111-0505'),
        Paciente(id: 12, nome: 'Marcos Vinícius', telefone: '(11) 98123-0606'),
        Paciente(id: 13, nome: 'Luciana Prado', telefone: '(11) 97234-0707'),
        Paciente(id: 14, nome: 'Rafael Souza', telefone: '(11) 96345-0808'),
      ];

  static List<Atendimento> _atendimentosIniciais() {
    final nomes = {for (final p in _pacientesIniciais()) p.id: p.nome};
    var id = 0;
    Atendimento a(
      int pacienteId,
      int mes,
      int dia,
      String horaInicio,
      Servico servico,
      int duracao,
      String sala, {
      int adicional = 0,
      StatusAtendimento status = StatusAtendimento.concluido,
    }) {
      final hm = minutosDeHora(horaInicio);
      return Atendimento(
        id: ++id,
        pacienteId: pacienteId,
        pacienteNome: nomes[pacienteId]!,
        inicio: DateTime(2026, mes, dia, hm ~/ 60, hm % 60),
        servico: servico,
        duracao: duracao,
        adicionalAuriculo: adicional,
        unidade: Unidades.moocaPlaza,
        sala: sala,
        status: status,
      );
    }

    const conf = StatusAtendimento.confirmado;
    const canc = StatusAtendimento.cancelado;
    const maca = Servico.maca;
    const quick = Servico.quickMassage;
    const reflexo = Servico.reflexologiaPodal;
    const auriculo = Servico.auriculoterapia;

    return [
      // Histórico da Ana Paula Martins
      a(1, 6, 12, '15:00', auriculo, 10, 'Sala 1'),
      a(1, 6, 27, '13:00', reflexo, 40, 'Sala 2'),
      a(1, 7, 10, '10:00', maca, 90, 'Sala 3'),
      a(1, 7, 24, '14:00', quick, 30, 'Cadeira 2'),
      a(1, 8, 7, '11:00', maca, 60, 'Sala 1'),
      a(1, 8, 21, '15:00', quick, 30, 'Cadeira 1'),
      a(1, 9, 4, '10:00', reflexo, 30, 'Sala 2', adicional: 10),
      a(1, 9, 25, '14:00', maca, 60, 'Sala 3'),
      // Outros históricos
      a(2, 9, 11, '15:00', reflexo, 30, 'Sala 2', adicional: 10),
      a(12, 9, 18, '12:00', quick, 30, 'Cadeira 1'),

      // Semana de 28 de setembro a 4 de outubro de 2026
      a(7, 9, 28, '10:00', quick, 30, 'Cadeira 1'),
      a(6, 9, 28, '14:00', reflexo, 40, 'Sala 2'),
      a(8, 9, 29, '11:00', maca, 60, 'Sala 1'),
      a(9, 9, 29, '15:00', quick, 15, 'Cadeira 2'),
      a(5, 9, 30, '13:00', reflexo, 30, 'Sala 2', adicional: 10),
      a(10, 10, 1, '10:00', maca, 90, 'Sala 3'),
      a(11, 10, 1, '15:00', quick, 30, 'Cadeira 1'),
      // Hoje: sexta-feira, 2 de outubro
      a(3, 10, 2, '10:00', maca, 60, 'Sala 2'),
      a(4, 10, 2, '11:00', maca, 45, 'Sala 1'),
      a(12, 10, 2, '12:00', quick, 30, 'Cadeira 1', status: canc),
      a(1, 10, 2, '14:00', maca, 60, 'Sala 3', status: conf),
      a(2, 10, 2, '15:00', reflexo, 30, 'Sala 2', adicional: 10, status: conf),
      a(13, 10, 3, '10:00', maca, 45, 'Sala 1', status: conf),
      a(14, 10, 4, '14:00', quick, 30, 'Cadeira 1', status: conf),
    ];
  }

  static List<Disponibilidade> _disponibilidadesIniciais() {
    var id = 0;
    Disponibilidade d(int dia, String ini, String fim, {String? cliente}) =>
        Disponibilidade(
          id: ++id,
          data: DateTime(2026, 10, dia),
          inicio: minutosDeHora(ini),
          fim: minutosDeHora(fim),
          clienteReservado: cliente,
        );
    return [
      d(2, '08:00', '09:00'),
      d(2, '17:00', '18:00', cliente: 'Patrícia Gomes'),
      d(2, '18:30', '19:30'),
      d(5, '17:00', '19:00'),
      d(7, '08:00', '09:30'),
      d(9, '17:00', '18:30'),
      d(12, '18:00', '20:00'),
      d(14, '08:00', '09:00'),
      d(14, '17:00', '18:00'),
      d(16, '17:30', '19:00'),
    ];
  }
}
