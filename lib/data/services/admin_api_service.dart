import '../models/modelos.dart';
import 'api_cliente.dart';

// =====================================================================
// Modelos do administrador
// =====================================================================

class UnidadeAdmin {
  const UnidadeAdmin({required this.id, required this.nome});
  final String id;
  final String nome;
}

/// Uma duração possível de um serviço, com o preço.
class OpcaoServico {
  const OpcaoServico({required this.duracao, this.preco});
  final int duracao;
  final double? preco;
}

class ServicoAdmin {
  const ServicoAdmin({
    required this.id,
    required this.nome,
    required this.opcoes,
    this.combo,
    this.nomeCombo,
  });
  final String id;
  final String nome;
  final List<OpcaoServico> opcoes;

  /// Combo opcional (Auriculoterapia na Reflexologia Podal).
  final OpcaoServico? combo;
  final String? nomeCombo;
}

/// Um terapeuta no dia escolhido: período de trabalho e horários.
class AgendaTerapeuta {
  const AgendaTerapeuta({
    required this.id,
    required this.nome,
    required this.horarios,
    this.inicio,
    this.fim,
    this.motivo,
  });
  final String id;
  final String nome;

  /// Período em minutos (null se não trabalha nesse dia).
  final int? inicio;
  final int? fim;
  final String? motivo;

  /// Horários de início (minutos) e se estão livres.
  final List<(int, bool)> horarios;

  bool get temHorarioLivre => horarios.any((h) => h.$2);
}

class AgendamentoAdmin {
  const AgendamentoAdmin({
    required this.id,
    required this.inicio,
    required this.fim,
    required this.duracao,
    required this.paciente,
    required this.terapeuta,
    required this.servico,
    required this.unidade,
    required this.status,
  });
  final String id;
  final DateTime inicio;
  final DateTime fim;
  final int duracao;
  final String paciente;
  final String terapeuta;
  final String servico;
  final String unidade;
  final StatusAtendimento status;
}

/// Escala de trabalho do cadastro: dias (1 = seg ... 7 = dom) e horário
/// em minutos. No domingo vale o horário da Rokuzen (14h às 20h).
class EscalaAdmin {
  const EscalaAdmin({
    required this.dias,
    required this.inicio,
    required this.fim,
  });
  final Set<int> dias;
  final int inicio;
  final int fim;

  Map<String, Object> paraJson() => {
        'dias': (dias.toList()..sort()),
        'inicio': inicio,
        'fim': fim,
      };

  static EscalaAdmin? deJson(Object? json) {
    if (json is! Map) return null;
    final dias = json['dias'];
    final inicio = json['inicio'];
    final fim = json['fim'];
    if (dias is! List || inicio is! int || fim is! int) return null;
    return EscalaAdmin(
      dias: {for (final d in dias) if (d is int) d},
      inicio: inicio,
      fim: fim,
    );
  }
}

class TerapeutaAdmin {
  const TerapeutaAdmin({
    required this.id,
    required this.nome,
    required this.unidades,
    this.login,
    this.apelido,
    this.email,
    this.escala,
  });
  final String id;
  final String nome;
  final String? login;
  final String? apelido;
  final String? email;
  final List<String> unidades;

  /// Null = segue a escala do sistema (tabela events).
  final EscalaAdmin? escala;
}

class PacienteAdmin {
  const PacienteAdmin({
    required this.id,
    required this.nome,
    this.telefone,
    this.email,
    this.nascimento,
  });
  final String id;
  final String nome;
  final String? telefone;
  final String? email;
  final DateTime? nascimento;
}

// =====================================================================
// Chamadas ao backend (rotas /admin/*)
// =====================================================================

class AdminApiService {
  Future<List<UnidadeAdmin>> unidades({bool todas = false}) async {
    final dados = await ApiCliente.get(
        '/admin/unidades', {if (todas) 'todas': '1'});
    return [
      for (final u in _lista(dados['unidades']))
        UnidadeAdmin(id: '${u['id']}', nome: '${u['nome'] ?? 'Unidade'}'),
    ];
  }

