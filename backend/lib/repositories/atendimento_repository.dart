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
          a.atd_005_c AS sala_numero,
          c.cli_004_c AS cliente_nome,
          und.und_001_c AS unidade_nome,
          t.tpr_001_c AS servico_nome,
          t.srv_ukey AS srv_ukey
        FROM atd a
        LEFT JOIN cli c ON a.cli_ukey = c.cli_ukey
        LEFT JOIN und und ON a.und_ukey = und.und_ukey
        LEFT JOIN tpr t ON a.tpr_ukey = t.tpr_ukey
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
          a.atd_005_c AS sala_numero,
          c.cli_004_c AS cliente_nome,
          und.und_001_c AS unidade_nome,
          t.tpr_001_c AS servico_nome,
          t.srv_ukey AS srv_ukey
        FROM atd a
        LEFT JOIN cli c ON a.cli_ukey = c.cli_ukey
        LEFT JOIN und und ON a.und_ukey = und.und_ukey
        LEFT JOIN tpr t ON a.tpr_ukey = t.tpr_ukey
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

    final salaNum = _texto(row.colByName('sala_numero'));
    String sala;
    if (servico == 'Quick Massage') {
      sala = (salaNum != null && salaNum.isNotEmpty) ? 'Cadeira $salaNum' : 'Cadeira 1';
    } else {
      sala = (salaNum != null && salaNum.isNotEmpty) ? 'Sala $salaNum' : 'Sala 1';
    }

    final inicioStr = row.colByName('inicio');
    final fimStr = row.colByName('fim');

    DateTime? inicioDate;
    if (inicioStr != null) {
      inicioDate = DateTime.tryParse(inicioStr.replaceAll(' ', 'T'));
    }

    DateTime? fimDate;
    if (fimStr != null) {
      fimDate = DateTime.tryParse(fimStr.replaceAll(' ', 'T'));
    }

    final agora = DateTime.now();
    String status = 'confirmado';

    if (fimDate != null && fimDate.isBefore(agora)) {
      status = 'concluido';
    } else if (inicioDate != null &&
        inicioDate.isBefore(agora) &&
        fimDate != null &&
        fimDate.isAfter(agora)) {
      status = 'andamento';
    }

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
      'sala': sala,
      'status': status,
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
