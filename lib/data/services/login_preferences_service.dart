
import 'package:shared_preferences/shared_preferences.dart';

/// Gerencia a preferência "Lembrar de mim".
/// Armazena apenas o login, nunca a senha.
class LoginPreferencesService {
  static const String _chaveLogin = 'rokuzen_login_lembrado';
  static const String _chaveLembrar = 'rokuzen_lembrar_login';

  /// Recupera o login salvo, se a preferência estiver ativa.
  Future<String?> carregarLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final lembrar = prefs.getBool(_chaveLembrar) ?? false;

    if (!lembrar) return null;

    return prefs.getString(_chaveLogin);
  }

  /// Verifica se o usuário escolheu lembrar o login.
  Future<bool> deveLembrar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chaveLembrar) ?? false;
  }

  /// Salva apenas o login após autenticação bem-sucedida.
  Future<void> salvarLogin(String login) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_chaveLogin, login);
    await prefs.setBool(_chaveLembrar, true);
  }

  /// Remove o login salvo e desativa a preferência.
  Future<void> limparLogin() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_chaveLogin);
    await prefs.setBool(_chaveLembrar, false);
  }
}
