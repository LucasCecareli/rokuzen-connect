import 'package:flutter/foundation.dart';

import 'models/modelos.dart';
import 'repositorio_demonstracao.dart';

/// Contrato de acesso aos dados do app.
///
/// As telas só conversam com esta classe, nunca direto com o banco. Assim,
/// para ligar o app ao banco da Rokuzen basta criar outra implementação
/// (ex.: `RepositorioApi`, que chama o backend em `backend/`) e trocá-la em
/// [repositorio], lá embaixo. Nenhuma tela precisa mudar.
///
/// LEITURA: os métodos `buscar...` só leem dados.
///
/// AÇÕES LOCAIS: os métodos de alteração (cadastrar paciente, mudar status,
/// adicionar disponibilidade...) por enquanto alteram APENAS a memória do
/// aparelho. Nada é enviado ao banco até o grupo definir com o professor onde
/// esses dados devem ser gravados.
///
/// O repositório avisa as telas quando algo muda ([ChangeNotifier]), para que
/// Início, Agenda e Pacientes fiquem sempre sincronizados.
abstract class RokuzenRepository extends ChangeNotifier {
  // ---------------------------------------------------------------- leitura
  Future<Terapeuta> buscarTerapeuta();

  /// Atendimentos do terapeuta com início em [inicio] (inclusive) até [fim]
  /// (exclusive), em ordem de horário.
  Future<List<Atendimento>> buscarAtendimentos(DateTime inicio, DateTime fim);

  /// Próximo atendimento em aberto a partir de [aPartirDe].
  Future<Atendimento?> buscarProximoAtendimento(DateTime aPartirDe);

  /// Pacientes com o resumo usado na lista (última sessão, atendimento hoje).
  Future<List<PacienteResumo>> buscarPacientes(DateTime agora);

  Future<Paciente?> buscarPaciente(int id);

  /// Todos os atendimentos de um paciente, do mais recente para o mais antigo.
  Future<List<Atendimento>> buscarAtendimentosDoPaciente(int pacienteId);

  /// Disponibilidades para atendimentos particulares.
  Future<List<Disponibilidade>> buscarDisponibilidades();

  // ------------------------------------------- ações locais (só em memória)
  Future<void> alterarStatus(int atendimentoId, StatusAtendimento status);

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

/// Origem dos dados usada pelo app inteiro.
///
/// Hoje: dados de exemplo iguais aos do protótipo.
/// Depois: troque por uma implementação que lê o backend da Rokuzen.
final RokuzenRepository repositorio = RepositorioDemonstracao();
