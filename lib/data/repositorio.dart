import 'package:flutter/foundation.dart';

import 'models/modelos.dart';
import 'repositorio_api.dart';

/// Contrato de acesso aos dados do app.
///
/// As telas só conversam com esta classe, nunca direto com o banco. Assim,
/// para ligar o app ao banco da Rokuzen basta criar outra implementação
/// (ex.: `RepositorioApi`, que chama o backend em `backend/`) e trocá-la em
/// [repositorio], lá embaixo. Nenhuma tela precisa mudar.
///
/// No modo real ([RepositorioApi]) leitura e gravação vão para o backend,
/// que fala com o banco do grupo. Se o servidor não responder, as leituras
/// devolvem listas vazias e [erroConexao] recebe uma mensagem (a tela
/// principal mostra um aviso com "Tentar novamente"). As gravações lançam
/// exceção, para o formulário mostrar o erro.
///
/// O repositório avisa as telas quando algo muda ([ChangeNotifier]), para que
/// Início, Agenda e Pacientes fiquem sempre sincronizados.
abstract class RokuzenRepository extends ChangeNotifier {
  Terapeuta? get terapeutaAtual;
  void definirTerapeutaLogado(Terapeuta terapeuta);

  /// Mensagem de falha de conexão com o servidor (null quando está tudo ok).
  /// Fica separada dos avisos do repositório para não recarregar as telas
  /// em loop quando o servidor está fora.
  final ValueNotifier<String?> erroConexao = ValueNotifier<String?>(null);

  /// "Tentar novamente": limpa o erro e pede para as telas recarregarem.
  void recarregar() {
    erroConexao.value = null;
    notifyListeners();
  }

  /// Esquece os dados da terapeuta ao sair da conta.
  void sair() {
    erroConexao.value = null;
  }

  // ---------------------------------------------------------------- leitura
  Future<Terapeuta> buscarTerapeuta();

  /// Atendimentos do terapeuta com início em [inicio] (inclusive) até [fim]
  /// (exclusive), em ordem de horário.
  Future<List<Atendimento>> buscarAtendimentos(DateTime inicio, DateTime fim);

  /// Próximo atendimento em aberto a partir de [aPartirDe].
  Future<Atendimento?> buscarProximoAtendimento(DateTime aPartirDe);

  /// Pacientes com o resumo usado na lista (última sessão, atendimento hoje).
  Future<List<PacienteResumo>> buscarPacientes(DateTime agora);

  Future<Paciente?> buscarPaciente(String id);

  /// Todos os atendimentos de um paciente, do mais recente para o mais antigo.
  Future<List<Atendimento>> buscarAtendimentosDoPaciente(String pacienteId);

  /// Disponibilidades para atendimentos particulares.
  Future<List<Disponibilidade>> buscarDisponibilidades();

  // -------------------------------------------------------------- gravação
  Future<void> alterarStatus(String atendimentoId, StatusAtendimento status);

  Future<Paciente> cadastrarPaciente({
    required String nome,
    required String telefone,
    String? email,
    DateTime? nascimento,
  });

  Future<Paciente> editarPaciente(Paciente paciente);

  Future<void> adicionarDisponibilidades(List<Disponibilidade> novas);

  Future<void> atualizarDisponibilidade(Disponibilidade disponibilidade);

  Future<void> removerDisponibilidade(int id);

  /// Desfaz uma remoção.
  Future<void> restaurarDisponibilidade(Disponibilidade disponibilidade);

  /// Gera um id provisório para itens criados no aparelho.
  int novoId();
}

/// Origem dos dados usada pelo app inteiro: o backend do grupo.
/// (Para apresentar sem servidor, troque por `RepositorioDemonstracao()`.)
final RokuzenRepository repositorio = RepositorioApi();
