import '../lib/config/database.dart';

Future<void> main() async {
  try {
    print('Tentando conectar ao MySQL...');

    final connection = await Database.connect();

    print('Conexão com o MySQL realizada com sucesso!');

    final result = await connection.execute('SELECT 1 AS teste');

    for (final row in result.rows) {
      print('Resultado do teste: ${row.colByName('teste')}');
    }

    await connection.close();

    print('Conexão encerrada.');
  } catch (e) {
    print('Erro ao conectar ao MySQL: $e');
  }
}