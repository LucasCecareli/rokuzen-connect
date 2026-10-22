
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8081';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8081';
    }

    return 'http://127.0.0.1:8081';
  }

  Future<Map<String, dynamic>> autenticar({
    required String login,
    required String senha,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'login': login.trim(),
              'senha': senha,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final dados = jsonDecode(response.body);

      if (dados is! Map<String, dynamic>) {
        throw const FormatException('Resposta inválida da API.');
      }

      if (response.statusCode == 200 && dados['success'] == true) {
        return dados;
      }

      if (response.statusCode == 400 || response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Login ou senha incorretos.',
        };
      }

      throw Exception('Falha na autenticação. Código: ${response.statusCode}');
    } catch (erro) {
      if (erro is FormatException) {
        throw Exception('A API retornou uma resposta inválida.');
      }

      rethrow;
    }
  }
}
