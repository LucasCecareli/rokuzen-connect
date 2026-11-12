import 'dart:convert';

import 'package:backend/config/database.dart';

class PacienteRepository {
  /// Pacientes da terapeuta: quem já teve (ou tem marcado) atendimento com
  /// ela, mais quem ela cadastrou pelo app. Cada um vem com a data da última
  /// sessão com ela antes de [agora].
  Future<List<Map<String, String?>>> listarPacientes({
    required String terapeutaId,
    String? agora,
  }) async {
    final connection = await Database.connect();

    try {
      final result = await connection.execute(
        '''
        SELECT
          c.cli_ukey,
          c.cli_004_c,
          c.cli_012_c,
          c.cli_001_c,
          c.cli_017_c,
          u.ultima AS ultima_sessao
        FROM cli AS c
        LEFT JOIN (
          SELECT a.cli_ukey, MAX(a.atd_002_c) AS ultima
          FROM atd a
          WHERE (
            a.usr_ukey = :terapeutaId
            OR a.usr_ukey = (SELECT usr_001_c FROM usr WHERE usr_ukey = :terapeutaId LIMIT 1)
            OR a.usr_ukey = (SELECT usr_ukey FROM usr WHERE usr_001_c = :terapeutaId LIMIT 1)
          )
          AND a.atd_002_c < :agora
          GROUP BY a.cli_ukey
        ) u ON u.cli_ukey = c.cli_ukey
        WHERE c.cli_ukey IN (
            SELECT a2.cli_ukey
            FROM atd a2
            WHERE a2.cli_ukey IS NOT NULL
              AND (
                a2.usr_ukey = :terapeutaId
                OR a2.usr_ukey = (SELECT usr_001_c FROM usr WHERE usr_ukey = :terapeutaId LIMIT 1)
                OR a2.usr_ukey = (SELECT usr_ukey FROM usr WHERE usr_001_c = :terapeutaId LIMIT 1)
              )
          )
          OR c.cli_ukey IN (
            SELECT pt.cli_ukey
            FROM app_paciente_terapeuta pt
            WHERE pt.usr_ukey = :terapeutaId
          )
        ORDER BY TRIM(c.cli_004_c)
        ''',
        {
          'terapeutaId': terapeutaId.trim(),
          'agora': _formatarDataHora(agora),
        },
      );

      return result.rows.map(_mapear).toList();
    } finally {
      await connection.close();
    }
  }

  /// Cadastra um cliente novo, ligado à terapeuta que cadastrou, e devolve
  /// o registro salvo.
  Future<Map<String, String?>> cadastrar(
    DadosPaciente dados, {
    required String terapeutaId,
  }) async {
    final connection = await Database.connect();
    try {
      // A tabela cli não tem auto incremento: o id é gerado aqui.
      final id = 'APP${DateTime.now().millisecondsSinceEpoch}';
      await connection.execute(
        '''
        INSERT INTO cli (cli_ukey, cli_004_c, cli_012_c, cli_001_c, cli_017_c)
        VALUES (:id, :nome, :telefone, :email, :nascimento)
        ''',
        {
          'id': id,
          'nome': dados.nome,
          'telefone': dados.telefone,
          'email': dados.email,
          'nascimento': dados.nascimentoSql,
        },
      );
      // Liga o paciente à terapeuta (aparece na lista dela mesmo antes do
      // primeiro atendimento).
      await connection.execute(
        '''
        INSERT INTO app_paciente_terapeuta (cli_ukey, usr_ukey)
        VALUES (:id, :terapeutaId)
        ''',
        {'id': id, 'terapeutaId': terapeutaId},
      );
      return {
        'id': id,
        'nome': dados.nome,
        'telefone': dados.telefone,
        'email': dados.email,
        'nascimento': dados.nascimento,
        'ultimaSessao': null,
      };
    } finally {
      await connection.close();
    }
  }