  Future<List<ServicoAdmin>> servicos() async {
    final dados = await ApiCliente.get('/admin/servicos');
    return [
      for (final s in _lista(dados['servicos']))
        ServicoAdmin(
          id: '${s['id']}',
          nome: '${s['nome'] ?? 'Serviço'}',
          opcoes: [
            for (final o in _lista(s['opcoes']))
              if (o['duracao'] is int)
                OpcaoServico(
                  duracao: o['duracao'] as int,
                  preco: (o['preco'] as num?)?.toDouble(),
                ),
          ],
          combo: s['combo'] is Map && (s['combo'] as Map)['duracao'] is int
              ? OpcaoServico(
                  duracao: (s['combo'] as Map)['duracao'] as int,
                  preco: ((s['combo'] as Map)['preco'] as num?)?.toDouble(),
                )
              : null,
          nomeCombo: s['combo'] is Map
              ? (s['combo'] as Map)['nome'] as String?
              : null,
        ),
    ];
  }

  Future<List<AgendaTerapeuta>> agendaTerapeutas({
    required String unidadeId,
    required DateTime dia,
    required int duracao,
    required DateTime agora,
  }) async {
    final dados = await ApiCliente.get('/admin/agenda-terapeutas', {
      'unidade': unidadeId,
      'data': _data(dia),
      'duracao': '$duracao',
      'agora': _dataHora(agora),
    });
    return [
      for (final t in _lista(dados['terapeutas']))
        AgendaTerapeuta(
          id: '${t['id']}',
          nome: '${t['nome'] ?? 'Terapeuta'}',
          inicio: t['inicio'] as int?,
          fim: t['fim'] as int?,
          motivo: t['motivo'] as String?,
          horarios: [
            for (final h in _lista(t['horarios']))
              if (h['minutos'] is int)
                (h['minutos'] as int, h['livre'] == true),
          ],
        ),
    ];
  }

  Future<List<AgendamentoAdmin>> agendamentos({
    required DateTime dia,
    String? unidadeId,
    required DateTime agora,
  }) async {
    final dados = await ApiCliente.get('/admin/agendamentos', {
      'data': _data(dia),
      'unidade': ?unidadeId,
      'agora': _dataHora(agora),
    });
    final lista = <AgendamentoAdmin>[];
    for (final a in _lista(dados['agendamentos'])) {
      final ini = DateTime.tryParse('${a['inicio']}');
      final fim = DateTime.tryParse('${a['fim']}');
      if (ini == null) continue;
      lista.add(AgendamentoAdmin(
        id: '${a['id']}',
        inicio: ini,
        fim: fim ?? ini.add(const Duration(hours: 1)),
        duracao: a['duracao'] is int ? a['duracao'] as int : 60,
        paciente: '${a['paciente'] ?? 'Paciente'}',
        terapeuta: '${a['terapeuta'] ?? 'Terapeuta'}',
        servico: '${a['servico'] ?? 'Serviço'}',
        unidade: '${a['unidade'] ?? ''}',
        status: StatusAtendimento.values.firstWhere(
          (s) => s.name == a['status'],
          orElse: () => StatusAtendimento.confirmado,
        ),
      ));
    }
    return lista;
  }

  Future<void> agendar({
    required String unidadeId,
    required String servicoId,
    required int duracao,
    required bool comCombo,
    required String terapeutaId,
    required String pacienteId,
    required DateTime inicio,
    required DateTime agora,
  }) async {
    await ApiCliente.post('/admin/agendamentos', {
      'unidade': unidadeId,
      'servico': servicoId,
      'duracao': duracao,
      'combo': comCombo,
      'terapeuta': terapeutaId,
      'paciente': pacienteId,
      'inicio': _dataHora(inicio),
      'agora': _dataHora(agora),
    });
  }

  Future<void> cancelar(String agendamentoId) async {
    await ApiCliente.put(
      '/admin/agendamentos/${Uri.encodeComponent(agendamentoId)}/cancelar',
      const {},
    );
  }

  // --------------------------------------------------------- terapeutas

  Future<List<TerapeutaAdmin>> terapeutas() async {
    final dados = await ApiCliente.get('/admin/terapeutas');
    return [
      for (final t in _lista(dados['terapeutas']))
        TerapeutaAdmin(
          id: '${t['id']}',
          nome: '${t['nome'] ?? 'Sem nome'}',
          login: t['login'] as String?,
          apelido: t['apelido'] as String?,
          email: t['email'] as String?,
          unidades: [
            for (final u in (t['unidades'] as List? ?? const [])) '$u',
          ],
          escala: EscalaAdmin.deJson(t['escala']),
        ),
    ];
  }

