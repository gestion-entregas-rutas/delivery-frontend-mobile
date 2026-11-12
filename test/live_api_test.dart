import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/data/api/api_client.dart';
import 'package:frontend_mobile/realtime/seguimiento_service.dart';

void main() {
  test(
    'Live JWT SignalR subscription uses the authenticated conductor',
    () async {
      final token = Platform.environment['DELIVERY_TEST_TOKEN'];
      expect(
        token?.isNotEmpty,
        isTrue,
        reason: 'Provide a conductor token in the local environment, never a command argument.',
      );
      const server = String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:5289',
      );
      final api = ApiClient(baseUrl: server, accessTokenProvider: () => token);
      final hub = SeguimientoService(
        hubUrl: server,
        accessTokenProvider: () => token,
      );
      try {
        final identity = await api.get('/autenticacion/me') as Map;
        expect(identity['rol'], 'Conductor');
        expect(identity['debeCambiarCredenciales'], isFalse);
        await hub.start(driverId: identity['repartidorId'] as String);
        expect(hub.isConnected, isTrue);
      } finally {
        await hub.stop();
        api.close();
      }
      expect(hub.isConnected, isFalse);
    },
    skip: !const bool.fromEnvironment('LIVE_API'),
  );
}
