import 'dart:convert';

import 'package:backend/config/database.dart';

/// Recusa de uma operação do administrador, com mensagem para a tela.
class AdminRecusa implements Exception {
  const AdminRecusa(this.mensagem, {this.codigo = 409});
  final String mensagem;
  final int codigo;

  @override
  String toString() => mensagem;
}

/// Tudo o que o login de administrador (admrokuzen) faz no banco:
/// catálogo (unidades e serviços), disponibilidade de terapeutas,
/// agendamentos e cadastro de terapeutas e pacientes.
class AdminRepository {
  // ----------------------------------------------------------- acesso

  /// Confere login e senha do administrador.
  Future<Map<String, String>?> autenticar(String login, String senha) async {
    final connection = await Database.connect();
    try {
      final result = await connection.execute(
        '''
        SELECT u.usr_ukey, u.usr_002_c, u.usr_003_c
        FROM usr u
        INNER JOIN app_admin a ON a.usr_ukey = u.usr_ukey
        WHERE u.usr_001_c = :login
        ''',
        {'login': login.trim()},
      );
      for (final row in result.rows) {
        if (row.colByName('usr_003_c') == senha) {
          return {
            'id': row.colByName('usr_ukey') ?? '',
            'nome': _texto(row.colByName('usr_002_c')) ?? 'Administrador',
            'login': login.trim(),
            'perfil': 'admin',
          };
        }
      }
      return null;
    } finally {
      await connection.close();
    }
  }

  /// Administradores já confirmados (evita uma consulta a cada chamada).
  static final _adminsConfirmados = <String>{};

  Future<bool> ehAdmin(String usuarioId) async {
    if (_adminsConfirmados.contains(usuarioId)) return true;
    final connection = await Database.connect();
    try {
      final result = await connection.execute(
        'SELECT 1 FROM app_admin WHERE usr_ukey = :id LIMIT 1',
        {'id': usuarioId},
      );
      if (result.rows.isNotEmpty) _adminsConfirmados.add(usuarioId);
      return result.rows.isNotEmpty;
    } finally {
      await connection.close();
    }
  }

  // ---------------------------------------------------------- catálogo

  /// Unidades. Com [soComServicos], só as que têm tabela de preços.
  Future<List<Map<String, String?>>> unidades({bool soComServicos = true}) async {
    final connection = await Database.connect();
    try {
      final result = await connection.execute(soComServicos
          ? '''
            SELECT u.und_ukey, u.und_001_c
            FROM und u
            WHERE EXISTS (SELECT 1 FROM tpr t WHERE t.und_ukey = u.und_ukey)
            ORDER BY u.und_001_c
            '''
          : 'SELECT und_ukey, und_001_c FROM und ORDER BY und_001_c');
      return [
        for (final row in result.rows)
          {
            'id': row.colByName('und_ukey'),
            'nome': _nomeUnidade(row.colByName('und_001_c')),
          },
      ];
    } finally {
      await connection.close();
    }
  }

  /// Serviços como no agendamento do site da Rokuzen: os 4 tipos, cada um
  /// com as durações e preços do site. A Reflexologia Podal pode ganhar o
  /// combo de Auriculoterapia (+10 min).
  static const catalogo = [
    (
      id: 'quick',
      nome: 'Quick Massage',
      palavra: 'quick',
      opcoes: [(15, 55.0), (30, 88.0)],
      combo: false,
    ),
    (
      id: 'maca',
      nome: 'Maca',
      palavra: 'maca',
      opcoes: [(30, 120.0), (45, 170.0), (60, 208.0), (90, 308.0), (120, 400.0)],
      combo: false,
    ),
    (
      id: 'reflexologia',
      nome: 'Reflexologia Podal',
      palavra: 'reflex',
      opcoes: [(20, 88.0), (30, 105.0), (40, 125.0), (60, 169.0)],
      combo: true,
    ),
    (
      id: 'auriculoterapia',
      nome: 'Auriculoterapia',
      palavra: 'auricul',
      opcoes: [(10, 72.0)],
      combo: false,
    ),
  ];

  /// Combo de Auriculoterapia oferecido junto com a Reflexologia Podal.
  static const combo = (duracao: 10, preco: 50.0);

  List<Map<String, Object?>> servicos() => [
        for (final s in catalogo)
          {
            'id': s.id,
            'nome': s.nome,
            'opcoes': [
              for (final (d, p) in s.opcoes) {'duracao': d, 'preco': p},
            ],
            'combo': s.combo
                ? {
                    'nome': 'Auriculoterapia - Combo',
                    'duracao': combo.duracao,
                    'preco': combo.preco,
                  }
                : null,
          },
      ];

  // ------------------------------------------- terapeutas e horários

  /// Terapeutas da unidade no [dia], com o período de trabalho e os
  /// horários de início (de hora em hora, como no site) para uma sessão de
  /// [duracao] minutos.
  ///
  /// Período de cada terapeuta, nesta ordem:
  /// 1. a escala do sistema (events) nesse dia;
  /// 2. a escala definida no cadastro do terapeuta (app_escala);
  /// 3. se a escala do sistema já cobre esse dia na unidade, quem não está
  ///    nela não trabalha;
  /// 4. para datas que a escala ainda não alcança, o turno mais recente do
  ///    terapeuta nesta unidade (de preferência no mesmo dia da semana);
  /// 5. sem nada disso, o terapeuta fica sem horários ("Sem escala").
  ///
  /// Um horário fica ocupado se cruza outro atendimento do terapeuta
  /// (cancelados e faltas não contam) ou se já passou.
  Future<List<Map<String, Object?>>> agendaTerapeutas({
    required String unidadeId,
    required DateTime dia,
    required int duracao,
    required DateTime agora,
  }) async {
    final connection = await Database.connect();
    try {
      final lista =
          await _agenda(connection, unidadeId, dia, duracao, agora);
      return [
        for (final t in lista)
          {
            'id': t.id,
            'nome': t.nome,
            'inicio': t.inicio,
            'fim': t.fim,
            'motivo': t.motivo,
            'horarios': [
              for (final (m, livre) in t.horarios)
                {'minutos': m, 'livre': livre},
            ],
          },
      ];
    } finally {
      await connection.close();
    }
  }

