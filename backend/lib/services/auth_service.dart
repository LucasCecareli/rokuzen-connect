import 'package:backend/repositories/auth_repository.dart';

class AuthService {
  final AuthRepository _repository;

  AuthService({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  Future<Map<String, dynamic>?> autenticar({
    required String login,
    required String senha,
  }) async {
    final loginInformado = login.trim();

    if (loginInformado.isEmpty || senha.isEmpty) {
      return null;
    }

    final usuarios =
        await _repository.buscarTerapeutasPorLogin(loginInformado);

    final candidatos = usuarios.where((usuario) {
      return usuario['senha'] == senha;
    }).toList();

    if (candidatos.isEmpty) {
      return null;
    }

    final autorizados = <Map<String, String?>>[];

    for (final usuario in candidatos) {
      final id = usuario['id'];

      if (id == null || id.isEmpty) {
        continue;
      }

      final possuiVinculo =
          await _repository.possuiVinculoComUnidade(id);

      if (possuiVinculo) {
        autorizados.add(usuario);
      }
    }

    // Não selecionar arbitrariamente entre contas diferentes.
    if (autorizados.length != 1) {
      return null;
    }

    final usuario = autorizados.single;
    final id = usuario['id']!;

    // Busca detalhes completos (unidade, turno, etc.)
    final detalhes = await _repository.buscarDetalhesTerapeuta(id);
    if (detalhes != null) {
      return detalhes;
    }

    return {
      'id': usuario['id'],
      'login': usuario['login'],
      'nome': usuario['nome'],
      'tipo': usuario['tipo'],
      'unidade': 'Golden Square',
      'inicioTurno': 10 * 60,
      'fimTurno': 16 * 60,
    };
  }

  Future<Map<String, dynamic>?> buscarPorId(String id) async {
    return _repository.buscarDetalhesTerapeuta(id);
  }

  /// true se existe exatamente um terapeuta com esse e-mail.
  Future<bool> emailCadastrado(String email) async {
    final ids = await _repository.buscarTerapeutasPorEmail(email.trim());
    return ids.length == 1;
  }

  /// Redefine a senha do terapeuta dono do e-mail. Devolve false se o e-mail
  /// não existir (ou se estiver em mais de uma conta).
  ///
  /// Mecanismo simplificado para a apresentação do projeto: não envia
  /// código de confirmação por e-mail.
  Future<bool> redefinirSenha(String email, String novaSenha) async {
    final ids = await _repository.buscarTerapeutasPorEmail(email.trim());
    if (ids.length != 1) return false;
    await _repository.alterarSenha(ids.single, novaSenha);
    return true;
  }

  Future<String?> buscarFoto(String id) => _repository.buscarFoto(id);

  Future<void> salvarFoto(String id, String? foto) =>
      _repository.salvarFoto(id, foto);
}
