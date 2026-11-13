import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_theme.dart';
import 'data/repositorio.dart';
import 'data/services/admin_api_service.dart';
import 'data/services/perfil_service.dart';
import 'features/admin/tela_admin.dart';
import 'features/login/tela_login.dart';
import 'features/principal/tela_principal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const RokuzenConnectApp());
}

/// Rokuzen Connect — app mobile do terapeuta.
class RokuzenConnectApp extends StatefulWidget {
  const RokuzenConnectApp({super.key});

  @override
  State<RokuzenConnectApp> createState() => _RokuzenConnectAppState();
}

enum _Area { login, terapeuta, admin }

class _RokuzenConnectAppState extends State<RokuzenConnectApp> {
  _Area _area = _Area.login;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rokuzen Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.tema,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        child: switch (_area) {
          _Area.terapeuta => TelaPrincipal(
              key: const ValueKey('app'),
              aoSair: () {
                repositorio.sair();
                PerfilService.limpar();
                setState(() => _area = _Area.login);
              },
            ),
          _Area.admin => TelaAdmin(
              key: const ValueKey('admin'),
              aoSair: () {
                SessaoAdmin.sair();
                setState(() => _area = _Area.login);
              },
            ),
          _Area.login => TelaLogin(
              key: const ValueKey('login'),
              aoEntrar: () => setState(() => _area = _Area.terapeuta),
              aoEntrarAdmin: () => setState(() => _area = _Area.admin),
            ),
        },
      ),
    );
  }
}