  Future<
      List<
          ({
            String id,
            String nome,
            int? inicio,
            int? fim,
            String? motivo,
            List<(int, bool)> horarios,
          })>> _agenda(
    dynamic connection,
    String unidadeId,
    DateTime diaInformado,
    int duracao,
    DateTime agora,
  ) async {
    final dia =
        DateTime(diaInformado.year, diaInformado.month, diaInformado.day);
    final seguinte = dia.add(const Duration(days: 1));

    // Terapeutas da unidade: vínculo em usrXund ou escala recente nela.
    final terapeutas = await connection.execute(
      '''
      SELECT u.usr_ukey, u.usr_001_c, u.usr_002_c, u.usr_038_c
      FROM usr u
      WHERE u.usr_010_c = '3'
        AND (
          u.usr_ukey IN (SELECT ux.usr_ukey FROM usrXund ux WHERE ux.und_ukey = :unidade)
          OR u.usr_ukey IN (
            SELECT e.title FROM events e
            WHERE e.und_ukey = :unidade AND e.start >= :desde
          )
        )
      ''',
      {
        'unidade': unidadeId,
        'desde': _sql(dia.subtract(const Duration(days: 120))),
      },
    );
    final pessoas = <({String id, String? login, String nome})>[];
    // Na escala (events), o campo title identifica o terapeuta. Pode estar
    // com o id, o login, o apelido ou o nome: aceita qualquer um deles.
    final donoPorTitulo = <String, String>{};
    for (final row in terapeutas.rows) {
      final id = (row.colByName('usr_ukey') as String?)?.trim();
      if (id == null || id.isEmpty) continue;
      final login = (row.colByName('usr_001_c') as String?)?.trim();
      final apelido = _texto(row.colByName('usr_038_c'));
      final nomeCompleto = _texto(row.colByName('usr_002_c'));
      pessoas.add((
        id: id,
        login: login,
        nome: apelido ?? nomeCompleto ?? 'Terapeuta',
      ));
      for (final chave in [id, login, apelido, nomeCompleto]) {
        if (chave == null || chave.isEmpty) continue;
        donoPorTitulo.putIfAbsent(_chave(chave), () => id);
      }
    }
    if (pessoas.isEmpty) return [];

    // Escala: o dia escolhido e os 120 dias anteriores (para o turno
    // padrão de quem ainda não tem escala lançada nesse dia).
    final escala = await connection.execute(
      '''
      SELECT e.title, e.start, e.end, e.und_ukey
      FROM events e
      WHERE (e.start >= :dia AND e.start < :ate)
         OR (e.und_ukey = :unidade AND e.start >= :desde AND e.start < :dia)
      ORDER BY e.start DESC
      ''',
      {
        // O dia inteiro (todas as unidades) e o histórico só desta unidade:
        // bem menos linhas do que todo o histórico de todas as unidades.
        'dia': _sql(dia),
        'unidade': unidadeId,
        'desde': _sql(dia.subtract(const Duration(days: 120))),
        'ate': _sql(seguinte),
      },
    );
    final noDia = <String, List<({int ini, int fim, String? und})>>{};
    final historico = <String, List<({DateTime ini, int iniMin, int fimMin})>>{};
    var diaCoberto = false;
    for (final row in escala.rows) {
      final tituloBruto = row.colByName('title') as String?;
      final titulo =
          tituloBruto == null ? null : donoPorTitulo[_chave(tituloBruto)];
      final ini = _data(row.colByName('start'));
      final f = _data(row.colByName('end'));
      if (ini == null || f == null || !f.isAfter(ini)) continue;
      final und = (row.colByName('und_ukey') as String?)?.trim();
      // Qualquer escala lançada nesta unidade no dia mostra que o dia já
      // está coberto pela escala.
      if (!ini.isBefore(dia) && und == unidadeId) diaCoberto = true;
      if (titulo == null) continue;
      final iniMin = ini.hour * 60 + ini.minute;
      final fimMin = f.day != ini.day ? 24 * 60 : f.hour * 60 + f.minute;
      if (!ini.isBefore(dia)) {
        noDia.putIfAbsent(titulo, () => []).add(
            (ini: iniMin, fim: fimMin, und: und));
      } else if (und == unidadeId) {
        historico.putIfAbsent(titulo, () => []).add(
            (ini: ini, iniMin: iniMin, fimMin: fimMin));
      }
    }

    // Se há escala na unidade nesse dia mas nenhuma é de um terapeuta
    // reconhecido, trata o dia como sem escala (usa o turno padrão).
    if (diaCoberto &&
        !pessoas.any((t) =>
            (noDia[t.id] ?? const []).any((e) => e.und == unidadeId))) {
      diaCoberto = false;
    }

    // Atendimentos do dia que ocupam horário.
    final ocupados = await connection.execute(
      '''
      SELECT a.usr_ukey, a.atd_002_c, a.atd_003_c, a.atd_001_c
      FROM atd a
      LEFT JOIN app_status_atendimento st ON st.atd_ukey = a.atd_ukey
      WHERE a.atd_002_c >= :desde
        AND a.atd_002_c < :ate
        AND (st.status IS NULL OR st.status NOT IN ('cancelado', 'faltou'))
      ''',
      {
        'desde': _sql(dia.subtract(const Duration(hours: 12))),
        'ate': _sql(seguinte),
      },
    );
    final ocupacao = <String, List<({DateTime ini, DateTime fim})>>{};
    for (final row in ocupados.rows) {
      final dono = (row.colByName('usr_ukey') as String?)?.trim();
      final ini = _data(row.colByName('atd_002_c'));
      if (dono == null || ini == null) continue;
      var f = _data(row.colByName('atd_003_c'));
      if (f == null || !f.isAfter(ini)) {
        final d = int.tryParse(row.colByName('atd_001_c') ?? '') ?? 60;
        f = ini.add(Duration(minutes: d > 0 ? d : 60));
      }
      ocupacao.putIfAbsent(dono, () => []).add((ini: ini, fim: f));
    }

    // Escala definida no cadastro do terapeuta pelo administrador.
    final escalasCadastro = await _escalasCadastro(connection);

    final resultado = <({
      String id,
      String nome,
      int? inicio,
      int? fim,
      String? motivo,
      List<(int, bool)> horarios,
    })>[];

    for (final t in pessoas) {
      int? ini;
      int? fim;
      String? motivo;

      // Ordem: 1) escala do sistema (events) no dia; 2) escala do
      // cadastro; 3) se o dia já tem escala lançada, quem não está nela
      // não trabalha; 4) turno mais recente do terapeuta nesta unidade;
      // 5) sem nada disso, fica sem horários.
      final turnosDia = noDia[t.id] ?? const [];
      final aqui =
          turnosDia.where((e) => e.und == null || e.und == unidadeId).toList();
      final cadastro = escalasCadastro[t.id];
      if (aqui.isNotEmpty) {
        ini = aqui.map((e) => e.ini).reduce((a, b) => a < b ? a : b);
        fim = aqui.map((e) => e.fim).reduce((a, b) => a > b ? a : b);
      } else if (turnosDia.isNotEmpty) {
        motivo = 'Escalado em outra unidade';
      } else if (cadastro != null) {
        final turno = cadastro.turnoDe(dia);
        if (turno == null) {
          motivo = 'Folga neste dia';
        } else {
          (ini, fim) = turno;
        }
      } else if (diaCoberto) {
        motivo = 'Sem expediente neste dia';
      } else {
        final passados = historico[t.id] ?? const [];
        final mesmoDiaSemana =
            passados.where((e) => e.ini.weekday == dia.weekday);
        final base = mesmoDiaSemana.isNotEmpty
            ? mesmoDiaSemana.first
            : passados.isNotEmpty
                ? passados.first
                : null;
        if (base != null) {
          ini = base.iniMin;
          fim = base.fimMin;
        } else {
          // Sem escala nenhuma: não inventa horário. O administrador pode
          // definir a escala no cadastro do terapeuta.
          motivo = 'Sem escala definida (defina em Terapeutas)';
        }
      }

      final horarios = <(int, bool)>[];
      if (ini != null && fim != null) {
        final ocupadoT = [
          ...?ocupacao[t.id],
          if (t.login != null) ...?ocupacao[t.login!],
        ];
        // De hora em hora, a partir da hora cheia do início do turno.
        for (var m = (ini + 59) ~/ 60 * 60; m + duracao <= fim; m += 60) {
          final iniSessao = dia.add(Duration(minutes: m));
          final fimSessao = iniSessao.add(Duration(minutes: duracao));
          final conflito = ocupadoT.any(
              (o) => o.ini.isBefore(fimSessao) && o.fim.isAfter(iniSessao));
          final passou = !iniSessao.isAfter(agora);
          horarios.add((m, !conflito && !passou));
        }
        if (horarios.isEmpty) {
          motivo = 'Período curto para esta duração';
        } else if (!horarios.any((h) => h.$2)) {
          motivo = 'Sem horários livres';
        }
      }

      resultado.add((
        id: t.id,
        nome: t.nome,
        inicio: ini,
        fim: fim,
        motivo: motivo,
        horarios: horarios,
      ));
    }

    // Quem tem horário livre primeiro; depois por nome.
    resultado.sort((a, b) {
      final la = a.horarios.any((h) => h.$2) ? 0 : 1;
      final lb = b.horarios.any((h) => h.$2) ? 0 : 1;
      if (la != lb) return la.compareTo(lb);
      return a.nome.compareTo(b.nome);
    });
    return resultado;
  }

