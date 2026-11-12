import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/auth/auth_controller.dart';
import 'package:frontend_mobile/auth/auth_models.dart';
import 'package:frontend_mobile/auth/session_store.dart';
import 'package:frontend_mobile/data/api/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _user({bool change = false}) => <String, dynamic>{
  'id': 'user-1',
  'nombreUsuario': 'driver',
  'rol': 'Conductor',
  'repartidorId': 'driver-1',
  'activo': true,
  'debeCambiarCredenciales': change,
};

Map<String, dynamic> _session(String token, {bool change = false}) =>
    <String, dynamic>{
      'accessToken': token,
      'expiraEn': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 30))
          .toIso8601String(),
      'tokenType': 'Bearer',
      'usuario': _user(change: change),
    };

void main() {
  test(
    'login persists only the session and credential rotation replaces it',
    () async {
      var rotated = false;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/autenticacion/login')) {
          return http.Response(
            jsonEncode(_session('temporary', change: true)),
            200,
          );
        }
        if (request.url.path.endsWith('/autenticacion/credenciales')) {
          rotated = true;
          return http.Response(jsonEncode(_session('operational')), 200);
        }
        if (request.url.path.endsWith('/autenticacion/logout')) {
          return http.Response('', 204);
        }
        if (request.url.path.endsWith('/autenticacion/me')) {
          return http.Response(jsonEncode(_user(change: true)), 200);
        }
        return http.Response('', 404);
      });
      late AuthController auth;
      final api = ApiClient(
        baseUrl: 'http://test/api',
        client: client,
        accessTokenProvider: () => auth.accessToken,
        onUnauthorized: (token) => auth.handleUnauthorized(token),
      );
      final store = MemorySessionStore();
      auth = AuthController(api: api, store: store);

      await auth.login(username: 'driver', password: 'Temporary!1');
      expect(auth.status, AuthStatus.needsCredentialChange);
      expect(store.value?.accessToken, 'temporary');
      await auth.changeCredentials(
        currentPassword: 'Temporary!1',
        username: 'driver',
        newPassword: 'NewPassword!2',
      );
      expect(rotated, isTrue);
      expect(auth.status, AuthStatus.signedIn);
      expect(store.value?.accessToken, 'operational');
      await auth.logout();
      expect(auth.status, AuthStatus.signedOut);
      expect(store.value, isNull);
    },
  );

  test(
    'restore preserves encrypted token on network failure but never opens Home',
    () async {
      final saved = AuthSession.fromJson(_session('saved'));
      final store = MemorySessionStore()..value = saved;
      late AuthController auth;
      final api = ApiClient(
        baseUrl: 'http://test/api',
        client: MockClient((_) async => throw http.ClientException('offline')),
        accessTokenProvider: () => auth.accessToken,
      );
      auth = AuthController(api: api, store: store);
      await auth.restore();
      expect(auth.status, AuthStatus.temporarilyUnavailable);
      expect(auth.isSignedIn, isFalse);
      expect(store.value?.accessToken, 'saved');
    },
  );

  test(
    'late 401 for an old token cannot sign out a replacement session',
    () async {
      final store = MemorySessionStore();
      late AuthController auth;
      final api = ApiClient(
        baseUrl: 'http://test/api',
        client: MockClient(
          (_) async => http.Response(jsonEncode(_session('new')), 200),
        ),
        accessTokenProvider: () => auth.accessToken,
      );
      auth = AuthController(api: api, store: store);
      auth.session = AuthSession.fromJson(_session('new'));
      auth.user = auth.session!.user;
      auth.status = AuthStatus.signedIn;
      auth.handleUnauthorized('old');
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.accessToken, 'new');
    },
  );
}
