import 'dart:async';

import 'package:flutter/material.dart';

import 'animated_route.dart';
import 'home_screen.dart' show AppColors, kAppName;
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 450,
          ),
          pageBuilder: (_, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (_, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.yellow,
    body: SafeArea(
      child: Column(
        children: [
          const Spacer(),
          const Icon(Icons.route_rounded, size: 48, color: AppColors.ink),
          const SizedBox(height: 16),
          const Text(
            kAppName,
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.8,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Haz tu ruta. Entrega a tiempo.',
            style: TextStyle(fontSize: 15, color: Color(0xFF4D461D)),
          ),
          const SizedBox(height: 28),
          const Flexible(
            flex: 3,
            child: SizedBox(height: 260, width: 480, child: AnimatedRoute()),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'HECHO PARA QUIENES MUEVEN EL DÍA',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
