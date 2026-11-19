import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/auth/auth_controller.dart';
import 'package:frontend_mobile/auth/session_store.dart';
import 'package:frontend_mobile/data/api/api_client.dart';
import 'package:frontend_mobile/screens/change_credentials_screen.dart';
import 'package:frontend_mobile/screens/login_screen.dart';
import 'package:frontend_mobile/theme/app_theme.dart';
import 'package:frontend_mobile/widgets/primary_button.dart';

Future<void> setView(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

void main() {
  group('LoginScreen', () {
    testWidgets('muestra un solo botón principal y los dos campos', (
      tester,
    ) async {
      await setView(tester, const Size(360, 780));
      await tester.pumpWidget(app(const LoginScreen()));
      expect(find.text('Hola de nuevo'), findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Iniciar sesión'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('valida los campos vacíos antes de enviar', (tester) async {
      await setView(tester, const Size(360, 780));
      await tester.pumpWidget(app(const LoginScreen()));
      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();
      expect(find.text('Ingresa tu usuario o correo'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('mostrar contraseña cambia el icono', (tester) async {
      await setView(tester, const Size(360, 780));
      await tester.pumpWidget(app(const LoginScreen()));
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Mostrar contraseña'));
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    for (final size in const [
      Size(320, 568),
      Size(390, 844),
      Size(768, 1024),
      Size(1200, 800),
    ]) {
      testWidgets(
        'no desborda en ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await setView(tester, size);
          await tester.pumpWidget(app(const LoginScreen()));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.text('Iniciar sesión'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  });

  group('ChangeCredentialsScreen', () {
    late AuthController auth;
    late ApiClient api;

    setUp(() {
      late AuthController controller;
      api = ApiClient(
        baseUrl: 'https://example.test',
        accessTokenProvider: () => controller.accessToken,
        onUnauthorized: (token) => controller.handleUnauthorized(token),
      );
      controller = AuthController(api: api, store: MemorySessionStore());
      auth = controller;
    });

    tearDown(() {
      auth.dispose();
      api.close();
    });

    testWidgets('pide clave actual, usuario y clave nueva con su requisito', (
      tester,
    ) async {
      await setView(tester, const Size(360, 780));
      await tester.pumpWidget(app(ChangeCredentialsScreen(auth: auth)));
      expect(find.text('Crea tu clave nueva'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(
        find.textContaining('12 o más caracteres'),
        findsOneWidget,
        reason: 'El requisito de la clave se ve antes de equivocarse',
      );
      expect(find.text('Guardar y continuar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('rechaza una clave débil con el motivo', (tester) async {
      await setView(tester, const Size(360, 780));
      await tester.pumpWidget(app(ChangeCredentialsScreen(auth: auth)));
      await tester.enterText(find.byType(TextFormField).at(0), 'Actual1234!x');
      await tester.enterText(find.byType(TextFormField).at(2), 'weak');
      await tester.ensureVisible(find.text('Guardar y continuar'));
      await tester.tap(find.text('Guardar y continuar'));
      await tester.pump();
      expect(find.text('Usa entre 12 y 128 caracteres'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    for (final size in const [Size(320, 568), Size(1200, 800)]) {
      testWidgets(
        'no desborda en ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await setView(tester, size);
          await tester.pumpWidget(app(ChangeCredentialsScreen(auth: auth)));
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  });
}
