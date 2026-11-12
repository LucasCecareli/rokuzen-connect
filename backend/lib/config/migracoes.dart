import 'package:backend/config/database.dart';

/// Tabelas próprias do Rokuzen Connect.
///
/// O banco da Rokuzen não tem onde guardar a disponibilidade particular da
/// terapeuta nem o status de cada atendimento (iniciado, concluído...). Em vez
/// de alterar as tabelas originais, o app usa duas tabelas novas com o
/// prefixo `app_`.
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
  ];

  static Future<void> garantirTabelas() async {
    final connection = await Database.connect();
    try {
      for (final sql in _tabelas) {
        await connection.execute(sql);
      }
    } finally {
      await connection.close();
    }
  }
}
