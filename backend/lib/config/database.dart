import 'package:dotenv/dotenv.dart';
import 'package:mysql_client/mysql_client.dart';

/// Acesso ao banco com conexões reaproveitadas.
///
/// Abrir uma conexão nova com o TiDB na nuvem (com SSL) leva de 1 a 3
/// segundos. Antes, cada consulta abria e fechava a sua; agora as conexões
/// ficam guardadas e são reutilizadas, e só a primeira consulta paga esse
/// tempo.
///
/// O uso continua igual:
///   final connection = await Database.connect();
///   try { await connection.execute(...); } finally { await connection.close(); }
/// Aqui, close() devolve a conexão para ser reaproveitada.
class Database {
  static const _maxGuardadas = 6;

  /// Uma conexão parada por muito tempo pode ser derrubada pela rede ou
  /// pelo servidor. Só reaproveita as que foram usadas há pouco.
  static const _tempoMaximoParada = Duration(seconds: 45);

  static final _livres = <(MySQLConnection, DateTime)>[];

  static DotEnv? _env;

  static Future<ConexaoBanco> connect() async {
    final agora = DateTime.now();
    while (_livres.isNotEmpty) {
      final (c, desde) = _livres.removeLast();
      if (c.connected && agora.difference(desde) < _tempoMaximoParada) {
        return ConexaoBanco._(c);
      }
      _fechar(c);
    }
    return ConexaoBanco._(await _nova());
  }

  static void _devolver(MySQLConnection c) {
    if (c.connected && _livres.length < _maxGuardadas) {
      _livres.add((c, DateTime.now()));
    } else {
      _fechar(c);
    }
  }

  static void _fechar(MySQLConnection c) {
    try {
      c.close().catchError((_) {});
    } catch (_) {}
  }

  static Future<MySQLConnection> _nova() async {
    final env = _env ??= (DotEnv()..load());

    final host = env['DB_HOST'];
    final port = int.parse(env['DB_PORT'] ?? '3306');
    final database = env['DB_NAME'];
    final user = env['DB_USER'];
    final password = env['DB_PASSWORD'];
    final secure = env['DB_SECURE'] == 'true';

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
      secure: secure,
    );

    await connection.connect();

    return connection;
  }
}

/// Uma conexão emprestada. Se a conexão guardada tiver caído (o servidor
/// encerra conexões paradas), abre outra e repete a consulta uma vez.
class ConexaoBanco {
  ConexaoBanco._(this._conexao);

  MySQLConnection _conexao;
  bool _devolvida = false;

  Future<IResultSet> execute(
    String query, [
    Map<String, dynamic>? params,
  ]) async {
    try {
      return await _conexao.execute(query, params);
    } catch (_) {
      // Se a conexão continua aberta, o erro é do SQL (tabela inexistente,
      // sintaxe...): repassa. Se caiu, troca por uma nova e tenta de novo.
      if (_conexao.connected) rethrow;
      Database._fechar(_conexao);
      _conexao = await Database._nova();
      return _conexao.execute(query, params);
    }
  }

  /// Devolve a conexão para ser reaproveitada.
  Future<void> close() async {
    if (_devolvida) return;
    _devolvida = true;
    Database._devolver(_conexao);
  }
}
