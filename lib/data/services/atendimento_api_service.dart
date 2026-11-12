import '../../core/app_config.dart';
import '../models/modelos.dart';
import 'api_cliente.dart';

/// Atendimentos da terapeuta (tabela atd), status gravado pelo app e escala
/// de expediente, através do backend.
class AtendimentoApiService {
  Future<List<Atendimento>> buscarAtendimentos({
    required String terapeutaId,
    DateTime? inicio,
    DateTime? fim,
  }) async {
    final dados = await ApiCliente.get('/atendimentos', {
      'terapeuta': terapeutaId,
      if (inicio != null) 'inicio': inicio.toIso8601String(),
      if (fim != null) 'fim': fim.toIso8601String(),
    });
    return _lista(dados['atendimentos']);
  }

  Future<Atendimento?> buscarProximoAtendimento({
    required String terapeutaId,
    required DateTime aPartirDe,
  }) async {
    final dados = await ApiCliente.get('/atendimentos/proximo', {
      'terapeuta': terapeutaId,
      'apartir': aPartirDe.toIso8601String(),
    });
    final item = dados['atendimento'];
    return item is Map<String, dynamic> ? _paraAtendimento(item) : null;
  }

  /// Histórico do paciente com a terapeuta, do mais recente ao mais antigo.
  Future<List<Atendimento>> buscarAtendimentosDoPaciente({
    required String terapeutaId,
    required String pacienteId,
  }) async {
    final dados = await ApiCliente.get(
      '/pacientes/${Uri.encodeComponent(pacienteId)}/atendimentos',
      {'terapeuta': terapeutaId},
    );
    return _lista(dados['atendimentos']);
  }

  /// Grava o status (iniciado, concluído...) na tabela do app.
  Future<void> salvarStatus({
    required String terapeutaId,
    required String atendimentoId,
    required StatusAtendimento status,
  }) async {
    await ApiCliente.put(
      '/atendimentos/${Uri.encodeComponent(atendimentoId)}/status',
      {'terapeuta': terapeutaId, 'status': status.name},
    );
  }

  /// Expediente de cada dia entre [inicio] e [fim] (fim exclusivo).
  Future<Map<DateTime, (int, int)>> buscarEscala({
    required String terapeutaId,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final dados = await ApiCliente.get(
      '/terapeutas/${Uri.encodeComponent(terapeutaId)}/escala',
      {'inicio': _data(inicio), 'fim': _data(fim)},
    );
    final lista = dados['escala'];
    final escala = <DateTime, (int, int)>{};
    if (lista is List) {
      for (final item in lista) {
        if (item is! Map) continue;
        final dia = DateTime.tryParse('${item['data']}');
        final ini = item['inicio'];
        final f = item['fim'];
        if (dia == null || ini is! int || f is! int || f <= ini) continue;
        escala[DateTime(dia.year, dia.month, dia.day)] = (ini, f);
      }
    }
    return escala;
  }

  // ---------------------------------------------------------------------

  static String _data(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  List<Atendimento> _lista(Object? lista) {
    if (lista is! List) {
      throw const ApiException('Resposta inválida do servidor.');
    }
    return [
      for (final item in lista)
        if (item is Map<String, dynamic>) _paraAtendimento(item),
    ];
  }

  Atendimento _paraAtendimento(Map<String, dynamic> json) {
    final inicioStr = json['inicio']?.toString();
    final inicio = inicioStr != null
        ? (DateTime.tryParse(inicioStr.replaceAll(' ', 'T')) ?? DateTime.now())
        : DateTime.now();

    final duracao = json['duracao'] is int ? json['duracao'] as int : 30;
    final adicional =
        json['adicionalAuriculo'] is int ? json['adicionalAuriculo'] as int : 0;
    final fim = inicio.add(Duration(minutes: duracao + adicional));

    return Atendimento(
      id: json['id']?.toString() ?? '',
      pacienteId: json['pacienteId']?.toString() ?? '',
      pacienteNome: json['pacienteNome']?.toString() ?? 'Paciente',
      inicio: inicio,
      servico: _paraServico(json['servico']?.toString() ?? 'Maca'),
      duracao: duracao,
      adicionalAuriculo: adicional,
      unidade: json['unidade']?.toString() ?? 'Rokuzen',
      sala: json['sala']?.toString() ?? '',
      status: _paraStatus(json['status']?.toString(), fim),
    );
  }

  Servico _paraServico(String texto) {
    final t = texto.toLowerCase();
    if (t.contains('quick') || t.contains('cadeira')) {
      return Servico.quickMassage;
    }
    if (t.contains('reflex')) return Servico.reflexologiaPodal;
    if (t.contains('auriculo') || t.contains('aurículo')) {
      return Servico.auriculoterapia;
    }
    return Servico.maca;
  }

  /// Usa o status gravado pelo app. Sem registro, deduz pelo horário: o que
  /// já terminou conta como concluído; o resto, como confirmado.
  StatusAtendimento _paraStatus(String? salvo, DateTime fim) {
    for (final s in StatusAtendimento.values) {
      if (s.name == salvo) return s;
    }
    return fim.isAfter(agora())
        ? StatusAtendimento.confirmado
        : StatusAtendimento.concluido;
  }
}
