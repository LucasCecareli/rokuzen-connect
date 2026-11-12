import '../core/formatadores.dart';
import 'models/modelos.dart';
import 'repositorio.dart';
import 'services/api_cliente.dart';
import 'services/atendimento_api_service.dart';
import 'services/disponibilidade_api_service.dart';
import 'services/paciente_api_service.dart';

/// Implementação real: tudo vem do backend do grupo (e dele para o banco).
///
/// Leituras que falham devolvem vazio e preenchem [erroConexao] (as telas
/// continuam abertas e a tela principal mostra o aviso). Gravações que
/// falham lançam [ApiException] para o formulário mostrar o erro.
class RepositorioApi extends RokuzenRepository {
  final PacienteApiService _pacientesApi = PacienteApiService();
  final AtendimentoApiService _atendimentosApi = AtendimentoApiService();
  final DisponibilidadeApiService _disponibilidadesApi =
      DisponibilidadeApiService();

  Terapeuta? _terapeuta;
  bool _escalaCarregada = false;

  /// Pacientes com a última sessão (guardados após a 1ª busca).
  List<(Paciente, DateTime?)>? _pacientes;

  /// Horários particulares (guardados após a 1ª busca).
  List<Disponibilidade>? _disponibilidades;

  int _idProvisorio = 0;

  @override
  Terapeuta? get terapeutaAtual => _terapeuta;

  @override
  void definirTerapeutaLogado(Terapeuta terapeuta) {
    _limpar();
    _terapeuta = terapeuta;
    notifyListeners();
  }

  @override
  void sair() {
    _limpar();
    _terapeuta = null;
    super.sair();
  }

  @override
  void recarregar() {
    _pacientes = null;
    _disponibilidades = null;
    super.recarregar();
  }

  void _limpar() {
    _escalaCarregada = false;
    _carregandoEscala = null;
    _pacientes = null;
    _disponibilidades = null;
  }

  String get _terapeutaId {
    final t = _terapeuta;
    if (t == null) {
      throw const ApiException('Sessão encerrada. Entre novamente.');
    }
    return t.id;
  }

  /// Executa uma leitura; se falhar, registra o erro e devolve [vazio].
  Future<T> _ler<T>(Future<T> Function() leitura, T vazio) async {
    try {
      return await leitura();
    } catch (e) {
      erroConexao.value = e is ApiException
          ? e.mensagem
          : 'Não foi possível carregar os dados do servidor.';
      return vazio;
    }
  }

  // ---------------------------------------------------------------- leitura

  Future<Terapeuta>? _carregandoEscala;

  @override
  Future<Terapeuta> buscarTerapeuta() async {
    final t = _terapeuta;
    if (t == null) {
      throw const ApiException('Sessão encerrada. Entre novamente.');
    }
    if (_escalaCarregada) return t;
    // Evita buscar a escala várias vezes ao mesmo tempo.
    final emAndamento = _carregandoEscala ??= _carregarEscala(t);
    try {
      return await emAndamento;
    } finally {
      if (identical(_carregandoEscala, emAndamento)) _carregandoEscala = null;
    }
  }

  Future<Terapeuta> _carregarEscala(Terapeuta t) async {
    // Expediente de cada dia (escala da Rokuzen) de 3 meses atrás até
    // 6 meses à frente. Sem escala, o app usa o turno padrão.
    final hoje = soData(DateTime.now());
    final escala = await _ler<Map<DateTime, (int, int)>?>(
      () => _atendimentosApi.buscarEscala(
        terapeutaId: t.id,
        inicio: somarDias(hoje, -90),
        fim: somarDias(hoje, 180),
      ),
      null,
    );
    if (escala == null) return t;

    // A terapeuta pode ter saído enquanto a escala carregava.
    if (!identical(_terapeuta, t)) return _terapeuta ?? t;
    _escalaCarregada = true;
    _terapeuta = t.comEscala(escala);
    return _terapeuta!;
  }

  @override
  Future<List<Atendimento>> buscarAtendimentos(
    DateTime inicio,
    DateTime fim,
  ) {
    return _ler(
      () => _atendimentosApi.buscarAtendimentos(
        terapeutaId: _terapeutaId,
        inicio: inicio,
        fim: fim,
      ),
      const <Atendimento>[],
    );
  }

  @override
  Future<Atendimento?> buscarProximoAtendimento(DateTime aPartirDe) async {
    final proximos = await _ler(() async {
      final p = await _atendimentosApi.buscarProximoAtendimento(
        terapeutaId: _terapeutaId,
        aPartirDe: aPartirDe,
      );
      return [?p];
    }, const <Atendimento>[]);
    return proximos.isEmpty ? null : proximos.first;
  }

