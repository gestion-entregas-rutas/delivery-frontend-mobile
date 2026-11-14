// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:frontend_mobile/data/api/api_client.dart';
import 'package:frontend_mobile/data/api/logistica_repository.dart';

// Read-only smoke. Optional DELIVERY_TEST_TOKEN must be supplied locally,
// never as a CLI argument, committed file, or chat message.
Future<void> main(List<String> args) async {
  final server = (args.isEmpty ? 'http://localhost:5289' : args.first)
      .replaceFirst(RegExp(r'/+$'), '')
      .replaceFirst(RegExp(r'/api$'), '');
  final client = http.Client();
  try {
    final token = Platform.environment['DELIVERY_TEST_TOKEN'];
    if (token == null || token.isEmpty) {
      for (final path in [
        '/api/autenticacion/me',
        '/api/repartidores',
        '/hubs/seguimiento/negotiate?negotiateVersion=1',
      ]) {
        final uri = Uri.parse('$server$path');
        final response =
            await (path.contains('negotiate')
                    ? client.post(uri)
                    : client.get(uri))
                .timeout(const Duration(seconds: 15));
        if (response.statusCode != 401) {
          throw StateError('Expected unauthenticated HTTP 401');
        }
      }
      print('REST and SignalR reject anonymous access: OK (401).');
      print(
        'Authenticated checks require a locally supplied DELIVERY_TEST_TOKEN. No login attempts or business changes made.',
      );
      return;
    }
    final api = ApiClient(
      baseUrl: server,
      client: client,
      accessTokenProvider: () => token,
    );
    final identity = await api.get('/autenticacion/me');
    if (identity is! Map ||
        identity['rol'] != 'Conductor' ||
        identity['activo'] != true ||
        identity['debeCambiarCredenciales'] != false ||
        identity['repartidorId'] is! String) {
      throw StateError('An operational conductor session is required');
    }
    final repo = LogisticaRepository(api);
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final route = await repo.rutaActiva(
      identity['repartidorId'] as String,
      date,
    );
    if (route != null) {
      final byId = await repo.ruta(route.id);
      if (byId.id != route.id) throw StateError('Route mismatch');
    }
    final response = await client
        .post(
          Uri.parse('$server/hubs/seguimiento/negotiate?negotiateVersion=1'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 ||
        (jsonDecode(response.body) as Map)['connectionToken'] == null) {
      throw StateError('SignalR negotiation failed');
    }
    print(
      'Authenticated identity, own route and SignalR negotiation: OK. No business data changed.',
    );
  } catch (_) {
    stderr.writeln(
      'API verification failed. Check server, token validity and conductor permissions locally.',
    );
    exitCode = 1;
  } finally {
    client.close();
  }
}