  Future<Map<String, EscalaTerapeuta>> _escalasCadastro(
      dynamic connection) async {
    final result = await connection
        .execute('SELECT usr_ukey, dias, inicio, fim FROM app_escala');
    final mapa = <String, EscalaTerapeuta>{};
    for (final row in result.rows) {
      final id = (row.colByName('usr_ukey') as String?)?.trim();
      final e = EscalaTerapeuta.doBanco(
        row.colByName('dias') as String?,
        row.colByName('inicio') as String?,
        row.colByName('fim') as String?,
      );
      if (id != null && e != null) mapa[id] = e;
    }
    return mapa;
  }

  Future<void> _salvarEscala(
    dynamic connection,
    String id,
    EscalaTerapeuta? escala,
  ) async {
    if (escala == null) {
      await connection.execute(
          'DELETE FROM app_escala WHERE usr_ukey = :id', {'id': id});
      return;
    }
    await connection.execute(
      '''
      INSERT INTO app_escala (usr_ukey, dias, inicio, fim)
      VALUES (:id, :dias, :inicio, :fim)
      ON DUPLICATE KEY UPDATE
        dias = VALUES(dias), inicio = VALUES(inicio), fim = VALUES(fim)
      ''',
      {
        'id': id,
        'dias': escala.dias.join(','),
        'inicio': escala.inicio,
        'fim': escala.fim,
      },
    );
  }

