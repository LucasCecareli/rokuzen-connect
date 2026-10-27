import 'dart:convert';

import 'package:backend/config/database.dart';

class PacienteRepository {
  
  Future<List<Map<String, String?>>> listarPacientes() async {
    final connection = await Database.connect();

    try {
      
      final result = await connection.execute('''
        SELECT
          c.cli_ukey,
          c.cli_004_c,
          c.cli_012_c,
          c.cli_001_c,
          c.cli_017_c
        FROM cli AS c
        ORDER BY TRIM(c.cli_004_c)
      ''');

      return result.rows.map((row) {
        return <String, String?>{
          'id': row.colByName('cli_ukey'),
          'nome': _texto(row.colByName('cli_004_c')),
          'telefone': _texto(row.colByName('cli_012_c')),
          'email': _texto(row.colByName('cli_001_c')),
          'nascimento': _dataOuNulo(row.colByName('cli_017_c')),
        };
      }).toList();
    } finally {
      await connection.close();
    }
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
}