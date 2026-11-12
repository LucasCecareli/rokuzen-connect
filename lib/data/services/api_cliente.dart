import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api_service.dart';

/// Erro de comunicação com o backend, com uma mensagem para mostrar na tela.
class ApiException implements Exception {
  const ApiException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Chamadas HTTP ao backend do grupo (JSON, com tempo limite).
abstract final class ApiCliente {
  static const _tempoLimite = Duration(seconds: 20);
  static const _cabecalhos = {'Content-Type': 'application/json'};

  static Uri _uri(String caminho, [Map<String, String>? query]) =>
      Uri.parse('${AuthApiService.baseUrl}$caminho')
          .replace(queryParameters: query);

  static Future<Map<String, dynamic>> get(
    String caminho, [
    Map<String, String>? query,
  ]) =>
      _enviar(() => http.get(_uri(caminho, query)));

  static Future<Map<String, dynamic>> post(String caminho, Object corpo) =>
      _enviar(() => http.post(_uri(caminho),
          headers: _cabecalhos, body: jsonEncode(corpo)));

  static Future<Map<String, dynamic>> put(String caminho, Object corpo) =>
      _enviar(() => http.put(_uri(caminho),
          headers: _cabecalhos, body: jsonEncode(corpo)));

  static Future<Map<String, dynamic>> delete(
    String caminho, [
    Map<String, String>? query,
  ]) =>
      _enviar(() => http.delete(_uri(caminho, query)));

  static Future<Map<String, dynamic>> _enviar(
    Future<http.Response> Function() requisicao,
  ) async {
    final http.Response resposta;
    try {
      resposta = await requisicao().timeout(_tempoLimite);
    } catch (_) {
      throw const ApiException(
        'Sem conexão com o servidor. Verifique se o backend está ligado.',
      );
    }

    Object? dados;
    try {
      dados = jsonDecode(utf8.decode(resposta.bodyBytes));
    } catch (_) {
      dados = null;
    }

    if (dados is Map<String, dynamic> &&
        resposta.statusCode == 200 &&
        dados['success'] == true) {
      return dados;
    }

    final mensagem = dados is Map<String, dynamic> && dados['message'] is String
        ? dados['message'] as String
        : 'O servidor respondeu com erro (${resposta.statusCode}).';
    throw ApiException(mensagem);
  }
}
