import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_theme.dart';
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

class _RokuzenConnectAppState extends State<RokuzenConnectApp> {
  bool _logado = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rokuzen Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.tema,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        child: _logado
            ? TelaPrincipal(
                key: const ValueKey('app'),
                aoSair: () => setState(() => _logado = false),
              )
            : TelaLogin(
                key: const ValueKey('login'),
                aoEntrar: () => setState(() => _logado = true),
              ),
      ),
    );
  }
}
