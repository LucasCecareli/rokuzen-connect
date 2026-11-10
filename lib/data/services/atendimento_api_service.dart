import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/modelos.dart';
import 'auth_api_service.dart';

/// Busca os atendimentos reais na tabela atd através do backend da Rokuzen.
class AtendimentoApiService {
  Future<List<Atendimento>> buscarAtendimentos({
    required String terapeutaId,
    DateTime? inicio,
    DateTime? fim,
  }) async {
    final queryParams = <String, String>{
      'terapeuta': terapeutaId,
    };

    if (inicio != null) {
      queryParams['inicio'] = inicio.toIso8601String();
    }
    if (fim != null) {
      queryParams['fim'] = fim.toIso8601String();
    }

    final uri = Uri.parse('${AuthApiService.baseUrl}/atendimentos')
        .replace(queryParameters: queryParams);

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Falha ao carregar atendimentos. Código: ${response.statusCode}',
      );
    }

    final dados = jsonDecode(utf8.decode(response.bodyBytes));
    final lista = dados is Map<String, dynamic> ? dados['atendimentos'] : null;

    if (lista is! List) {
      throw const FormatException('Resposta inválida da API de atendimentos.');
    }

    return [
      for (final item in lista)
        if (item is Map<String, dynamic>) _paraAtendimento(item),
    ];
  }

  Future<Atendimento?> buscarProximoAtendimento({
    required String terapeutaId,
    required DateTime aPartirDe,
  }) async {
    final uri = Uri.parse('${AuthApiService.baseUrl}/atendimentos/proximo')
        .replace(queryParameters: {
      'terapeuta': terapeutaId,
      'apartir': aPartirDe.toIso8601String(),
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Falha ao buscar próximo atendimento. Código: ${response.statusCode}',
      );
    }

    final dados = jsonDecode(utf8.decode(response.bodyBytes));
    final item = dados is Map<String, dynamic> ? dados['atendimento'] : null;

    if (item == null) return null;
    if (item is Map<String, dynamic>) {
      return _paraAtendimento(item);
    }

    return null;
  }

  Future<List<Atendimento>> buscarAtendimentosDoPaciente(
    String pacienteId,
  ) async {
    final uri = Uri.parse(
      '${AuthApiService.baseUrl}/pacientes/$pacienteId/atendimentos',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Falha ao buscar atendimentos do paciente. Código: ${response.statusCode}',
      );
    }

    final dados = jsonDecode(utf8.decode(response.bodyBytes));
    final lista = dados is Map<String, dynamic> ? dados['atendimentos'] : null;

    if (lista is! List) {
      throw const FormatException('Resposta inválida da API de atendimentos.');
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

    final servicoTexto = json['servico']?.toString() ?? 'Maca';
    final servico = _paraServico(servicoTexto);

    final statusTexto = json['status']?.toString();
    final status = _paraStatus(statusTexto);

    return Atendimento(
      id: json['id']?.toString() ?? '',
      pacienteId: json['pacienteId']?.toString() ?? '',
      pacienteNome: json['pacienteNome']?.toString() ?? 'Paciente',
      inicio: inicio,
      servico: servico,
      duracao: json['duracao'] as int? ?? 30,
      adicionalAuriculo: json['adicionalAuriculo'] as int? ?? 0,
      unidade: json['unidade']?.toString() ?? 'Golden Square',
      sala: json['sala']?.toString() ?? 'Sala 1',
      status: status,
    );
  }

  Servico _paraServico(String texto) {
    final t = texto.toLowerCase();
    if (t.contains('quick') || t.contains('cadeira')) {
      return Servico.quickMassage;
    }
    if (t.contains('reflex')) {
      return Servico.reflexologiaPodal;
    }
    if (t.contains('auriculo') || t.contains('aurículo')) {
      return Servico.auriculoterapia;
    }
    return Servico.maca;
  }

  StatusAtendimento _paraStatus(String? texto) {
    return switch (texto?.toLowerCase()) {
      'andamento' || 'em andamento' => StatusAtendimento.andamento,
      'concluido' || 'concluído' => StatusAtendimento.concluido,
      'cancelado' => StatusAtendimento.cancelado,
      'faltou' => StatusAtendimento.faltou,
      'pendente' => StatusAtendimento.pendente,
      _ => StatusAtendimento.confirmado,
    };
  }
}
