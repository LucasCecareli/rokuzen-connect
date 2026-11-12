import '../models/modelos.dart';
import 'api_cliente.dart';

/// Horários particulares da terapeuta (tabela app_disponibilidade).
class DisponibilidadeApiService {
  Future<List<Disponibilidade>> listar(String terapeutaId) async {
    final dados = await ApiCliente.get(
      '/disponibilidades',
      {'terapeuta': terapeutaId},
    );
    return _lista(dados['disponibilidades']);
  }

  /// Grava os horários e devolve os registros criados (com o id do banco).
  Future<List<Disponibilidade>> adicionar(
    String terapeutaId,
    List<Disponibilidade> novas,
  ) async {
    final dados = await ApiCliente.post('/disponibilidades', {
      'terapeuta': terapeutaId,
      'horarios': [for (final d in novas) _paraJson(d)],
    });
    return _lista(dados['disponibilidades']);
  }

  Future<void> atualizar(String terapeutaId, Disponibilidade d) async {
    await ApiCliente.put('/disponibilidades/${d.id}', {
      'terapeuta': terapeutaId,
      ..._paraJson(d),
    });
  }

  Future<void> remover(String terapeutaId, int id) async {
    await ApiCliente.delete('/disponibilidades/$id', {'terapeuta': terapeutaId});
  }

  Map<String, Object> _paraJson(Disponibilidade d) => {
        'data': '${d.data.year.toString().padLeft(4, '0')}-'
            '${d.data.month.toString().padLeft(2, '0')}-'
            '${d.data.day.toString().padLeft(2, '0')}',
        'inicio': d.inicio,
        'fim': d.fim,
      };

  List<Disponibilidade> _lista(Object? lista) {
    if (lista is! List) {
      throw const ApiException('Resposta inválida do servidor.');
    }
    final itens = <Disponibilidade>[];
    for (final item in lista) {
      if (item is! Map) continue;
      final id = item['id'];
      final dia = DateTime.tryParse('${item['data']}');
      final ini = item['inicio'];
      final fim = item['fim'];
      if (id is! int || dia == null || ini is! int || fim is! int) continue;
      final cliente = item['clienteReservado'];
      itens.add(Disponibilidade(
        id: id,
        data: DateTime(dia.year, dia.month, dia.day),
        inicio: ini,
        fim: fim,
        clienteReservado:
            cliente is String && cliente.trim().isNotEmpty ? cliente : null,
      ));
    }
    return itens;
  }
}
