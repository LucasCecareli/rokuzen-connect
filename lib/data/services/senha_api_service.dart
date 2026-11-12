import 'api_cliente.dart';

/// "Esqueci minha senha" (versão simplificada para a apresentação do
/// projeto: não envia código de confirmação por e-mail).
class SenhaApiService {
  /// true se o e-mail pertence a um terapeuta cadastrado.
  Future<bool> emailExiste(String email) async {
    final dados =
        await ApiCliente.post('/auth/verificar-email', {'email': email.trim()});
    return dados['encontrado'] == true;
  }

  /// Grava a nova senha. Lança [ApiException] se não der certo.
  Future<void> redefinir(String email, String novaSenha) async {
    await ApiCliente.post('/auth/redefinir-senha', {
      'email': email.trim(),
      'novaSenha': novaSenha,
    });
  }
}
