import 'dart:convert';

import 'package:backend/config/migracoes.dart';
import 'package:backend/repositories/atendimento_repository.dart';
import 'package:backend/repositories/disponibilidade_repository.dart';
import 'package:backend/repositories/paciente_repository.dart';
import 'package:backend/services/auth_service.dart';
import 'package:dotenv/dotenv.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

const _jsonHeaders = {
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 'no-store',
};

Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      const headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
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

Response _ok(Map<String, Object?> corpo) =>
    Response.ok(jsonEncode({'success': true, ...corpo}), headers: _jsonHeaders);

Response _erro(int codigo, String mensagem) => Response(
      codigo,
      body: jsonEncode({'success': false, 'message': mensagem}),
      headers: _jsonHeaders,
    );

/// Executa a rota e, em caso de exceção, registra no terminal e devolve 500
/// sem revelar detalhes do banco ao aplicativo.
Future<Response> _protegido(
  String descricao,
  Future<Response> Function() acao,
) async {
  try {
    return await acao();
  } on FormatException {
    return _erro(400, 'JSON inválido.');
  } catch (e) {
    print('Erro interno ao $descricao: $e');
    return _erro(500, 'Erro interno do servidor.');
  }
}

/// Lê o corpo JSON da requisição como mapa (ou null se não for um objeto).
Future<Map<String, dynamic>?> _corpo(Request request) async {
  final dados = jsonDecode(await request.readAsString());
  return dados is Map<String, dynamic> ? dados : null;
}

String? _texto(Object? valor) =>
    valor is String && valor.trim().isNotEmpty ? valor.trim() : null;