  /// Atualiza nome, telefone, e-mail e nascimento. Devolve false se o
  /// cliente não existir.
  Future<bool> atualizar(String id, DadosPaciente dados) async {
    final connection = await Database.connect();
    try {
      final existe = await connection.execute(
        'SELECT cli_ukey FROM cli WHERE cli_ukey = :id LIMIT 1',
        {'id': id},
      );
      if (existe.rows.isEmpty) return false;

      await connection.execute(
        '''
        UPDATE cli
        SET cli_004_c = :nome,
            cli_012_c = :telefone,
            cli_001_c = :email,
            cli_017_c = :nascimento
        WHERE cli_ukey = :id
        ''',
        {
          'id': id,
          'nome': dados.nome,
          'telefone': dados.telefone,
          'email': dados.email,
          'nascimento': dados.nascimentoSql,
        },
      );
      return true;
    } finally {
      await connection.close();
    }
  }

  Map<String, String?> _mapear(dynamic row) {
    return <String, String?>{
      'id': row.colByName('cli_ukey'),
      'nome': _texto(row.colByName('cli_004_c')),
      'telefone': _texto(row.colByName('cli_012_c')),
      'email': _texto(row.colByName('cli_001_c')),
      'nascimento': _dataOuNulo(row.colByName('cli_017_c')),
      'ultimaSessao': _dataHoraOuNulo(row.colByName('ultima_sessao')),
    };
  }

  /// "2026-11-11T22:50:00.000" (vindo do app) -> "2026-11-11 22:50:00"
  String _formatarDataHora(String? valor) {
    final data = valor == null ? null : DateTime.tryParse(valor);
    final d = data ?? DateTime.now();
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${dois(d.month)}-${dois(d.day)} '
        '${dois(d.hour)}:${dois(d.minute)}:${dois(d.second)}';
  }

  String? _texto(String? valor) {
    if (valor == null) return null;
    var texto = valor.trim();
    if (texto.contains('Ã') || texto.contains('Â')) {
      try {
        texto = utf8.decode(latin1.encode(texto)).trim();
      } catch (_) {
        // Se não der para consertar, mantém o texto como veio.
      }
    }
    return texto.isEmpty ? null : texto;
  }

  /// Datas zeradas ("0000-00-00") ou de enchimento ("1900-01-01",
  /// "0001-01-01") significam "sem data de nascimento".
  /// Devolve só a data, no formato AAAA-MM-DD.
  String? _dataOuNulo(String? valor) {
    if (valor == null || valor.length < 10) return null;
    final ano = int.tryParse(valor.substring(0, 4)) ?? 0;
    if (ano <= 1900) return null;
    return valor.substring(0, 10);
  }

  /// "2026-11-10 14:00:00" -> "2026-11-10T14:00:00"
  String? _dataHoraOuNulo(String? valor) {
    if (valor == null || valor.length < 10) return null;
    return valor.replaceFirst(' ', 'T');
  }
}

/// Dados do formulário de paciente, já validados.
class DadosPaciente {
  const DadosPaciente({
    required this.nome,
    required this.telefone,
    this.email,
    this.nascimento,
  });

  final String nome;
  final String telefone;
  final String? email;

  /// AAAA-MM-DD
  final String? nascimento;

  String? get nascimentoSql =>
      nascimento == null ? null : '$nascimento 00:00:00';

  /// Lê e valida o JSON do app. Devolve null se os dados forem inválidos.
  static DadosPaciente? deJson(Object? json) {
    if (json is! Map) return null;
    final nome = json['nome'];
    final telefone = json['telefone'];
    final email = json['email'];
    final nascimento = json['nascimento'];

    if (nome is! String || nome.trim().isEmpty || nome.trim().length > 100) {
      return null;
    }
    if (telefone is! String ||
        telefone.trim().isEmpty ||
        telefone.trim().length > 20) {
      return null;
    }
    if (email != null && (email is! String || email.length > 150)) {
      return null;
    }

    String? nasc;
    if (nascimento is String && nascimento.isNotEmpty) {
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(nascimento) ||
          DateTime.tryParse(nascimento) == null) {
        return null;
      }
      nasc = nascimento;
    }

    final emailTexto =
        email is String && email.trim().isNotEmpty ? email.trim() : null;

    return DadosPaciente(
      nome: nome.trim(),
      telefone: telefone.trim(),
      email: emailTexto,
      nascimento: nasc,
    );
  }
}
