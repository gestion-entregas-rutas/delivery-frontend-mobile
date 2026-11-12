import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/screens/login_screen.dart';
import 'package:frontend_mobile/screens/splash_screen.dart';

void main() {
  testWidgets('Splash opens the driver login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    expect(find.text('RutaExpress'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
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
