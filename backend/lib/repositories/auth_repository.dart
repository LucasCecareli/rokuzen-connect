
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
        LIMIT 1
        ''',
        {'usuarioId': usuarioId},
      );

      return result.rows.isNotEmpty;
    } finally {
      await connection.close();
    }
  }
}
