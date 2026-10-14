import 'package:dotenv/dotenv.dart';
import 'package:mysql_client/mysql_client.dart';

class Database {
  static Future<MySQLConnection> connect() async {
    final env = DotEnv()..load();

    final host = env['DB_HOST'];
    final port = int.parse(env['DB_PORT'] ?? '3306');
    final database = env['DB_NAME'];
    final user = env['DB_USER'];
    final password = env['DB_PASSWORD'];

    if (host == null ||
        database == null ||
        user == null ||
        password == null) {
      throw Exception('Variáveis do banco não configuradas no arquivo .env');
    }

    final connection = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: user,
      password: password,
      databaseName: database,
      secure: false,
    );

    await connection.connect();

    return connection;
  }
}