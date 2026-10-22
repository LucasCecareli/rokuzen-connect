
import 'package:backend/repositories/auth_repository.dart';

class AuthService {
  final AuthRepository _repository;

  AuthService({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  Future<Map<String, String?>?> autenticar({
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

    // A senha nunca deve ser devolvida à aplicação Flutter.
    return {
      'id': usuario['id'],
      'login': usuario['login'],
      'nome': usuario['nome'],
      'tipo': usuario['tipo'],
    };
  }
}