  /// Horário de funcionamento das unidades (minutos): seg. a sáb. 10h–22h,
  /// domingo 14h–20h.
  static (int, int) horarioUnidade(DateTime dia) =>
      dia.weekday == DateTime.sunday ? (14 * 60, 20 * 60) : (10 * 60, 22 * 60);

  // ------------------------------------------------------ agendamentos

  /// Cria o agendamento (tabela atd), conferindo de novo se o horário do
  /// terapeuta está livre.
  Future<String> agendar({
    required String unidadeId,
    required String servicoId,
    required int duracao,
    required bool comCombo,
    required String terapeutaId,
    required String pacienteId,
    required DateTime inicio,
    required DateTime agora,
  }) async {
    final servico = catalogo.where((s) => s.id == servicoId).firstOrNull;
    if (servico == null) {
      throw const AdminRecusa('Serviço inválido.', codigo: 400);
    }
    final opcao = servico.opcoes.where((o) => o.$1 == duracao).firstOrNull;
    if (opcao == null) {
      throw const AdminRecusa('Duração inválida para este serviço.',
          codigo: 400);
    }
    if (comCombo && !servico.combo) {
      throw const AdminRecusa('Este serviço não tem combo.', codigo: 400);
    }
    final total = duracao + (comCombo ? combo.duracao : 0);
    final preco = opcao.$2 + (comCombo ? combo.preco : 0);

    final connection = await Database.connect();
    try {
      final paciente = await connection.execute(
        'SELECT 1 FROM cli WHERE cli_ukey = :id LIMIT 1',
        {'id': pacienteId},
      );
      if (paciente.rows.isEmpty) {
        throw const AdminRecusa('Paciente não encontrado.', codigo: 400);
      }

      // Confere o horário com a mesma regra da tela.
      final agenda =
          await _agenda(connection, unidadeId, inicio, total, agora);
      final t = agenda.where((x) => x.id == terapeutaId).firstOrNull;
      if (t == null) {
        throw const AdminRecusa('Terapeuta não atende nesta unidade.');
      }
      final minutos = inicio.hour * 60 + inicio.minute;
      final livre = t.horarios.any((h) => h.$1 == minutos && h.$2);
      if (!livre) {
        throw const AdminRecusa(
            'Este horário não está mais livre. Escolha outro.');
      }

      final tabelaId =
          await _tabelaDoServico(connection, unidadeId, servico.palavra, duracao);

      final id = 'APP${DateTime.now().millisecondsSinceEpoch}';
      await connection.execute(
        '''
        INSERT INTO atd
          (atd_ukey, und_ukey, cli_ukey, tpr_ukey, usr_ukey,
           atd_001_c, atd_002_c, atd_003_c, atd_004_c, atd_022_c, atd_030_c)
        VALUES
          (:id, :unidade, :paciente, :tabela, :terapeuta,
           :duracao, :inicio, :fim, :preco, :obs, 'N')
        ''',
        {
          'id': id,
          'unidade': unidadeId,
          'paciente': pacienteId,
          'tabela': tabelaId,
          'terapeuta': terapeutaId,
          'duracao': total,
          'inicio': _sql(inicio),
          'fim': _sql(inicio.add(Duration(minutes: total))),
          'preco': preco.toStringAsFixed(2),
          // Marca o combo para o app do terapeuta mostrar
          // "Reflexologia Podal + Auriculoterapia".
          'obs': comCombo ? 'Auriculoterapia - Combo' : null,
        },
      );
      return id;
    } finally {
      await connection.close();
    }
  }

  /// Linha da tabela de preços (tpr) que corresponde ao serviço na unidade:
  /// de preferência com a mesma duração.
  Future<String?> _tabelaDoServico(
    dynamic connection,
    String unidadeId,
    String palavra,
    int duracao,
  ) async {
    final result = await connection.execute(
      '''
      SELECT tpr_ukey, tpr_001_c, tpr_002_c
      FROM tpr
      WHERE und_ukey = :unidade
      ''',
      {'unidade': unidadeId},
    );
    String? qualquer;
    for (final row in result.rows) {
      final nome = (_texto(row.colByName('tpr_001_c')) ?? '').toLowerCase();
      if (!nome.contains(palavra) ||
          nome.contains('#') ||
          nome.contains('combo') ||
          nome.contains('+') ||
          nome.contains('sessão') ||
          nome.contains('sessao') ||
          RegExp(r'^[a-z]\s*\.').hasMatch(nome)) {
        continue;
      }
      final id = row.colByName('tpr_ukey') as String?;
      if (id == null) continue;
      qualquer ??= id;
      if (_duracaoTabela(row.colByName('tpr_002_c'), nome, null) == duracao) {
        return id;
      }
    }
    return qualquer;
  }

