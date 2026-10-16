import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart' show AppColors;
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // App del repartidor: solo vertical.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Barra de estado transparente con iconos oscuros (el fondo es claro/amarillo).
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS
  ));

  runApp(const LogisticsApp());
}

class LogisticsApp extends StatelessWidget {
  const LogisticsApp({super.key});

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
      home: const SplashScreen(),
    );
  }
}