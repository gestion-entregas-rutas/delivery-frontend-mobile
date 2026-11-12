import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth/auth_controller.dart';
import 'config/api_config.dart';
import 'data/api/api_client.dart';

import 'screens/home_screen.dart' show AppColors;
import 'screens/session_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // App del repartidor: solo vertical.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Barra de estado transparente con iconos oscuros (el fondo es claro/amarillo).
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Android
      statusBarBrightness: Brightness.light, // iOS
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
      title: 'Logistics App',
      debugShowCheckedModeBanner: false, // Oculta el banner de "DEBUG"
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.yellow,
          primary: AppColors.yellow,
          onPrimary: AppColors.ink,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: SessionGate(auth: auth),
    );
  }
}
