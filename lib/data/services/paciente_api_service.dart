import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/modelos.dart';
import 'auth_api_service.dart';

/// Busca os pacientes (clientes) no backend da Rokuzen. Só leitura.
class PacienteApiService {
  Future<List<Paciente>> listarPacientes() async {
    final response = await http
        .get(Uri.parse('${AuthApiService.baseUrl}/pacientes'))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'Falha ao carregar pacientes. Código: ${response.statusCode}',
      );
    }

    final dados = jsonDecode(utf8.decode(response.bodyBytes));
    final lista = dados is Map<String, dynamic> ? dados['pacientes'] : null;

    if (lista is! List) {
      throw const FormatException('Resposta inválida da API.');
    }

    return [
      for (final item in lista)
        if (item is Map<String, dynamic>) _paraPaciente(item),
    ];
  }

  Paciente _paraPaciente(Map<String, dynamic> json) {
    final nascimento = json['nascimento'];

    return Paciente(
      id: '${json['id']}',
      nome: (json['nome'] as String?) ?? 'Sem nome',
      telefone: (json['telefone'] as String?) ?? '',
      email: json['email'] as String?,
      nascimento: nascimento is String ? DateTime.tryParse(nascimento) : null,
    );
  }
}