  /// Cadastra (sem [id]) ou edita um terapeuta. [senha] nula na edição
  /// mantém a senha atual.
  Future<void> salvarTerapeuta({
    String? id,
    required String nome,
    required String login,
    required List<String> unidades,
    String? apelido,
    String? email,
    String? senha,
    EscalaAdmin? escala,
  }) async {
    final corpo = {
      'nome': nome,
      'login': login,
      'unidades': unidades,
      'apelido': apelido,
      'email': email,
      'senha': senha,
      'escala': escala?.paraJson(),
    };
    if (id == null) {
      await ApiCliente.post('/admin/terapeutas', corpo);
    } else {
      await ApiCliente.put(
          '/admin/terapeutas/${Uri.encodeComponent(id)}', corpo);
    }
  }

  Future<void> excluirTerapeuta(String id, DateTime agora) async {
    await ApiCliente.delete('/admin/terapeutas/${Uri.encodeComponent(id)}',
        {'agora': _dataHora(agora)});
  }

  // ---------------------------------------------------------- pacientes

  /// Pacientes (até 60) e o total encontrado.
  Future<(int, List<PacienteAdmin>)> pacientes({String? busca}) async {
    final dados = await ApiCliente.get('/admin/pacientes', {
      if (busca != null && busca.trim().isNotEmpty) 'busca': busca.trim(),
    });
    final lista = [
      for (final p in _lista(dados['pacientes'])) _paciente(p),
    ];
    final total = dados['total'] is int ? dados['total'] as int : lista.length;
    return (total, lista);
  }

  Future<PacienteAdmin> salvarPaciente({
    String? id,
    required String nome,
    required String telefone,
    String? email,
    DateTime? nascimento,
  }) async {
    final corpo = {
      'nome': nome,
      'telefone': telefone,
      'email': email,
      'nascimento': nascimento == null ? null : _data(nascimento),
    };
    if (id == null) {
      final dados = await ApiCliente.post('/admin/pacientes', corpo);
      final p = dados['paciente'];
      if (p is! Map<String, dynamic>) {
        throw const ApiException('Resposta inválida do servidor.');
      }
      return _paciente(p);
    }
    await ApiCliente.put('/admin/pacientes/${Uri.encodeComponent(id)}', corpo);
    return PacienteAdmin(
      id: id,
      nome: nome,
      telefone: telefone,
      email: email,
      nascimento: nascimento,
    );
  }

  Future<void> excluirPaciente(String id, DateTime agora) async {
    await ApiCliente.delete('/admin/pacientes/${Uri.encodeComponent(id)}',
        {'agora': _dataHora(agora)});
  }

  // ------------------------------------------------------------ apoio

  PacienteAdmin _paciente(Map<String, dynamic> p) => PacienteAdmin(
        id: '${p['id']}',
        nome: '${p['nome'] ?? 'Sem nome'}',
        telefone: p['telefone'] as String?,
        email: p['email'] as String?,
        nascimento: p['nascimento'] is String
            ? DateTime.tryParse(p['nascimento'] as String)
            : null,
      );

  static List<Map<String, dynamic>> _lista(Object? valor) {
    if (valor is! List) {
      throw const ApiException('Resposta inválida do servidor.');
    }
    return [
      for (final item in valor)
        if (item is Map<String, dynamic>) item,
    ];
  }

  static String _dois(int n) => n.toString().padLeft(2, '0');

  static String _data(DateTime d) =>
      '${d.year}-${_dois(d.month)}-${_dois(d.day)}';

  static String _dataHora(DateTime d) =>
      '${_data(d)}T${_dois(d.hour)}:${_dois(d.minute)}:00';
}

/// Administrador conectado (só em memória, enquanto o app está aberto).
abstract final class SessaoAdmin {
  static String? nome;

  static bool get ativa => ApiCliente.adminId != null;

  static void entrar({required String id, required String nome}) {
    ApiCliente.adminId = id;
    SessaoAdmin.nome = nome;
  }

  static void sair() {
    ApiCliente.adminId = null;
    nome = null;
  }
}