  /// Agendamentos de um dia (todas as unidades ou só [unidadeId]).
  Future<List<Map<String, Object?>>> agendamentosDoDia({
    required DateTime dia,
    String? unidadeId,
    required DateTime agora,
  }) async {
    final connection = await Database.connect();
    try {
      final d = DateTime(dia.year, dia.month, dia.day);
      final filtroUnidade =
          unidadeId == null ? '' : 'AND a.und_ukey = :unidade';
      final result = await connection.execute(
        '''
        SELECT a.atd_ukey, a.atd_001_c, a.atd_002_c, a.atd_003_c,
               a.usr_ukey, a.cli_ukey,
               c.cli_004_c AS paciente,
               COALESCE(NULLIF(TRIM(u.usr_038_c), ''), u.usr_002_c,
                        NULLIF(TRIM(u2.usr_038_c), ''), u2.usr_002_c) AS terapeuta,
               t.tpr_001_c AS servico,
               a.atd_022_c AS obs,
               und.und_001_c AS unidade,
               st.status AS status_salvo
        FROM atd a
        LEFT JOIN cli c ON c.cli_ukey = a.cli_ukey
        LEFT JOIN usr u ON u.usr_ukey = a.usr_ukey
        LEFT JOIN usr u2 ON u.usr_ukey IS NULL AND u2.usr_001_c = a.usr_ukey
        LEFT JOIN tpr t ON t.tpr_ukey = a.tpr_ukey
        LEFT JOIN und und ON und.und_ukey = a.und_ukey
        LEFT JOIN app_status_atendimento st ON st.atd_ukey = a.atd_ukey
        WHERE a.atd_002_c >= :dia AND a.atd_002_c < :seguinte
          $filtroUnidade
        ORDER BY a.atd_002_c
        ''',
        {
          'dia': _sql(d),
          'seguinte': _sql(d.add(const Duration(days: 1))),
          if (unidadeId != null) 'unidade': unidadeId,
        },
      );

      return [
        for (final row in result.rows) _mapearAgendamento(row, agora),
      ];
    } finally {
      await connection.close();
    }
  }

  Map<String, Object?> _mapearAgendamento(dynamic row, DateTime agora) {
    final ini = _data(row.colByName('atd_002_c'));
    var fim = _data(row.colByName('atd_003_c'));
    final duracao = int.tryParse(row.colByName('atd_001_c') ?? '') ?? 60;
    if (ini != null && (fim == null || !fim.isAfter(ini))) {
      fim = ini.add(Duration(minutes: duracao));
    }
    final salvo = _texto(row.colByName('status_salvo'));
    final status = salvo ??
        (fim != null && !fim.isAfter(agora) ? 'concluido' : 'confirmado');
    return {
      'id': row.colByName('atd_ukey'),
      'inicio': ini?.toIso8601String(),
      'fim': fim?.toIso8601String(),
      'duracao': duracao,
      'paciente': _texto(row.colByName('paciente')) ?? 'Paciente sem nome',
      'terapeuta': _texto(row.colByName('terapeuta')) ?? 'Terapeuta',
      'servico': _nomeServico(
        _texto(row.colByName('servico')),
        _texto(row.colByName('obs')),
      ),
      'unidade': _nomeUnidade(row.colByName('unidade')),
      'status': status,
    };
  }

  /// Cancela o agendamento (o registro fica no histórico como cancelado).
  Future<void> cancelar(String atendimentoId) async {
    final connection = await Database.connect();
    try {
      final existe = await connection.execute(
        'SELECT usr_ukey FROM atd WHERE atd_ukey = :id LIMIT 1',
        {'id': atendimentoId},
      );
      if (existe.rows.isEmpty) {
        throw const AdminRecusa('Agendamento não encontrado.', codigo: 404);
      }
      await connection.execute(
        '''
        INSERT INTO app_status_atendimento (atd_ukey, usr_ukey, status)
        VALUES (:id, :terapeuta, 'cancelado')
        ON DUPLICATE KEY UPDATE
          status = VALUES(status),
          atualizado_em = CURRENT_TIMESTAMP
        ''',
        {
          'id': atendimentoId,
          'terapeuta': existe.rows.first.colByName('usr_ukey'),
        },
      );
    } finally {
      await connection.close();
    }
  }

  // --------------------------------------------------------- terapeutas

  Future<List<Map<String, Object?>>> terapeutas() async {
    final connection = await Database.connect();
    try {
      final result = await connection.execute(
        '''
        SELECT u.usr_ukey, u.usr_001_c, u.usr_002_c, u.usr_038_c, u.usr_019_c,
               es.dias AS escala_dias, es.inicio AS escala_inicio,
               es.fim AS escala_fim,
               GROUP_CONCAT(ux.und_ukey) AS unidades
        FROM usr u
        LEFT JOIN usrXund ux ON ux.usr_ukey = u.usr_ukey
        LEFT JOIN app_escala es ON es.usr_ukey = u.usr_ukey
        WHERE u.usr_010_c = '3'
        GROUP BY u.usr_ukey, u.usr_001_c, u.usr_002_c, u.usr_038_c, u.usr_019_c,
                 es.dias, es.inicio, es.fim
        ORDER BY TRIM(u.usr_002_c)
        ''',
      );
      return [
        for (final row in result.rows)
          {
            'id': row.colByName('usr_ukey'),
            'login': _texto(row.colByName('usr_001_c')),
            'nome': _texto(row.colByName('usr_002_c')) ?? 'Sem nome',
            'apelido': _texto(row.colByName('usr_038_c')),
            'email': _texto(row.colByName('usr_019_c')),
            'unidades': [
              for (final u in (row.colByName('unidades') ?? '').split(','))
                if (u.trim().isNotEmpty) u.trim(),
            ],
            'escala': EscalaTerapeuta.doBanco(
              row.colByName('escala_dias'),
              row.colByName('escala_inicio'),
              row.colByName('escala_fim'),
            )?.paraJson(),
          },
      ];
    } finally {
      await connection.close();
    }
  }

