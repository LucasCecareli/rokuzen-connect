import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gerencia a foto e customizações de perfil do terapeuta conectado.
class PerfilService {
  static final ValueNotifier<String?> fotoNotifier = ValueNotifier<String?>(null);
  static String? _ultimoTerapeutaId;

  static Future<void> inicializar(String terapeutaId) async {
    _ultimoTerapeutaId = terapeutaId;
    final prefs = await SharedPreferences.getInstance();
    fotoNotifier.value = prefs.getString('foto_terapeuta_$terapeutaId');
  }

  static Future<void> salvarFoto(String? foto) async {
    final id = _ultimoTerapeutaId;
    if (id == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (foto == null || foto.trim().isEmpty) {
      await prefs.remove('foto_terapeuta_$id');
      fotoNotifier.value = null;
    } else {
      await prefs.setString('foto_terapeuta_$id', foto.trim());
      fotoNotifier.value = foto.trim();
    }
  }

  static Future<void> limpar() async {
    _ultimoTerapeutaId = null;
    fotoNotifier.value = null;
  }
}
