import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend_mobile/auth/auth_controller.dart';
import 'package:frontend_mobile/auth/session_store.dart';
import 'package:frontend_mobile/data/api/api_client.dart';
import 'package:frontend_mobile/screens/session_gate.dart';
import 'package:frontend_mobile/screens/login_screen.dart';
import 'package:frontend_mobile/screens/change_credentials_screen.dart';

void main() {
  testWidgets(
    'Temporary session shows credential policy and never opens operational resources',
    (tester) async {
      final requests = <String>[];
      late AuthController auth;
      final api = ApiClient(
        baseUrl: 'https://example.test',
        accessTokenProvider: () => auth.accessToken,
        onUnauthorized: (token) => auth.handleUnauthorized(token),
        client: MockClient((request) async {
          requests.add(request.url.path);
          return http.Response(
            jsonEncode({
              'accessToken': 'fake-token',
              'tokenType': 'Bearer',
              'expiraEn': DateTime.now()
                  .add(const Duration(minutes: 10))
                  .toUtc()
                  .toIso8601String(),
              'usuario': {
                'id': 'u',
                'nombreUsuario': 'driver',
                'rol': 'Conductor',
                'repartidorId': 'd',
                'activo': true,
                'debeCambiarCredenciales': true,
              },
            }),
            200,
          );
        }),
      );
      auth = AuthController(api: api, store: MemorySessionStore());
      await auth.login(username: 'driver', password: 'test');
      await tester.pumpWidget(MaterialApp(home: SessionGate(auth: auth)));
      expect(find.byType(ChangeCredentialsScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'CurrentPassword1!',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'weak');
      await tester.ensureVisible(find.text('Guardar y continuar'));
      await tester.tap(find.text('Guardar y continuar'));
      await tester.pump();
      expect(find.text('Usa entre 12 y 128 caracteres'), findsOneWidget);
      expect(requests, ['/api/autenticacion/login']);
      auth.handleUnauthorized('fake-token');
      await tester.pump();
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ChangeCredentialsScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      api.close();
    },
  );
}
