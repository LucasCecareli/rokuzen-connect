import 'models/modelos.dart';
import 'repositorio.dart';
import 'repositorio_demonstracao.dart';
import 'services/atendimento_api_service.dart';
import 'services/paciente_api_service.dart';

class RepositorioApi extends RokuzenRepository {
  RepositorioApi() {
    // Repassa os avisos de mudança do repositório de demonstração às telas.
    _demo.addListener(notifyListeners);
  }

  final RepositorioDemonstracao _demo = RepositorioDemonstracao();
  final PacienteApiService _pacientesApi = PacienteApiService();
  final AtendimentoApiService _atendimentosApi = AtendimentoApiService();

  Terapeuta? _terapeutaLogado;
  final Map<String, StatusAtendimento> _statusLocais = {};

  @override
  Terapeuta? get terapeutaAtual => _terapeutaLogado ?? _demo.terapeutaAtual;

  @override
  void definirTerapeutaLogado(Terapeuta terapeuta) {
    _terapeutaLogado = terapeuta;
    notifyListeners();
  }

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
  Future<Terapeuta> buscarTerapeuta() async {
    if (_terapeutaLogado != null) return _terapeutaLogado!;
    return _demo.buscarTerapeuta();
  }

  @override
  Future<List<Atendimento>> buscarAtendimentos(
    DateTime inicio,
    DateTime fim,
  ) async {
    final terapeuta = _terapeutaLogado ?? _demo.terapeutaAtual;
    if (terapeuta == null) {
      return _demo.buscarAtendimentos(inicio, fim);
    }

    try {
      final lista = await _atendimentosApi.buscarAtendimentos(
        terapeutaId: terapeuta.id,
        inicio: inicio,
        fim: fim,
      );

      return [
        for (final a in lista)
          if (_statusLocais.containsKey(a.id))
            a.comStatus(_statusLocais[a.id]!)
          else
            a,
      ];
    } catch (_) {
      // Em caso de falha de conexão com a API, usa o fallback seguro
      final demoLista = await _demo.buscarAtendimentos(inicio, fim);
      return [
        for (final a in demoLista)
          if (_statusLocais.containsKey(a.id))
            a.comStatus(_statusLocais[a.id]!)
          else
            a,
      ];
    }
  }

  @override
  Future<Atendimento?> buscarProximoAtendimento(DateTime aPartirDe) async {
    final terapeuta = _terapeutaLogado ?? _demo.terapeutaAtual;
    if (terapeuta == null) {
      return _demo.buscarProximoAtendimento(aPartirDe);
    }

    try {
      final proximo = await _atendimentosApi.buscarProximoAtendimento(
        terapeutaId: terapeuta.id,
        aPartirDe: aPartirDe,
      );

      if (proximo == null) return null;

      if (_statusLocais.containsKey(proximo.id)) {
        return proximo.comStatus(_statusLocais[proximo.id]!);
      }
      return proximo;
    } catch (_) {
      final proximoDemo = await _demo.buscarProximoAtendimento(aPartirDe);
      if (proximoDemo != null && _statusLocais.containsKey(proximoDemo.id)) {
        return proximoDemo.comStatus(_statusLocais[proximoDemo.id]!);
      }
      return proximoDemo;
    }
  }

  @override
  Future<List<Atendimento>> buscarAtendimentosDoPaciente(
    String pacienteId,
  ) async {
    try {
      final lista =
          await _atendimentosApi.buscarAtendimentosDoPaciente(pacienteId);
      if (lista.isNotEmpty) {
        return [
          for (final a in lista)
            if (_statusLocais.containsKey(a.id))
              a.comStatus(_statusLocais[a.id]!)
            else
              a,
        ];
      }
      return _demo.buscarAtendimentosDoPaciente(pacienteId);
    } catch (_) {
      return _demo.buscarAtendimentosDoPaciente(pacienteId);
    }
  }

  @override
  Future<List<Disponibilidade>> buscarDisponibilidades() =>
      _demo.buscarDisponibilidades();

  @override
  Future<void> alterarStatus(
    String atendimentoId,
    StatusAtendimento status,
  ) async {
    _statusLocais[atendimentoId] = status;
    await _demo.alterarStatus(atendimentoId, status);
    notifyListeners();
  }

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