  Future<String> criarTerapeuta(DadosTerapeuta d) async {
    if (d.senha == null) {
      throw const AdminRecusa('Informe uma senha.', codigo: 400);
    }
    final connection = await Database.connect();
    try {
      await _loginLivre(connection, d.login);
      final id = 'APP${DateTime.now().millisecondsSinceEpoch}';
      await connection.execute(
        '''
        INSERT INTO usr
          (usr_ukey, usr_001_c, usr_002_c, usr_003_c, usr_010_c, usr_019_c, usr_038_c)
        VALUES (:id, :login, :nome, :senha, '3', :email, :apelido)
        ''',
        {
          'id': id,
          'login': d.login,
          'nome': d.nome,
          'senha': d.senha,
          'email': d.email,
          'apelido': d.apelido,
        },
      );
      for (final u in d.unidades) {
        await connection.execute(
          'INSERT INTO usrXund (usr_ukey, und_ukey) VALUES (:id, :und)',
          {'id': id, 'und': u},
        );
      }
      await _salvarEscala(connection, id, d.escala);
      return id;
    } finally {
      await connection.close();
    }
  }

  Future<void> editarTerapeuta(String id, DadosTerapeuta d) async {
    final connection = await Database.connect();
    try {
      final existe = await connection.execute(
        "SELECT 1 FROM usr WHERE usr_ukey = :id AND usr_010_c = '3' LIMIT 1",
        {'id': id},
      );
      if (existe.rows.isEmpty) {
        throw const AdminRecusa('Terapeuta não encontrado.', codigo: 404);
      }
      await _loginLivre(connection, d.login, excetoId: id);

      await connection.execute(
        '''
        UPDATE usr
        SET usr_001_c = :login, usr_002_c = :nome, usr_019_c = :email,
            usr_038_c = :apelido
        WHERE usr_ukey = :id
        ''',
        {
          'id': id,
          'login': d.login,
          'nome': d.nome,
          'email': d.email,
          'apelido': d.apelido,
        },
      );
      if (d.senha != null) {
        await connection.execute(
          'UPDATE usr SET usr_003_c = :senha WHERE usr_ukey = :id',
          {'id': id, 'senha': d.senha},
        );
      }

      // Unidades: remove só as desmarcadas e acrescenta as novas (mantém os
      // dados de comissão das que continuam).
      final atuais = await connection.execute(
        'SELECT und_ukey FROM usrXund WHERE usr_ukey = :id',
        {'id': id},
      );
      final existentes = {
        for (final row in atuais.rows) (row.colByName('und_ukey') ?? '').trim(),
      };
      for (final u in existentes.difference(d.unidades.toSet())) {
        await connection.execute(
          'DELETE FROM usrXund WHERE usr_ukey = :id AND und_ukey = :und',
          {'id': id, 'und': u},
        );
      }
      for (final u in d.unidades.toSet().difference(existentes)) {
        await connection.execute(
          'INSERT INTO usrXund (usr_ukey, und_ukey) VALUES (:id, :und)',
          {'id': id, 'und': u},
        );
      }
      await _salvarEscala(connection, id, d.escala);
    } finally {
      await connection.close();
    }
  }

  /// Exclui o terapeuta. Recusa se ele tiver agendamentos futuros ativos.
  Future<void> excluirTerapeuta(String id, DateTime agora) async {
    final connection = await Database.connect();
    try {
      final usuario = await connection.execute(
        "SELECT usr_001_c FROM usr WHERE usr_ukey = :id AND usr_010_c = '3' LIMIT 1",
        {'id': id},
      );
      if (usuario.rows.isEmpty) {
        throw const AdminRecusa('Terapeuta não encontrado.', codigo: 404);
      }
      final login = usuario.rows.first.colByName('usr_001_c') ?? id;

      final futuros = await connection.execute(
        '''
        SELECT COUNT(*) AS n
        FROM atd a
        LEFT JOIN app_status_atendimento st ON st.atd_ukey = a.atd_ukey
        WHERE (a.usr_ukey = :id OR a.usr_ukey = :login)
          AND a.atd_002_c >= :agora
          AND (st.status IS NULL OR st.status NOT IN ('cancelado', 'faltou'))
        ''',
        {'id': id, 'login': login, 'agora': _sql(agora)},
      );
      final n = int.tryParse(futuros.rows.first.colByName('n') ?? '0') ?? 0;
      if (n > 0) {
        throw AdminRecusa(
            'Este terapeuta tem $n agendamento${n == 1 ? '' : 's'} '
            'futuro${n == 1 ? '' : 's'}. Cancele antes de excluir.');
      }

      for (final sql in [
        'DELETE FROM usrXund WHERE usr_ukey = :id',
        'DELETE FROM app_escala WHERE usr_ukey = :id',
        'DELETE FROM app_perfil WHERE usr_ukey = :id',
        'DELETE FROM app_disponibilidade WHERE usr_ukey = :id',
        'DELETE FROM app_paciente_terapeuta WHERE usr_ukey = :id',
        "DELETE FROM usr WHERE usr_ukey = :id AND usr_010_c = '3'",
      ]) {
        await connection.execute(sql, {'id': id});
      }
    } finally {
      await connection.close();
    }
  }

