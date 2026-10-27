import 'models/modelos.dart';
import 'repositorio.dart';
import 'repositorio_demonstracao.dart';
import 'services/paciente_api_service.dart';


class RepositorioApi extends RokuzenRepository {
  RepositorioApi() {
    // Repassa os avisos de mudança do repositório de demonstração às telas.
    _demo.addListener(notifyListeners);
  }

  final RepositorioDemonstracao _demo = RepositorioDemonstracao();
  final PacienteApiService _pacientesApi = PacienteApiService();

  List<Paciente>? _doBanco; // lista vinda do backend (guardada após a 1ª busca)
  final List<Paciente> _locais = []; // cadastrados no aparelho
  final Map<String, Paciente> _editados = {}; // edições feitas no aparelho

  Future<List<Paciente>> _todos() async {
    _doBanco ??= await _pacientesApi.listarPacientes();
    return [
      ..._locais,
      for (final p in _doBanco!) _editados[p.id] ?? p,
    ];
  }

 

  @override
  Future<List<PacienteResumo>> buscarPacientes(DateTime agora) async {
    final todos = await _todos();
    return [for (final p in todos) PacienteResumo(paciente: p)];
  }

  @override
  Future<Paciente?> buscarPaciente(String id) async {
    for (final p in await _todos()) {
      if (p.id == id) return p;
    }
    return _demo.buscarPaciente(id);
  }

  @override
  Future<Paciente> cadastrarPaciente({
    required String nome,
    required String telefone,
    String? email,
    DateTime? nascimento,
  }) async {
    final paciente = Paciente(
      id: 'local-${novoId()}',
      nome: nome,
      telefone: telefone,
      email: email,
      nascimento: nascimento,
      novo: true,
    );
    _locais.insert(0, paciente);
    notifyListeners();
    return paciente;
  }

  @override
  Future<Paciente> editarPaciente(Paciente paciente) async {
    final i = _locais.indexWhere((p) => p.id == paciente.id);
    if (i >= 0) {
      _locais[i] = paciente;
    } else if (_doBanco?.any((p) => p.id == paciente.id) ?? false) {
      _editados[paciente.id] = paciente;
    } else {
      return _demo.editarPaciente(paciente);
    }
    notifyListeners();
    return paciente;
  }

  

  @override
  Future<Terapeuta> buscarTerapeuta() => _demo.buscarTerapeuta();

  @override
  Future<List<Atendimento>> buscarAtendimentos(DateTime inicio, DateTime fim) =>
      _demo.buscarAtendimentos(inicio, fim);

  @override
  Future<Atendimento?> buscarProximoAtendimento(DateTime aPartirDe) =>
      _demo.buscarProximoAtendimento(aPartirDe);

  @override
  Future<List<Atendimento>> buscarAtendimentosDoPaciente(String pacienteId) =>
      _demo.buscarAtendimentosDoPaciente(pacienteId);

  @override
  Future<List<Disponibilidade>> buscarDisponibilidades() =>
      _demo.buscarDisponibilidades();

  @override
  Future<void> alterarStatus(String atendimentoId, StatusAtendimento status) =>
      _demo.alterarStatus(atendimentoId, status);

  @override
  Future<void> adicionarDisponibilidades(List<Disponibilidade> novas) =>
      _demo.adicionarDisponibilidades(novas);

  @override
  Future<void> atualizarDisponibilidade(Disponibilidade disponibilidade) =>
      _demo.atualizarDisponibilidade(disponibilidade);

  @override
  Future<void> removerDisponibilidade(int id) =>
      _demo.removerDisponibilidade(id);

  @override
  Future<void> restaurarDisponibilidade(Disponibilidade disponibilidade) =>
      _demo.restaurarDisponibilidade(disponibilidade);

  @override
  int novoId() => _demo.novoId();
}