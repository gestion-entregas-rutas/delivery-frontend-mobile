import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend_mobile/data/api/api_client.dart';
import 'package:frontend_mobile/data/api/api_exception.dart';

void main() {
  test(
    'Protected PUT uses current bearer and sends credential contract JSON',
    () async {
      late http.Request captured;
      final api = ApiClient(
        baseUrl: 'https://example.test',
        accessTokenProvider: () => 'token',
        client: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );
      await api.put(
        '/autenticacion/credenciales',
        body: {
          'claveActual': 'old-test',
          'nuevoNombreUsuario': 'driver',
          'nuevaClave': 'New-test-value',
        },
      );
      expect(captured.method, 'PUT');
      expect(captured.headers['Authorization'], 'Bearer token');
      expect(jsonDecode(captured.body)['nuevoNombreUsuario'], 'driver');
      api.close();
    },
  );
  test(
    'A late 401 reports the old token and cannot invalidate its replacement',
    () async {
      var token = 'old';
      final response = Completer<http.Response>();
      final started = Completer<void>();
      String? used;
      final api = ApiClient(
        baseUrl: 'https://example.test',
        accessTokenProvider: () => token,
        onUnauthorized: (requestToken) {
          used = requestToken;
          if (requestToken == token) token = '';
        },
        client: MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
      final result = expectLater(
        api.get('/autenticacion/me'),
        throwsA(isA<ApiException>()),
      );
      await started.future;
      token = 'replacement';
      response.complete(http.Response('', 401));
      await result;
      expect(used, 'old');
      expect(token, 'replacement');
      api.close();
    },
  );
  test(
    '403 and 429 do not clear a valid session or automatically retry',
    () async {
      for (final code in [403, 429]) {
        var invalidations = 0;
        var requests = 0;
        final api = ApiClient(
          baseUrl: 'https://example.test',
          accessTokenProvider: () => 'valid',
          onUnauthorized: (_) => invalidations++,
          client: MockClient((_) async {
            requests++;
            return http.Response('', code);
          }),
        );
        await expectLater(
          api.post('/rutas/r/iniciar'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', code),
          ),
        );
        expect(invalidations, 0);
        expect(requests, 1);
        api.close();
      }
    },
  );
}