Future<void> main() async {
  final router = Router();
  final authService = AuthService();
  final pacienteRepository = PacienteRepository();
  final atendimentoRepository = AtendimentoRepository();
  final disponibilidadeRepository = DisponibilidadeRepository();

  // Tabelas próprias do app (disponibilidade e status dos atendimentos).
  try {
    await Migracoes.garantirTabelas();
  } catch (e) {
    print('Aviso: não foi possível criar as tabelas do app: $e');
  }

  router.get('/status', (Request request) {
    return _ok({'message': 'API Rokuzen funcionando'});
  });

  // ------------------------------------------------------------ login

  router.post('/auth/login', (Request request) {
    return _protegido('validar login', () async {
      final body = await _corpo(request);
      if (body == null) return _erro(400, 'Dados inválidos.');

      final login = body['login'];
      final senha = body['senha'];

      if (login is! String ||
          senha is! String ||
          login.trim().isEmpty ||
          senha.isEmpty) {
        return _erro(400, 'Informe login e senha.');
      }

      final usuario = await authService.autenticar(login: login, senha: senha);

      if (usuario == null) {
        return _erro(401, 'Credenciais inválidas ou acesso não autorizado.');
      }

      return _ok({'message': 'Credenciais validadas.', 'usuario': usuario});
    });
  });

  /// "Esqueci minha senha", passo 1: confere se o e-mail existe.
  /// POST /auth/verificar-email  {"email": "..."}
  router.post('/auth/verificar-email', (Request request) {
    return _protegido('verificar e-mail', () async {
      final email = _texto((await _corpo(request))?['email']);
      if (email == null) return _erro(400, 'Informe o e-mail.');
      final existe = await authService.emailCadastrado(email);
      return _ok({'encontrado': existe});
    });
  });

  /// "Esqueci minha senha", passo 2: grava a nova senha.
  /// POST /auth/redefinir-senha  {"email": "...", "novaSenha": "..."}
  router.post('/auth/redefinir-senha', (Request request) {
    return _protegido('redefinir senha', () async {
      final body = await _corpo(request);
      final email = _texto(body?['email']);
      final novaSenha = body?['novaSenha'];
      if (email == null ||
          novaSenha is! String ||
          novaSenha.length < 4 ||
          novaSenha.length > 50) {
        return _erro(400, 'Informe o e-mail e uma senha de 4 a 50 caracteres.');
      }
      final ok = await authService.redefinirSenha(email, novaSenha);
      if (!ok) return _erro(404, 'E-mail não encontrado.');
      return _ok({'message': 'Senha alterada.'});
    });
  });

  // -------------------------------------------------------- terapeutas

  router.get('/terapeutas/<id>', (Request request, String id) {
    return _protegido('buscar terapeuta $id', () async {
      final terapeuta = await authService.buscarPorId(id);
      if (terapeuta == null) return _erro(404, 'Terapeuta não encontrado.');
      return _ok({'terapeuta': terapeuta});
    });
  });

  /// Foto de perfil (tabela app_perfil).
  router.get('/terapeutas/<id>/foto', (Request request, String id) {
    return _protegido('buscar foto de $id', () async {
      return _ok({'foto': await authService.buscarFoto(id)});
    });
  });

  /// PUT /terapeutas/<id>/foto  {"foto": "data:image/jpeg;base64,..." | "preset_lotus" | null}
  router.put('/terapeutas/<id>/foto', (Request request, String id) {
    return _protegido('salvar foto de $id', () async {
      final body = await _corpo(request);
      if (body == null) return _erro(400, 'Dados inválidos.');
      final foto = body['foto'];
      if (foto != null && (foto is! String || foto.length > 3000000)) {
        return _erro(400, 'Foto inválida ou grande demais.');
      }
      await authService.salvarFoto(id, _texto(foto));
      return _ok({'message': 'Foto salva.'});
    });
  });

  /// Expediente de cada dia (escala oficial da Rokuzen, tabela events).
  /// GET /terapeutas/<id>/escala?inicio=AAAA-MM-DD&fim=AAAA-MM-DD
  router.get('/terapeutas/<id>/escala', (Request request, String id) {
    return _protegido('buscar escala de $id', () async {
      final q = request.url.queryParameters;
      final inicio = _texto(q['inicio']);
      final fim = _texto(q['fim']);
      if (inicio == null || fim == null) {
        return _erro(400, 'Informe os parâmetros inicio e fim.');
      }
      final dias = await atendimentoRepository.buscarEscala(
        terapeutaId: id,
        inicio: inicio,
        fim: fim,
      );
      return _ok({'escala': dias});
    });
  });

  // ------------------------------------------------------ atendimentos

  router.get('/atendimentos/proximo', (Request request) {
    return _protegido('buscar próximo atendimento', () async {
      final q = request.url.queryParameters;
      final terapeutaId = _texto(q['terapeuta']);
      final apartir = q['apartir'] ?? DateTime.now().toIso8601String();

      if (terapeutaId == null) {
        return _erro(400, 'Informe o parâmetro terapeuta.');
      }

      final atendimento = await atendimentoRepository.buscarProximoAtendimento(
        terapeutaId: terapeutaId,
        aPartirDe: apartir,
      );
      return _ok({'atendimento': atendimento});
    });
  });

  router.get('/atendimentos', (Request request) {
    return _protegido('listar atendimentos', () async {
      final q = request.url.queryParameters;
      final terapeutaId = _texto(q['terapeuta']);
      if (terapeutaId == null) {
        return _erro(400, 'Informe o parâmetro terapeuta.');
      }

      final atendimentos = await atendimentoRepository.listarAtendimentos(
        terapeutaId: terapeutaId,
        pacienteId: q['paciente'],
        inicio: q['inicio'],
        fim: q['fim'],
      );
      return _ok({'atendimentos': atendimentos});
    });
  });

  /// Grava o status de um atendimento (iniciado, concluído...).
  /// PUT /atendimentos/<id>/status  {"terapeuta": "...", "status": "andamento"}
  router.put('/atendimentos/<id>/status', (Request request, String id) {
    return _protegido('salvar status do atendimento $id', () async {
      final body = await _corpo(request);
      final terapeutaId = _texto(body?['terapeuta']);
      final status = _texto(body?['status']);

      if (terapeutaId == null ||
          status == null ||
          !AtendimentoRepository.statusValidos.contains(status)) {
        return _erro(400, 'Informe terapeuta e um status válido.');
      }

      final salvo = await atendimentoRepository.salvarStatus(
        atendimentoId: id,
        terapeutaId: terapeutaId,
        status: status,
        iniciadoEm: _texto(body?['iniciadoEm']),
      );
      if (!salvo) return _erro(404, 'Atendimento não encontrado.');
      return _ok({'status': status});
    });
  });

  // --------------------------------------------------------- pacientes

  /// Pacientes da terapeuta.
  /// GET /pacientes?terapeuta=<id>&agora=<data e hora do app>
  router.get('/pacientes', (Request request) {
    return _protegido('listar pacientes', () async {
      final q = request.url.queryParameters;
      final terapeutaId = _texto(q['terapeuta']);
      if (terapeutaId == null) {
        return _erro(400, 'Informe o parâmetro terapeuta.');
      }
      final pacientes = await pacienteRepository.listarPacientes(
        terapeutaId: terapeutaId,
        agora: q['agora'],
      );
      return _ok({'pacientes': pacientes});
    });
  });

  router.post('/pacientes', (Request request) {
    return _protegido('cadastrar paciente', () async {
      final body = await _corpo(request);
      final terapeutaId = _texto(body?['terapeuta']);
      final dados = DadosPaciente.deJson(body);
      if (dados == null || terapeutaId == null) {
        return _erro(400, 'Dados do paciente inválidos.');
      }

      final paciente =
          await pacienteRepository.cadastrar(dados, terapeutaId: terapeutaId);
      return _ok({'paciente': paciente});
    });
  });

  router.put('/pacientes/<id>', (Request request, String id) {
    return _protegido('editar paciente $id', () async {
      final dados = DadosPaciente.deJson(await _corpo(request));
      if (dados == null) return _erro(400, 'Dados do paciente inválidos.');

      final ok = await pacienteRepository.atualizar(id, dados);
      if (!ok) return _erro(404, 'Paciente não encontrado.');
      return _ok({'message': 'Paciente atualizado.'});
    });
  });

  /// Histórico do paciente com a terapeuta logada.
  /// GET /pacientes/<id>/atendimentos?terapeuta=<id>
  router.get('/pacientes/<id>/atendimentos', (Request request, String id) {
    return _protegido('buscar atendimentos do paciente $id', () async {
      final terapeutaId = _texto(request.url.queryParameters['terapeuta']);
      if (terapeutaId == null) {
        return _erro(400, 'Informe o parâmetro terapeuta.');
      }
      final atendimentos = await atendimentoRepository.listarAtendimentos(
        terapeutaId: terapeutaId,
        pacienteId: id,
      );
      return _ok({'atendimentos': atendimentos});
    });
  });

  // -------------------------------------------------- disponibilidade

  /// GET /disponibilidades?terapeuta=<id>
  router.get('/disponibilidades', (Request request) {
    return _protegido('listar disponibilidades', () async {
      final terapeutaId = _texto(request.url.queryParameters['terapeuta']);
      if (terapeutaId == null) {
        return _erro(400, 'Informe o parâmetro terapeuta.');
      }
      final itens = await disponibilidadeRepository.listar(terapeutaId);
      return _ok({'disponibilidades': itens});
    });
  });

  /// POST /disponibilidades
  /// {"terapeuta": "...", "horarios": [{"data": "2026-11-12", "inicio": 1140, "fim": 1260}]}
  router.post('/disponibilidades', (Request request) {
    return _protegido('adicionar disponibilidades', () async {
      final body = await _corpo(request);
      final terapeutaId = _texto(body?['terapeuta']);
      final lista = body?['horarios'];

      if (terapeutaId == null || lista is! List || lista.isEmpty) {
        return _erro(400, 'Informe terapeuta e horarios.');
      }
      if (lista.length > 120) {
        return _erro(400, 'Muitos horários de uma vez.');
      }

      final horarios = <HorarioDisponivel>[];
      for (final item in lista) {
        final h = HorarioDisponivel.deJson(item);
        if (h == null) return _erro(400, 'Horário inválido.');
        horarios.add(h);
      }

      final criados =
          await disponibilidadeRepository.adicionar(terapeutaId, horarios);
      return _ok({'disponibilidades': criados});
    });
  });

  /// PUT /disponibilidades/<id>
  /// {"terapeuta": "...", "data": "2026-11-12", "inicio": 1140, "fim": 1260}
  router.put('/disponibilidades/<id>', (Request request, String id) {
    return _protegido('editar disponibilidade $id', () async {
      final numero = int.tryParse(id);
      final body = await _corpo(request);
      final terapeutaId = _texto(body?['terapeuta']);
      final h = HorarioDisponivel.deJson(body);

      if (numero == null || terapeutaId == null || h == null) {
        return _erro(400, 'Dados do horário inválidos.');
      }

      final ok =
          await disponibilidadeRepository.atualizar(numero, terapeutaId, h);
      if (!ok) return _erro(404, 'Horário não encontrado.');
      return _ok({'message': 'Horário atualizado.'});
    });
  });

  /// DELETE /disponibilidades/<id>?terapeuta=<id>
  router.delete('/disponibilidades/<id>', (Request request, String id) {
    return _protegido('remover disponibilidade $id', () async {
      final numero = int.tryParse(id);
      final terapeutaId = _texto(request.url.queryParameters['terapeuta']);
      if (numero == null || terapeutaId == null) {
        return _erro(400, 'Informe o horário e o terapeuta.');
      }
      await disponibilidadeRepository.remover(numero, terapeutaId);
      return _ok({'message': 'Horário removido.'});
    });
  });

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addHandler(router.call);

  // Por padrão só este computador acessa o backend. Para testar no iPhone
  // pela rede (Safari), coloque SERVER_HOST=0.0.0.0 no .env.
  final env = DotEnv()..load();
  final host = env['SERVER_HOST'] ?? '127.0.0.1';

  final server = await shelf_io.serve(handler, host, 8081);

  print(
    'Servidor rodando em '
    'http://${server.address.host}:${server.port}',
  );
}
