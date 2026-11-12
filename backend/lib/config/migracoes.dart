import 'package:backend/config/database.dart';

/// Tabelas próprias do Rokuzen Connect.
///
/// O banco da Rokuzen não tem onde guardar a disponibilidade particular da
/// terapeuta, o status de cada atendimento (iniciado, concluído...), a foto
/// de perfil nem quais pacientes a terapeuta cadastrou pelo app. Em vez de
/// alterar as tabelas originais, o app usa tabelas novas com o prefixo
/// `app_`.
///
/// São criadas automaticamente quando o servidor liga (CREATE TABLE IF NOT
/// EXISTS): rodar de novo não apaga nem duplica nada.
abstract final class Migracoes {
  static const _tabelas = [
    '''
    CREATE TABLE IF NOT EXISTS app_disponibilidade (
      id INT NOT NULL AUTO_INCREMENT,
      usr_ukey VARCHAR(20) NOT NULL,
      data DATE NOT NULL,
      inicio SMALLINT NOT NULL,
      fim SMALLINT NOT NULL,
      cliente_reservado VARCHAR(150) NULL,
      criado_em TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_app_disp_terapeuta_data (usr_ukey, data)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS app_status_atendimento (
      atd_ukey VARCHAR(20) NOT NULL,
      usr_ukey VARCHAR(20) NULL,
      status VARCHAR(20) NOT NULL,
      atualizado_em TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (atd_ukey)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS app_perfil (
      usr_ukey VARCHAR(20) NOT NULL,
      foto MEDIUMTEXT NULL,
      atualizado_em TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (usr_ukey)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS app_paciente_terapeuta (
      cli_ukey VARCHAR(20) NOT NULL,
      usr_ukey VARCHAR(20) NOT NULL,
      criado_em TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (cli_ukey, usr_ukey),
      KEY idx_app_pac_terapeuta (usr_ukey)
    )
    ''',
  ];

  /// Colunas acrescentadas depois que as tabelas já existiam no banco do
  /// grupo: (tabela, coluna, definição).
  static const _colunas = [
    (
      'app_status_atendimento',
      'iniciado_em',
      'DATETIME NULL',
    ),
  ];

  static Future<void> garantirTabelas() async {
    final connection = await Database.connect();
    try {
      for (final sql in _tabelas) {
        await connection.execute(sql);
      }
      for (final (tabela, coluna, definicao) in _colunas) {
        final existe = await connection.execute(
          '''
          SELECT 1 FROM information_schema.COLUMNS
          WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_NAME = :tabela
            AND COLUMN_NAME = :coluna
          ''',
          {'tabela': tabela, 'coluna': coluna},
        );
        if (existe.rows.isEmpty) {
          await connection.execute(
            'ALTER TABLE $tabela ADD COLUMN $coluna $definicao',
          );
        }
      }
    } finally {
      await connection.close();
    }
  }
}
