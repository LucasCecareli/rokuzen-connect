import 'dart:convert';

import 'package:backend/repositories/atendimento_repository.dart';
import 'package:backend/repositories/paciente_repository.dart';
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

      return response.change(headers: {...response.headers, ...headers});
    };
  };
}

Future<void> main() async {
  final router = Router();
  final authService = AuthService();
  final pacienteRepository = PacienteRepository();
  final atendimentoRepository = AtendimentoRepository();

  Map<String, String> jsonHeaders = {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  };

  router.get('/status', (Request request) {
    return Response.ok(
      jsonEncode({'success': true, 'message': 'API Rokuzen funcionando'}),
      headers: jsonHeaders,
    );
  });

  router.get('/pacientes', (Request request) async {
    try {
      final pacientes = await pacienteRepository.listarPacientes();

      return Response.ok(
        jsonEncode({'success': true, 'pacientes': pacientes}),
        headers: jsonHeaders,
      );
    } catch (e) {
      // Não revelar detalhes do banco ao aplicativo.
      print('Erro interno ao listar pacientes: $e');

      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Erro interno do servidor.',
        }),
        headers: jsonHeaders,
      );
    }
  });

  router.get('/terapeutas/<id>', (Request request, String id) async {
    try {
      final terapeuta = await authService.buscarPorId(id);

      if (terapeuta == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Terapeuta não encontrado.'}),
          headers: jsonHeaders,
        );
      }

      return Response.ok(
        jsonEncode({'success': true, 'terapeuta': terapeuta}),
        headers: jsonHeaders,
      );
    } catch (e) {
      print('Erro interno ao buscar terapeuta $id: $e');

      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Erro interno do servidor.',
        }),
        headers: jsonHeaders,
      );
    }
  });

  router.get('/atendimentos/proximo', (Request request) async {
    try {
      final terapeutaId = request.url.queryParameters['terapeuta'];
      final apartir = request.url.queryParameters['apartir'] ??
          DateTime.now().toIso8601String();

      if (terapeutaId == null || terapeutaId.trim().isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'success': false,
            'message': 'Informe o parâmetro terapeuta.',
          }),
          headers: jsonHeaders,
        );
      }

      final atendimento = await atendimentoRepository.buscarProximoAtendimento(
        terapeutaId: terapeutaId,
        aPartirDe: apartir,
      );

      return Response.ok(
        jsonEncode({'success': true, 'atendimento': atendimento}),
        headers: jsonHeaders,
      );
    } catch (e) {
      print('Erro interno ao buscar próximo atendimento: $e');

      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Erro interno do servidor.',
        }),
        headers: jsonHeaders,
      );
    }
  });

  router.get('/atendimentos', (Request request) async {
    try {
      final terapeutaId = request.url.queryParameters['terapeuta'];
      final pacienteId = request.url.queryParameters['paciente'];
      final inicio = request.url.queryParameters['inicio'];
      final fim = request.url.queryParameters['fim'];

      final atendimentos = await atendimentoRepository.listarAtendimentos(
        terapeutaId: terapeutaId,
        pacienteId: pacienteId,
        inicio: inicio,
        fim: fim,
      );

      return Response.ok(
        jsonEncode({'success': true, 'atendimentos': atendimentos}),
        headers: jsonHeaders,
      );
    } catch (e) {
      print('Erro interno ao listar atendimentos: $e');

      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Erro interno do servidor.',
        }),
        headers: jsonHeaders,
      );
    }
  });

  router.get('/pacientes/<id>/atendimentos', (Request request, String id) async {
    try {
      final atendimentos = await atendimentoRepository.listarAtendimentos(
        pacienteId: id,
      );

      return Response.ok(
        jsonEncode({'success': true, 'atendimentos': atendimentos}),
        headers: jsonHeaders,
      );
    } catch (e) {
      print('Erro interno ao buscar atendimentos do paciente $id: $e');

      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Erro interno do servidor.',
        }),
        headers: jsonHeaders,
      );
    }
  });

  router.post('/auth/login', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());

      if (body is! Map<String, dynamic>) {
        return Response(
          400,
          body: jsonEncode({'success': false, 'message': 'Dados inválidos.'}),
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

      final usuario = await authService.autenticar(login: login, senha: senha);

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
        body: jsonEncode({'success': false, 'message': 'JSON inválido.'}),
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

  final server = await shelf_io.serve(handler, '127.0.0.1', 8081);

  print(
    'Servidor rodando em '
    'http://${server.address.host}:${server.port}',
  );
}
