import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/data/api/api_client.dart';
import 'package:frontend_mobile/data/api/api_exception.dart';
import 'package:frontend_mobile/data/api/logistica_repository.dart';
import 'package:frontend_mobile/models/logistica_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _routeJson({String state = 'Planificada'}) =>
    <String, dynamic>{
      'id': 'route-1',
      'fecha': '2026-10-17',
      'zonaId': 'zone-1',
      'repartidorId': 'driver-1',
      'capacidad': 2,
      'estado': state,
      'paradas': [
        {
          'orden': 2,
          'pedido': {
            'id': 'order-2',
            'clienteNombre': 'Dos',
            'clienteTelefono': '222',
            'direccion': 'B',
            'ubicacion': {'latitud': -1, 'longitud': -2},
            'fechaEntrega': '2026-10-17',
            'horaEntrega': '10:00:00',
            'estado': 'AsignadoARuta',
          },
        },
        {
          'orden': 1,
          'pedido': {
            'id': 'order-1',
            'clienteNombre': 'Uno',
            'clienteTelefono': '111',
            'direccion': 'A',
            'ubicacion': {'latitud': -3, 'longitud': -4},
            'fechaEntrega': '2026-10-17',
            'horaEntrega': '09:00:00',
            'estado': 'Entregado',
          },
        },
      ],
    };

void main() {
  test('DTOs sort stops by the server order and preserve the local date', () {
    final route = RutaDto.fromJson(_routeJson());
    expect(route.paradas.map((stop) => stop.orden), [1, 2]);
    expect(route.fecha, '2026-10-17');
    expect(route.completedCount, 1);
  });

  test('POST transition has no automatic body and decodes response', () async {
    late http.BaseRequest sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(
        jsonEncode(_routeJson(state: 'EnCurso')),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final repository = LogisticaRepository(
      ApiClient(baseUrl: 'http://localhost:5289/api', client: client),
    );
    final route = await repository.iniciarRuta('route-1');
    expect(route.estado, 'EnCurso');
    expect(sent.method, 'POST');
    expect((sent as http.Request).body, isEmpty);
  });

  test('ProblemDetails 409 is typed for conflict handling', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode(<String, dynamic>{'status': 409, 'detail': 'Ya cambió'}),
        409,
      ),
    );
    final api = ApiClient(baseUrl: 'http://localhost:5289/api', client: client);
    await expectLater(
      api.post('/rutas/route-1/iniciar'),
      throwsA(
        isA<ApiException>().having((e) => e.isConflict, 'conflict', true),
      ),
    );
  });
  test(
    'A malformed successful mutation is uncertain instead of an empty DTO',
    () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      final repository = LogisticaRepository(
        ApiClient(baseUrl: 'http://localhost:5289', client: client),
      );
      await expectLater(
        repository.confirmarEntrega('p'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.isUncertain,
            'requires refresh',
            true,
          ),
        ),
      );
    },
  );
  test('A server failure after a POST requires reconciliation', () async {
    final client = MockClient((_) async => http.Response('', 500));
    final api = ApiClient(baseUrl: 'http://localhost:5289', client: client);
    await expectLater(
      api.post('/rutas/r/iniciar'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.isUncertain,
          'requires refresh',
          true,
        ),
      ),
    );
  });
}
