import 'dart:convert';

import 'package:backend/config/database.dart';

class AtendimentoRepository {
  Future<List<Map<String, dynamic>>> listarAtendimentos({
    String? terapeutaId,
    String? pacienteId,
    String? inicio,
    String? fim,
  }) async {
    final connection = await Database.connect();

    try {
      final params = <String, dynamic>{};
      final whereClauses = <String>['1 = 1'];

      if (terapeutaId != null && terapeutaId.trim().isNotEmpty) {
        params['terapeutaId'] = terapeutaId.trim();
        whereClauses.add('''
          (
            a.usr_ukey = :terapeutaId
            OR a.usr_ukey = (SELECT usr_001_c FROM usr WHERE usr_ukey = :terapeutaId LIMIT 1)
            OR a.usr_ukey = (SELECT usr_ukey FROM usr WHERE usr_001_c = :terapeutaId LIMIT 1)
          )
        ''');
      }

      if (pacienteId != null && pacienteId.trim().isNotEmpty) {
        params['pacienteId'] = pacienteId.trim();
        whereClauses.add('a.cli_ukey = :pacienteId');
      }

      if (inicio != null && inicio.trim().isNotEmpty) {
        params['inicio'] = _formatarDataParaSql(inicio.trim());
        whereClauses.add('a.atd_002_c >= :inicio');
      }

      if (fim != null && fim.trim().isNotEmpty) {
        params['fim'] = _formatarDataParaSql(fim.trim());
        whereClauses.add('a.atd_002_c < :fim');
      }

      final ordenacao = (pacienteId != null && pacienteId.trim().isNotEmpty)
          ? 'ORDER BY a.atd_002_c DESC'
          : 'ORDER BY a.atd_002_c ASC';

      final sql = '''
        SELECT
          a.atd_ukey,
          a.und_ukey,
          a.cli_ukey,
          a.tpr_ukey,
          a.usr_ukey,
          a.atd_001_c AS duracao,
          a.atd_002_c AS inicio,
          a.atd_003_c AS fim,
          st.status AS status_salvo,
          c.cli_004_c AS cliente_nome,
          und.und_001_c AS unidade_nome,
          t.tpr_001_c AS servico_nome,
          t.srv_ukey AS srv_ukey
        FROM atd a
        LEFT JOIN cli c ON a.cli_ukey = c.cli_ukey
        LEFT JOIN und und ON a.und_ukey = und.und_ukey
        LEFT JOIN tpr t ON a.tpr_ukey = t.tpr_ukey
        LEFT JOIN app_status_atendimento st ON st.atd_ukey = a.atd_ukey
        WHERE ${whereClauses.join(' AND ')}
        $ordenacao
      ''';

      final result = await connection.execute(sql, params);

      return result.rows.map((row) => _mapearAtendimento(row)).toList();
    } finally {
      await connection.close();
    }
  }

  Future<Map<String, dynamic>?> buscarProximoAtendimento({
    required String terapeutaId,
    required String aPartirDe,
  }) async {
    final connection = await Database.connect();

    try {
      final sql = '''
        SELECT
          a.atd_ukey,
          a.und_ukey,
          a.cli_ukey,
          a.tpr_ukey,
          a.usr_ukey,
          a.atd_001_c AS duracao,
          a.atd_002_c AS inicio,
          a.atd_003_c AS fim,
          st.status AS status_salvo,
          c.cli_004_c AS cliente_nome,
          und.und_001_c AS unidade_nome,
          t.tpr_001_c AS servico_nome,
          t.srv_ukey AS srv_ukey
        FROM atd a
        LEFT JOIN cli c ON a.cli_ukey = c.cli_ukey
        LEFT JOIN und und ON a.und_ukey = und.und_ukey
        LEFT JOIN tpr t ON a.tpr_ukey = t.tpr_ukey
        LEFT JOIN app_status_atendimento st ON st.atd_ukey = a.atd_ukey
        WHERE (
          a.usr_ukey = :terapeutaId
          OR a.usr_ukey = (SELECT usr_001_c FROM usr WHERE usr_ukey = :terapeutaId LIMIT 1)
          OR a.usr_ukey = (SELECT usr_ukey FROM usr WHERE usr_001_c = :terapeutaId LIMIT 1)
        )
        AND a.atd_002_c >= :aPartirDe
        ORDER BY a.atd_002_c ASC
        LIMIT 1
      ''';

      final result = await connection.execute(sql, {
        'terapeutaId': terapeutaId.trim(),
        'aPartirDe': _formatarDataParaSql(aPartirDe.trim()),
      });

      if (result.rows.isEmpty) return null;

      return _mapearAtendimento(result.rows.first);
    } finally {
      await connection.close();
    }
  }