  Future<void> _loginLivre(
    dynamic connection,
    String login, {
    String? excetoId,
  }) async {
    final result = await connection.execute(
      'SELECT usr_ukey FROM usr WHERE usr_001_c = :login',
      {'login': login},
    );
    for (final row in result.rows) {
      if (row.colByName('usr_ukey') != excetoId) {
        throw const AdminRecusa('Este login já está em uso.');
      }
    }
  }

  // ---------------------------------------------------------- pacientes

  /// Pacientes em ordem alfabética, filtrados por nome ou telefone.
  Future<Map<String, Object?>> pacientes({String? busca, int limite = 60}) async {
    final connection = await Database.connect();
    try {
      final termo = busca?.trim() ?? '';
      final filtro = termo.isEmpty
          ? ''
          : 'WHERE c.cli_004_c LIKE :busca OR c.cli_012_c LIKE :busca';
      final params = {if (termo.isNotEmpty) 'busca': '%$termo%'};

      final total = await connection.execute(
        'SELECT COUNT(*) AS n FROM cli c $filtro',
        params,
      );
      final result = await connection.execute(
        '''
        SELECT c.cli_ukey, c.cli_004_c, c.cli_012_c, c.cli_001_c, c.cli_017_c
        FROM cli c
        $filtro
        ORDER BY TRIM(c.cli_004_c)
        LIMIT $limite
        ''',
        params,
      );
      return {
        'total': int.tryParse(total.rows.first.colByName('n') ?? '0') ?? 0,
        'pacientes': [
          for (final row in result.rows)
            {
              'id': row.colByName('cli_ukey'),
              'nome': _texto(row.colByName('cli_004_c')) ?? 'Sem nome',
              'telefone': _texto(row.colByName('cli_012_c')),
              'email': _texto(row.colByName('cli_001_c')),
              'nascimento': _dataNascimento(row.colByName('cli_017_c')),
            },
        ],
      };
    } finally {
      await connection.close();
    }
  }

  /// Exclui o paciente. Recusa se ele tiver agendamentos futuros ativos.
  Future<void> excluirPaciente(String id, DateTime agora) async {
    final connection = await Database.connect();
    try {
      final existe = await connection.execute(
        'SELECT 1 FROM cli WHERE cli_ukey = :id LIMIT 1',
        {'id': id},
      );
      if (existe.rows.isEmpty) {
        throw const AdminRecusa('Paciente não encontrado.', codigo: 404);
      }
      final futuros = await connection.execute(
        '''
        SELECT COUNT(*) AS n
        FROM atd a
        LEFT JOIN app_status_atendimento st ON st.atd_ukey = a.atd_ukey
        WHERE a.cli_ukey = :id
          AND a.atd_002_c >= :agora
          AND (st.status IS NULL OR st.status NOT IN ('cancelado', 'faltou'))
        ''',
        {'id': id, 'agora': _sql(agora)},
      );
      final n = int.tryParse(futuros.rows.first.colByName('n') ?? '0') ?? 0;
      if (n > 0) {
        throw AdminRecusa(
            'Este paciente tem $n agendamento${n == 1 ? '' : 's'} '
            'futuro${n == 1 ? '' : 's'}. Cancele antes de excluir.');
      }
      await connection.execute(
        'DELETE FROM app_paciente_terapeuta WHERE cli_ukey = :id',
        {'id': id},
      );
      await connection.execute(
        'DELETE FROM cli WHERE cli_ukey = :id',
        {'id': id},
      );
    } finally {
      await connection.close();
    }
  }

  // ------------------------------------------------------------ apoio

  static String _sql(DateTime d) {
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${dois(d.month)}-${dois(d.day)} '
        '${dois(d.hour)}:${dois(d.minute)}:${dois(d.second)}';
  }

  static DateTime? _data(Object? valor) {
    if (valor is! String || valor.length < 10) return null;
    return DateTime.tryParse(valor.replaceFirst(' ', 'T'));
  }

  /// Texto comparável: minúsculas, sem espaços extras.
  static String _chave(String texto) =>
      _texto(texto)?.toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ?? '';

  static int _primeiroNumero(String? texto) {
    final m = RegExp(r'\d+').firstMatch(texto ?? '');
    return m == null ? 0 : int.parse(m.group(0)!);
  }

  /// Duração em minutos de uma linha da tabela de preços. Aceita "60",
  /// "60 min", "1h30", "01:00" ou "01:00:00". Se a coluna não tiver a
  /// duração, tenta o nome ("Maca 60 min") e depois a duração usada nos
  /// atendimentos já feitos com esse preço. Sem nada disso, 60 minutos.
  static int _duracaoTabela(String? coluna, String? nome, String? doAtd) {
    final texto = (coluna ?? '').trim();
    final hhmm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(texto);
    if (hhmm != null) {
      final m = int.parse(hhmm.group(1)!) * 60 + int.parse(hhmm.group(2)!);
      if (m > 0) return m;
    }
    final hm = RegExp(r'(\d+)\s*h\s*(\d{1,2})?', caseSensitive: false)
        .firstMatch(texto);
    if (hm != null) {
      final m = int.parse(hm.group(1)!) * 60 + int.parse(hm.group(2) ?? '0');
      if (m > 0) return m;
    }
    final direto = _primeiroNumero(texto);
    if (direto > 0) return direto;

    final noNome = RegExp(r'(\d+)\s*(?:minutos|minuto|mins|min|m)\b',
            caseSensitive: false)
        .firstMatch(nome ?? '');
    if (noNome != null) {
      final m = int.parse(noNome.group(1)!);
      if (m > 0) return m;
    }
    final atd = int.tryParse((doAtd ?? '').trim()) ?? 0;
    return atd > 0 ? atd : 60;
  }

