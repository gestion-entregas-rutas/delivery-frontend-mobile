import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth/auth_controller.dart';
import 'config/api_config.dart';
import 'data/api/api_client.dart';

import 'theme/app_theme.dart';
import 'screens/session_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // App del repartidor: solo vertical.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Barra de estado transparente con iconos claros (arriba hay morado de marca).
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Android
      statusBarBrightness: Brightness.dark, // iOS
    ),
  );

  runApp(const LogisticsApp());
}

class LogisticsApp extends StatefulWidget {
  const LogisticsApp({super.key});

  @override
  State<LogisticsApp> createState() => _LogisticsAppState();
}

class _LogisticsAppState extends State<LogisticsApp> {
  late final AuthController auth;
  late final ApiClient api;

  @override
  void initState() {
    super.initState();
    late AuthController controller;
    api = ApiClient(
      baseUrl: ApiConfig.baseUrl,
      accessTokenProvider: () => controller.accessToken,
      onUnauthorized: (token) => controller.handleUnauthorized(token),
    );
    controller = AuthController(api: api);
    auth = controller;
    unawaited(auth.restore());
  }

  @override
  void dispose() {
    auth.dispose();
    api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RutaExpress',
      debugShowCheckedModeBanner: false, // Oculta el banner de "DEBUG"
      theme: AppTheme.light(),
      home: SessionGate(auth: auth),
    );
  }
}
