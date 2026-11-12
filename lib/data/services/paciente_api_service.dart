import '../models/modelos.dart';
import 'api_cliente.dart';

/// Pacientes (tabela cli) através do backend.
class PacienteApiService {
  /// Lista os pacientes com a data da última sessão com a terapeuta.
  Future<List<(Paciente, DateTime?)>> listarPacientes({
    required String terapeutaId,
    required DateTime agora,
  }) async {
    final dados = await ApiCliente.get('/pacientes', {
      'terapeuta': terapeutaId,
      'agora': agora.toIso8601String(),
    });
    final lista = dados['pacientes'];
    if (lista is! List) {
      throw const ApiException('Resposta inválida do servidor.');
    }

    return [
      for (final item in lista)
        if (item is Map<String, dynamic>)
          (
            _paraPaciente(item),
            DateTime.tryParse('${item['ultimaSessao']}'),
          ),
    ];
  }

  /// Cadastra o paciente ligado à terapeuta (aparece na lista dela).
  Future<Paciente> cadastrar(Paciente p, {required String terapeutaId}) async {
    final dados = await ApiCliente.post('/pacientes', {
      'terapeuta': terapeutaId,
      ..._paraJson(p),
    });
    final salvo = dados['paciente'];
    if (salvo is! Map<String, dynamic>) {
      throw const ApiException('Resposta inválida do servidor.');
    }
    return _paraPaciente(salvo, novo: true);
  }

  Future<void> editar(Paciente p) async {
    await ApiCliente.put(
      '/pacientes/${Uri.encodeComponent(p.id)}',
      _paraJson(p),
    );
  }

  Map<String, Object?> _paraJson(Paciente p) => {
        'nome': p.nome,
        'telefone': p.telefone,
        'email': p.email,
        'nascimento': p.nascimento == null
            ? null
            : '${p.nascimento!.year.toString().padLeft(4, '0')}-'
                '${p.nascimento!.month.toString().padLeft(2, '0')}-'
                '${p.nascimento!.day.toString().padLeft(2, '0')}',
      };

  Paciente _paraPaciente(Map<String, dynamic> json, {bool novo = false}) {
    final nascimento = json['nascimento'];

    return Paciente(
      id: '${json['id']}',
      nome: (json['nome'] as String?) ?? 'Sem nome',
      telefone: (json['telefone'] as String?) ?? '',
      email: json['email'] as String?,
      nascimento: nascimento is String ? DateTime.tryParse(nascimento) : null,
      novo: novo,
    );
  }
}