  /// Nome do serviço para a lista do administrador ("2.Reflexologia Podal"
  /// -> "Reflexologia Podal"), com o combo de Auriculoterapia quando houver.
  static String _nomeServico(String? tabela, String? obs) {
    final n = (tabela ?? '').toLowerCase();
    var nome = catalogo
            .where((s) => n.contains(s.palavra))
            .map((s) => s.nome)
            .firstOrNull ??
        (tabela ?? 'Serviço').replaceFirst(RegExp(r'^\s*\d+\s*[.)\-–]\s*'), '');
    if ((obs ?? '').toLowerCase().contains('auricul') &&
        !nome.toLowerCase().contains('auricul')) {
      nome = '$nome + Auriculoterapia';
    }
    return nome;
  }

  static String? _dataNascimento(String? valor) {
    if (valor == null || valor.length < 10) return null;
    final ano = int.tryParse(valor.substring(0, 4)) ?? 0;
    if (ano <= 1900) return null;
    return valor.substring(0, 10);
  }

  static String _nomeUnidade(String? valor) =>
      (_texto(valor) ?? 'Unidade').replaceAll(' Shopping', '').trim();

  static String? _texto(String? valor) {
    if (valor == null) return null;
    var texto = valor.trim();
    if (texto.contains('Ã') || texto.contains('Â')) {
      try {
        texto = utf8.decode(latin1.encode(texto)).trim();
      } catch (_) {}
    }
    return texto.isEmpty ? null : texto;
  }
}

/// Dados do formulário de terapeuta, já validados.
class DadosTerapeuta {
  const DadosTerapeuta({
    required this.nome,
    required this.login,
    required this.unidades,
    this.apelido,
    this.email,
    this.senha,
    this.escala,
  });

  final String nome;
  final String login;
  final List<String> unidades;
  final String? apelido;
  final String? email;

  /// Null ao editar = mantém a senha atual.
  final String? senha;

  /// Escala do cadastro. Null = usa a escala do sistema (events).
  final EscalaTerapeuta? escala;

  static DadosTerapeuta? deJson(Object? json) {
    if (json is! Map) return null;
    String? texto(Object? v, int max) {
      if (v is! String) return null;
      final t = v.trim();
      if (t.isEmpty || t.length > max) return null;
      return t;
    }

    final nome = texto(json['nome'], 50);
    final login = texto(json['login'], 20);
    final unidades = json['unidades'];
    if (nome == null || login == null || unidades is! List) return null;
    final lista = [
      for (final u in unidades)
        if (u is String && u.trim().isNotEmpty) u.trim(),
    ];
    if (lista.isEmpty) return null;

    final senha = json['senha'];
    if (senha != null &&
        (senha is! String || senha.length < 4 || senha.length > 50)) {
      return null;
    }

    return DadosTerapeuta(
      nome: nome,
      login: login,
      unidades: lista,
      apelido: texto(json['apelido'], 30),
      email: texto(json['email'], 200),
      senha: senha is String ? senha : null,
      escala: EscalaTerapeuta.deJson(json['escala']),
    );
  }
}

/// Escala de trabalho do terapeuta definida no cadastro (tabela
/// app_escala): dias da semana (1 = segunda ... 7 = domingo) e horário.
/// No domingo vale sempre o horário da Rokuzen, das 14h às 20h.
class EscalaTerapeuta {
  const EscalaTerapeuta({
    required this.dias,
    required this.inicio,
    required this.fim,
  });

  final List<int> dias;
  final int inicio;
  final int fim;

  /// Turno do [dia] (minutos) ou null se é folga.
  (int, int)? turnoDe(DateTime dia) {
    if (!dias.contains(dia.weekday)) return null;
    return dia.weekday == DateTime.sunday ? (14 * 60, 20 * 60) : (inicio, fim);
  }

  Map<String, Object> paraJson() =>
      {'dias': dias, 'inicio': inicio, 'fim': fim};

  static EscalaTerapeuta? doBanco(Object? dias, Object? inicio, Object? fim) {
    if (dias is! String) return null;
    final lista = [
      for (final d in dias.split(','))
        if (int.tryParse(d.trim()) case final n?)
          if (n >= 1 && n <= 7) n,
    ];
    final i = int.tryParse('${inicio ?? ''}');
    final f = int.tryParse('${fim ?? ''}');
    if (lista.isEmpty || i == null || f == null || f <= i) return null;
    return EscalaTerapeuta(dias: lista, inicio: i, fim: f);
  }

  static EscalaTerapeuta? deJson(Object? json) {
    if (json is! Map) return null;
    final dias = json['dias'];
    final inicio = json['inicio'];
    final fim = json['fim'];
    if (dias is! List || inicio is! int || fim is! int) return null;
    final lista = {
      for (final d in dias)
        if (d is int && d >= 1 && d <= 7) d,
    }.toList()
      ..sort();
    if (lista.isEmpty || inicio < 0 || fim > 24 * 60 || fim <= inicio) {
      return null;
    }
    return EscalaTerapeuta(dias: lista, inicio: inicio, fim: fim);
  }
}
