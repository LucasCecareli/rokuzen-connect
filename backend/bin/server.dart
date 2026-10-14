import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final router = Router();

  router.get('/status', (Request request) {
    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'API Rokuzen funcionando',
      }),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
    );
  });

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final server = await shelf_io.serve(
    handler,
    'localhost',
    8080,
  );

  print('Servidor rodando em http://${server.address.host}:${server.port}');
}