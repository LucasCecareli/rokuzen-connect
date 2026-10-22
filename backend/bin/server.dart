
import 'dart:convert';

import 'package:backend/services/auth_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      const headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      };

      if (request.method == 'OPTIONS') {
        return Response(204, headers: headers);
      }

      final response = await innerHandler(request);

      return response.change(
        headers: {
          ...response.headers,
          ...headers,
        },
      );
    };
  };
}
Future<void> main() async {
  final router = Router();
  final authService = AuthService();

  Map<String, String> jsonHeaders = {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  };

  router.get('/status', (Request request) {
    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'API Rokuzen funcionando',
      }),
      headers: jsonHeaders,
    );
  });

  router.post('/auth/login', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());

      if (body is! Map<String, dynamic>) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'Dados inválidos.',
          }),
          headers: jsonHeaders,
        );
      }

      final login = body['login'];
      final senha = body['senha'];

      if (login is! String ||
          senha is! String ||
          login.trim().isEmpty ||
          senha.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'Informe login e senha.',
          }),
          headers: jsonHeaders,
        );
      }

      final usuario = await authService.autenticar(
        login: login,
        senha: senha,
      );

      if (usuario == null) {
        return Response(
          401,
          body: jsonEncode({
            'success': false,
            'message': 'Credenciais inválidas ou acesso não autorizado.',
          }),
          headers: jsonHeaders,
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Credenciais validadas.',
          'usuario': usuario,
        }),
        headers: jsonHeaders,
      );
    } on FormatException {
      return Response(
        400,
        body: jsonEncode({
          'success': false,
          'message': 'JSON inválido.',
        }),
        headers: jsonHeaders,
      );
    } catch (e) {
      // Não revelar detalhes do banco ao aplicativo.
      print('Erro interno ao validar login: $e');

      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Erro interno do servidor.',
        }),
        headers: jsonHeaders,
      );
    }
  });

  final handler = Pipeline()
    .addMiddleware(logRequests())
    .addMiddleware(corsMiddleware())
    .addHandler(router.call);

  final server = await shelf_io.serve(
  handler,
  '127.0.0.1',
  8081,
);

  print(
    'Servidor rodando em '
    'http://${server.address.host}:${server.port}',
  );
}