  Future<List<(Paciente, DateTime?)>> _carregarPacientes() async {
    return _pacientes ??= await _pacientesApi.listarPacientes(
      terapeutaId: _terapeutaId,
      agora: DateTime.now(),
    );
  }

  @override
  Future<List<PacienteResumo>> buscarPacientes(DateTime agora) async {
    final pacientes = await _ler(_carregarPacientes, const <(Paciente, DateTime?)>[]);
    if (pacientes.isEmpty) return const [];

    // Atendimentos de hoje ainda em aberto, para o selo "Hoje · 14:00".
    final dia = soData(agora);
    final hoje = await buscarAtendimentos(dia, somarDias(dia, 1));
    final hojePorPaciente = <String, Atendimento>{};
    for (final a in hoje) {
      if (!a.status.emAberto) continue;
      final atual = hojePorPaciente[a.pacienteId];
      if (atual == null || a.inicio.isBefore(atual.inicio)) {
        hojePorPaciente[a.pacienteId] = a;
      }
    }

    return [
      for (final (p, ultima) in pacientes)
        PacienteResumo(
          paciente: p,
          ultimaSessao: ultima,
          atendimentoHoje: hojePorPaciente[p.id],
        ),
    ];
  }

  @override
  Future<Paciente?> buscarPaciente(String id) async {
    final pacientes = await _ler(_carregarPacientes, const <(Paciente, DateTime?)>[]);
    for (final (p, _) in pacientes) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<List<Atendimento>> buscarAtendimentosDoPaciente(String pacienteId) {
    return _ler(
      () => _atendimentosApi.buscarAtendimentosDoPaciente(
        terapeutaId: _terapeutaId,
        pacienteId: pacienteId,
      ),
      const <Atendimento>[],
    );
  }

  @override
  Future<List<Disponibilidade>> buscarDisponibilidades() async {
    final lista = await _ler(
      () async => _disponibilidades ??=
          await _disponibilidadesApi.listar(_terapeutaId),
      const <Disponibilidade>[],
    );
    return List.of(lista);
  }

  // -------------------------------------------------------------- gravação

  @override
  Future<void> alterarStatus(
    String atendimentoId,
    StatusAtendimento status,
  ) async {
    await _atendimentosApi.salvarStatus(
      terapeutaId: _terapeutaId,
      atendimentoId: atendimentoId,
      status: status,
    );
    notifyListeners();
  }

  @override
  Future<Paciente> cadastrarPaciente({
    required String nome,
    required String telefone,
    String? email,
    DateTime? nascimento,
  }) async {
    final salvo = await _pacientesApi.cadastrar(
      Paciente(
        id: '',
        nome: nome,
        telefone: telefone,
        email: email,
        nascimento: nascimento,
      ),
      terapeutaId: _terapeutaId,
    );
    _pacientes?.insert(0, (salvo, null));
    notifyListeners();
    return salvo;
  }

  @override
  Future<Paciente> editarPaciente(Paciente paciente) async {
    await _pacientesApi.editar(paciente);
    final lista = _pacientes;
    if (lista != null) {
      final i = lista.indexWhere((x) => x.$1.id == paciente.id);
      if (i >= 0) lista[i] = (paciente, lista[i].$2);
    }
    notifyListeners();
    return paciente;
  }

  @override
  Future<void> adicionarDisponibilidades(List<Disponibilidade> novas) async {
    if (novas.isEmpty) return;
    final criadas =
        await _disponibilidadesApi.adicionar(_terapeutaId, novas);
    final destacar = novas.first.nova;
    _disponibilidades?.addAll([
      for (final d in criadas) destacar ? d.copyWith(nova: true) : d,
    ]);
    notifyListeners();
  }

  @override
  Future<void> atualizarDisponibilidade(Disponibilidade disponibilidade) async {
    await _disponibilidadesApi.atualizar(_terapeutaId, disponibilidade);
    final lista = _disponibilidades;
    if (lista != null) {
      final i = lista.indexWhere((x) => x.id == disponibilidade.id);
      if (i >= 0) lista[i] = disponibilidade;
    }
    notifyListeners();
  }

  @override
  Future<void> removerDisponibilidade(int id) async {
    await _disponibilidadesApi.remover(_terapeutaId, id);
    _disponibilidades?.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  /// Desfaz uma remoção: grava o horário de novo (recebe um id novo).
  @override
  Future<void> restaurarDisponibilidade(Disponibilidade disponibilidade) =>
      adicionarDisponibilidades([disponibilidade.copyWith(nova: false)]);

  /// Id provisório (negativo) para horários ainda não gravados; o banco
  /// devolve o id definitivo.
  @override
  int novoId() => --_idProvisorio;
}
