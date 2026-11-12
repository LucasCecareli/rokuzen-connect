import 'package:backend/config/database.dart';

/// Horários livres da terapeuta para atendimentos particulares
/// (tabela própria do app: app_disponibilidade).
///
/// `inicio` e `fim` são minutos desde a meia-noite (ex.: 19:30 = 1170).
class DisponibilidadeRepository {
  Future<List<Map<String, dynamic>>> listar(String terapeutaId) async {
    final connection = await Database.connect();
    try {
      final result = await connection.execute(
        '''
        SELECT id, data, inicio, fim, cliente_reservado
        FROM app_disponibilidade
        WHERE usr_ukey = :terapeuta
        ORDER BY data, inicio
        ''',
        {'terapeuta': terapeutaId},
      );
      return result.rows.map(_mapear).toList();
    } finally {
      await connection.close();
    }
  }

  /// Insere os horários e devolve os registros criados (com o id do banco).
  Future<List<Map<String, dynamic>>> adicionar(
    String terapeutaId,
    List<HorarioDisponivel> horarios,
  ) async {
    final connection = await Database.connect();
    try {
      final criados = <Map<String, dynamic>>[];
      for (final h in horarios) {
        final result = await connection.execute(
          '''
          INSERT INTO app_disponibilidade (usr_ukey, data, inicio, fim)
          VALUES (:terapeuta, :data, :inicio, :fim)
          ''',
          {
            'terapeuta': terapeutaId,
            'data': h.data,
            'inicio': h.inicio,
            'fim': h.fim,
          },
        );
        criados.add({
          'id': result.lastInsertID.toInt(),
          'data': h.data,
          'inicio': h.inicio,
          'fim': h.fim,
          'clienteReservado': null,
        });
      }
      return criados;
    } finally {
      await connection.close();
    }
  }

  /// Altera um horário da própria terapeuta. Devolve false se não existir.
  Future<bool> atualizar(
    int id,
    String terapeutaId,
    HorarioDisponivel h,
  ) async {
    final connection = await Database.connect();
    try {
      final existe = await connection.execute(
        'SELECT id FROM app_disponibilidade WHERE id = :id AND usr_ukey = :terapeuta',
        {'id': id, 'terapeuta': terapeutaId},
      );
      if (existe.rows.isEmpty) return false;

      await connection.execute(
        '''
        UPDATE app_disponibilidade
        SET data = :data, inicio = :inicio, fim = :fim
        WHERE id = :id AND usr_ukey = :terapeuta
        ''',
        {
          'id': id,
          'terapeuta': terapeutaId,
          'data': h.data,
          'inicio': h.inicio,
          'fim': h.fim,
        },
      );
      return true;
    } finally {
      await connection.close();
    }
  }

  Future<void> remover(int id, String terapeutaId) async {
    final connection = await Database.connect();
    try {
      await connection.execute(
        'DELETE FROM app_disponibilidade WHERE id = :id AND usr_ukey = :terapeuta',
        {'id': id, 'terapeuta': terapeutaId},
      );
    } finally {
      await connection.close();
    }
  }

  Map<String, dynamic> _mapear(dynamic row) {
    final data = (row.colByName('data') as String?) ?? '';
    return {
      'id': int.tryParse(row.colByName('id') ?? '') ?? 0,
      'data': data.length >= 10 ? data.substring(0, 10) : data,
      'inicio': int.tryParse(row.colByName('inicio') ?? '') ?? 0,
      'fim': int.tryParse(row.colByName('fim') ?? '') ?? 0,
      'clienteReservado': row.colByName('cliente_reservado'),
    };
  }
}

/// Um horário vindo do app, já validado.
class HorarioDisponivel {
  const HorarioDisponivel({
    required this.data,
    required this.inicio,
    required this.fim,
  });

  /// AAAA-MM-DD
  final String data;
  final int inicio;
  final int fim;

  /// Lê e valida o JSON {data, inicio, fim}. Devolve null se for inválido.
  static HorarioDisponivel? deJson(Object? json) {
    if (json is! Map) return null;
    final data = json['data'];
    final inicio = json['inicio'];
    final fim = json['fim'];
    if (data is! String || inicio is! int || fim is! int) return null;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(data)) return null;
    if (DateTime.tryParse(data) == null) return null;
    if (inicio < 0 || fim > 24 * 60 || inicio >= fim) return null;
    return HorarioDisponivel(data: data, inicio: inicio, fim: fim);
  }
}
