import 'package:backend/config/database.dart';

class AuthRepository {
  Future<List<Map<String, String?>>> buscarTerapeutasPorLogin(
    String login,
  ) async {
    final connection = await Database.connect();

    try {
      final result = await connection.execute(
        '''
        SELECT
          u.usr_ukey,
          u.usr_001_c,
          u.usr_002_c,
          u.usr_003_c,
          u.usr_010_c
        FROM usr AS u
        WHERE u.usr_001_c = :login
          AND u.usr_010_c = '3'
        ''',
        {'login': login.trim()},
      );

      return result.rows.map((row) {
        return <String, String?>{
          'id': row.colByName('usr_ukey'),
          'login': row.colByName('usr_001_c'),
          'nome': row.colByName('usr_002_c'),
          'senha': row.colByName('usr_003_c'),
          'tipo': row.colByName('usr_010_c'),
        };
      }).toList();
    } finally {
      await connection.close();
    }
  }

  Future<bool> possuiVinculoComUnidade(String usuarioId) async {
    final connection = await Database.connect();

    try {
      final result = await connection.execute(
        '''
        SELECT 1
        FROM usrXund
        WHERE usr_ukey = :usuarioId
        UNION
        SELECT 1
        FROM events
        WHERE title = :usuarioId AND und_ukey IS NOT NULL
        LIMIT 1
        ''',
        {'usuarioId': usuarioId},
      );

      return result.rows.isNotEmpty;
    } finally {
      await connection.close();
    }
  }

  Future<Map<String, dynamic>?> buscarDetalhesTerapeuta(String usuarioId) async {
    final connection = await Database.connect();

    try {
      final result = await connection.execute(
        '''
        SELECT
          u.usr_ukey,
          u.usr_001_c,
          u.usr_002_c,
          u.usr_010_c,
          und.und_ukey,
          und.und_001_c AS unidade_nome
        FROM usr AS u
        LEFT JOIN usrXund AS ux ON u.usr_ukey = ux.usr_ukey
        LEFT JOIN und AS und ON ux.und_ukey = und.und_ukey
        WHERE u.usr_ukey = :usuarioId
        LIMIT 1
        ''',
        {'usuarioId': usuarioId},
      );

      if (result.rows.isEmpty) return null;

      final row = result.rows.first;
      var unidade = row.colByName('unidade_nome') ?? 'Golden Square';
      unidade = unidade.replaceAll(' Shopping', '').trim();

      int inicioTurno = 10 * 60; // 10h
      int fimTurno = 16 * 60;    // 16h

      // Tenta buscar o turno na escala oficial de events
      final eventRes = await connection.execute(
        '''
        SELECT start, end, und_ukey
        FROM events
        WHERE title = :usuarioId
        ORDER BY start DESC
        LIMIT 1
        ''',
        {'usuarioId': usuarioId},
      );

      var unidadeId = row.colByName('und_ukey');
      if (unidadeId == null && eventRes.rows.isNotEmpty) {
        unidadeId = eventRes.rows.first.colByName('und_ukey');
      }

      if (eventRes.rows.isNotEmpty) {
        final startStr = eventRes.rows.first.colByName('start');
        final endStr = eventRes.rows.first.colByName('end');
        if (startStr != null && startStr.length >= 16) {
          final h = int.tryParse(startStr.substring(11, 13));
          final m = int.tryParse(startStr.substring(14, 16));
          if (h != null && m != null) inicioTurno = h * 60 + m;
        }
        if (endStr != null && endStr.length >= 16) {
          final h = int.tryParse(endStr.substring(11, 13));
          final m = int.tryParse(endStr.substring(14, 16));
          if (h != null && m != null) fimTurno = h * 60 + m;
        }
      }

      return {
        'id': row.colByName('usr_ukey'),
        'login': row.colByName('usr_001_c'),
        'nome': row.colByName('usr_002_c'),
        'tipo': row.colByName('usr_010_c'),
        'unidadeId': unidadeId ?? '1',
        'unidade': unidade,
        'inicioTurno': inicioTurno,
        'fimTurno': fimTurno,
      };
    } finally {
      await connection.close();
    }
  }
}