  static const statusValidos = {
    'confirmado',
    'pendente',
    'andamento',
    'concluido',
    'cancelado',
    'faltou',
  };

  /// Grava o status de um atendimento da terapeuta (tabela própria do app,
  /// app_status_atendimento). Devolve false se o atendimento não for dela.
  Future<bool> salvarStatus({
    required String atendimentoId,
    required String terapeutaId,
    required String status,
  }) async {
    final connection = await Database.connect();

    try {
      final dono = await connection.execute(
        '''
        SELECT a.atd_ukey
        FROM atd a
        WHERE a.atd_ukey = :atendimentoId
          AND (
            a.usr_ukey = :terapeutaId
            OR a.usr_ukey = (SELECT usr_001_c FROM usr WHERE usr_ukey = :terapeutaId LIMIT 1)
            OR a.usr_ukey = (SELECT usr_ukey FROM usr WHERE usr_001_c = :terapeutaId LIMIT 1)
          )
        LIMIT 1
        ''',
        {'atendimentoId': atendimentoId, 'terapeutaId': terapeutaId},
      );
      if (dono.rows.isEmpty) return false;

      await connection.execute(
        '''
        INSERT INTO app_status_atendimento (atd_ukey, usr_ukey, status)
        VALUES (:atendimentoId, :terapeutaId, :status)
        ON DUPLICATE KEY UPDATE
          status = VALUES(status),
          usr_ukey = VALUES(usr_ukey),
          atualizado_em = CURRENT_TIMESTAMP
        ''',
        {
          'atendimentoId': atendimentoId,
          'terapeutaId': terapeutaId,
          'status': status,
        },
      );
      return true;
    } finally {
      await connection.close();
    }
  }

  /// Expediente da terapeuta em cada dia entre [inicio] e [fim] (AAAA-MM-DD,
  /// fim exclusivo), lido da escala oficial da Rokuzen (tabela events).
  Future<List<Map<String, dynamic>>> buscarEscala({
    required String terapeutaId,
    required String inicio,
    required String fim,
  }) async {
    final connection = await Database.connect();

    try {
      final result = await connection.execute(
        '''
        SELECT e.start AS inicio, e.end AS fim, und.und_001_c AS unidade_nome
        FROM events e
        LEFT JOIN und und ON e.und_ukey = und.und_ukey
        WHERE e.title = :terapeutaId
          AND e.start >= :inicio
          AND e.start < :fim
        ORDER BY e.start
        ''',
        {
          'terapeutaId': terapeutaId.trim(),
          'inicio': _formatarDataParaSql(inicio.trim()),
          'fim': _formatarDataParaSql(fim.trim()),
        },
      );

      // Um dia pode ter mais de um registro: usa o primeiro início e o
      // último fim.
      final porDia = <String, Map<String, dynamic>>{};
      for (final row in result.rows) {
        final ini = DateTime.tryParse(
            (row.colByName('inicio') ?? '').replaceAll(' ', 'T'));
        final fimEvt = DateTime.tryParse(
            (row.colByName('fim') ?? '').replaceAll(' ', 'T'));
        if (ini == null || fimEvt == null || !fimEvt.isAfter(ini)) continue;

        final dia = ini.toIso8601String().substring(0, 10);
        final iniMin = ini.hour * 60 + ini.minute;
        // Expediente que vira a meia-noite termina às 24:00 do mesmo dia.
        final fimMin = fimEvt.day != ini.day
            ? 24 * 60
            : fimEvt.hour * 60 + fimEvt.minute;

        var unidade = _texto(row.colByName('unidade_nome'));
        unidade = unidade?.replaceAll(' Shopping', '').trim();

        final atual = porDia[dia];
        if (atual == null) {
          porDia[dia] = {
            'data': dia,
            'inicio': iniMin,
            'fim': fimMin,
            'unidade': unidade,
          };
        } else {
          if (iniMin < (atual['inicio'] as int)) atual['inicio'] = iniMin;
          if (fimMin > (atual['fim'] as int)) atual['fim'] = fimMin;
          atual['unidade'] ??= unidade;
        }
      }
      return porDia.values.toList();
    } finally {
      await connection.close();
    }
  }

