import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_cliente.dart';

/// Foto de perfil do terapeuta conectado.
///
/// A foto fica salva no banco (tabela app_perfil, pelo backend), então
/// aparece em qualquer aparelho. Uma cópia fica no aparelho só para a foto
/// aparecer na hora, enquanto o banco responde.
class PerfilService {
  static final ValueNotifier<String?> fotoNotifier = ValueNotifier<String?>(null);
  static String? _ultimoTerapeutaId;

  static String _chave(String id) => 'foto_terapeuta_$id';

  static String _caminho(String id) =>
      '/terapeutas/${Uri.encodeComponent(id)}/foto';

  /// Carrega a foto do terapeuta (só na primeira vez para cada terapeuta).
  static Future<void> inicializar(String terapeutaId) async {
    if (_ultimoTerapeutaId == terapeutaId) return;
    _ultimoTerapeutaId = terapeutaId;

    // 1) Cópia do aparelho, para não piscar as iniciais.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_ultimoTerapeutaId == terapeutaId) {
        fotoNotifier.value = prefs.getString(_chave(terapeutaId));
      }
    } catch (_) {}

    // 2) Foto do banco (vale a do banco).
    try {
      final dados = await ApiCliente.get(_caminho(terapeutaId));
      if (_ultimoTerapeutaId != terapeutaId) return;
      final foto = dados['foto'];
      final valor = foto is String && foto.isNotEmpty ? foto : null;
      fotoNotifier.value = valor;
      await _guardarNoAparelho(terapeutaId, valor);
    } catch (_) {
      // Sem servidor: fica com a cópia do aparelho.
    }
  }

  /// Salva a foto no banco (null remove). Lança [ApiException] se falhar.
  static Future<void> salvarFoto(String? foto) async {
    final id = _ultimoTerapeutaId;
    if (id == null) return;

    final valor = foto == null || foto.trim().isEmpty ? null : foto.trim();
    await ApiCliente.put(_caminho(id), {'foto': valor});
    fotoNotifier.value = valor;
    await _guardarNoAparelho(id, valor);
  }

  static Future<void> _guardarNoAparelho(String id, String? foto) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (foto == null) {
        await prefs.remove(_chave(id));
      } else {
        await prefs.setString(_chave(id), foto);
      }
    } catch (_) {}
  }

  static Future<void> limpar() async {
    _ultimoTerapeutaId = null;
    fotoNotifier.value = null;
  }
}
