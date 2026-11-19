import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/screens/login_screen.dart';
import 'package:frontend_mobile/screens/rive_delivery.dart';
import 'package:frontend_mobile/screens/splash_screen.dart';

void main() {
  setUpAll(() => RiveDelivery.enabled = false);
  splashRegressionTests();

  testWidgets('Splash opens the driver login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    expect(find.text('RutaExpress'), findsOneWidget);
    // El tiempo de splash cuenta desde que la animación está lista, con un
    // tope si nunca avisa. Sin Rive (tests) el respaldo dura 2,5 s.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Small screen keeps login validation accessible', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('Ingresa tu usuario o correo'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('URL de la API'), findsNothing);
    expect(find.text('ID del repartidor (GUID)'), findsNothing);
    tester.view.viewInsets = FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byType(TextFormField).first);
    await tester.enterText(find.byType(TextFormField).first, 'demo');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

// Regresión: "setState() called during build" en SessionGate. El splash
// avisaba onDone dentro de didUpdateWidget, es decir, en plena construcción.
void splashRegressionTests() {
  testWidgets(
    'el splash termina sin setState durante el build cuando la carga acaba tarde',
    (tester) async {
      var done = false;
      var progress = 0.0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return done
                  ? const SizedBox()
                  : SplashScreen(
                      loadProgress: progress,
                      onDone: () => setState(() => done = true),
                    );
            },
          ),
        ),
      );
      // Pasa el tiempo mínimo del splash, pero la carga sigue en 0.
      await tester.pump(const Duration(seconds: 3));
      expect(done, isFalse);
      // La carga termina: el padre reconstruye y el splash recibe el 1.
      rebuild(() => progress = 1);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(done, isTrue);
    },
  );
}