  Map<String, dynamic> _mapearAtendimento(dynamic row) {
    final servicoNome = _texto(row.colByName('servico_nome')) ?? '';
    final nomeLower = servicoNome.toLowerCase();
    final srvUkey = row.colByName('srv_ukey');

    String servico;
    int duracao = int.tryParse(row.colByName('duracao') ?? '') ?? 30;
    int adicionalAuriculo = 0;

    final temAuriculo = nomeLower.contains('auriculo') ||
        nomeLower.contains('aurículo') ||
        srvUkey == '5' ||
        srvUkey == '23';

    if (srvUkey == '3' || nomeLower.contains('quick') || nomeLower.contains('cadeira')) {
      servico = 'Quick Massage';
    } else if (srvUkey == '4' ||
        srvUkey == '24' ||
        nomeLower.contains('reflexo') ||
        nomeLower.contains('reflexologia')) {
      servico = 'Reflexologia Podal';
      if (temAuriculo) {
        adicionalAuriculo = 10;
        if (duracao > 10) duracao -= 10;
      }
    } else if (srvUkey == '5' || temAuriculo) {
      servico = 'Auriculoterapia';
    } else {
      servico = 'Maca';
    }

    var unidade = _texto(row.colByName('unidade_nome')) ?? 'Golden Square';
    unidade = unidade.replaceAll(' Shopping', '').trim();

    final inicioStr = row.colByName('inicio');
    final fimStr = row.colByName('fim');

    return {
      'id': row.colByName('atd_ukey'),
      'pacienteId': row.colByName('cli_ukey') ?? '',
      'pacienteNome': _texto(row.colByName('cliente_nome')) ?? 'Paciente sem nome',
      'inicio': inicioStr,
      'fim': fimStr,
      'duracao': duracao,
      'adicionalAuriculo': adicionalAuriculo,
      'servico': servico,
      'unidade': unidade,
      // O banco da Rokuzen não registra sala/cadeira.
      'sala': null,
      // Status gravado pelo app (iniciado, concluído...). Quando não há,
      // o app deduz pelo horário.
      'status': _texto(row.colByName('status_salvo')),
    };
  }

  String _formatarDataParaSql(String data) {
    // Se vier no formato ISO 2026-11-08T00:00:00.000, converte para 2026-11-08 00:00:00
    if (data.contains('T')) {
      final partes = data.split('T');
      final dataParte = partes[0];
      var horaParte = partes[1];
      if (horaParte.contains('.')) {
        horaParte = horaParte.split('.')[0];
      }
      return '$dataParte $horaParte';
    }
    // Se vier apenas data YYYY-MM-DD
    if (data.length == 10 && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(data)) {
      return '$data 00:00:00';
    }
    return data;
  }

  String? _texto(String? valor) {
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
