import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/data/routing/road_router.dart';
import 'package:frontend_mobile/utils/format.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

String osrmBody({
  String code = 'Ok',
  List<List<double>>? coords,
  double distance = 1234,
  double duration = 300,
}) => jsonEncode({
  'code': code,
  'routes': [
    {
      'distance': distance,
      'duration': duration,
      'geometry': {
        'type': 'LineString',
        'coordinates':
            coords ??
            [
              [-78.48, -0.18],
              [-78.481, -0.181],
              [-78.482, -0.183],
            ],
      },
    },
  ],
});

void main() {
  group('parseOsrmRoute', () {
    test('lee puntos (lng, lat), distancia y tiempo', () {
      final route = parseOsrmRoute(osrmBody())!;
      expect(route.points.length, 3);
      // GeoJSON es [lng, lat]: la latitud es el segundo valor.
      expect(route.points.first.latitude, -0.18);
      expect(route.points.first.longitude, -78.48);
      expect(route.distanceMeters, 1234);
      expect(route.durationSeconds, 300);
    });

    test('devuelve null si no hay camino', () {
      expect(parseOsrmRoute(osrmBody(code: 'NoRoute')), isNull);
      expect(parseOsrmRoute('{"code":"Ok","routes":[]}'), isNull);
      expect(
        parseOsrmRoute(
          osrmBody(
            coords: [
              [-78.0, -0.1],
            ],
          ),
        ),
        isNull,
      );
    });

    test('ignora puntos mal formados', () {
      final route = parseOsrmRoute(
        jsonEncode({
          'code': 'Ok',
          'routes': [
            {
              'distance': 10,
              'duration': 1,
              'geometry': {
                'coordinates': [
                  [-78.0, -0.1],
                  ['x', 'y'],
                  [-78.1, -0.2],
                ],
              },
            },
          ],
        }),
      );
      expect(route!.points.length, 2);
    });
  });

  group('OsrmRoadRouter', () {
    const a = LatLng(-0.18, -78.48);
    const b = LatLng(-0.19, -78.49);
    const c = LatLng(-0.20, -78.50);

    test('pide los puntos como lng,lat separados por ;', () async {
      Uri? requested;
      final router = OsrmRoadRouter(
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(osrmBody(), 200);
        }),
      );
      final route = await router.route([a, b, c]);
      expect(route, isNotNull);
      expect(requested!.host, 'router.project-osrm.org');
      expect(
        requested!.path,
        '/route/v1/driving/-78.48000,-0.18000;-78.49000,-0.19000;-78.50000,-0.20000',
      );
      expect(requested!.queryParameters['geometries'], 'geojson');
      expect(requested!.queryParameters['overview'], 'full');
    });

    test('recuerda los aciertos y no repite la petición', () async {
      var calls = 0;
      final router = OsrmRoadRouter(
        client: MockClient((_) async {
          calls++;
          return http.Response(osrmBody(), 200);
        }),
      );
      await router.route([a, b]);
      await router.route([a, b]);
      expect(calls, 1);
    });

    test('un fallo no se recuerda: se puede reintentar', () async {
      var calls = 0;
      final router = OsrmRoadRouter(
        client: MockClient((_) async {
          calls++;
          return calls == 1
              ? http.Response('error', 500)
              : http.Response(osrmBody(), 200);
        }),
      );
      expect(await router.route([a, b]), isNull);
      expect(await router.route([a, b]), isNotNull);
      expect(calls, 2);
    });

    test('red caída, cuerpo roto o tiempo agotado devuelven null', () async {
      expect(
        await OsrmRoadRouter(
          client: MockClient(
            (_) async => throw http.ClientException('sin red'),
          ),
        ).route([a, b]),
        isNull,
      );
      expect(
        await OsrmRoadRouter(
          client: MockClient((_) async => http.Response('no es json', 200)),
        ).route([a, b]),
        isNull,
      );
      expect(
        await OsrmRoadRouter(
          timeout: const Duration(milliseconds: 20),
          client: MockClient((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return http.Response(osrmBody(), 200);
          }),
        ).route([a, b]),
        isNull,
      );
    });

    test('con menos de dos puntos no pide nada', () async {
      var calls = 0;
      final router = OsrmRoadRouter(
        client: MockClient((_) async {
          calls++;
          return http.Response(osrmBody(), 200);
        }),
      );
      expect(await router.route([a]), isNull);
      expect(await router.route([]), isNull);
      expect(calls, 0);
    });
  });

  group('splitPathAt', () {
    final path = [
      const LatLng(0, 0),
      const LatLng(0, 1),
      const LatLng(0, 2),
      const LatLng(0, 3),
    ];

    test('parte en el punto más cercano y ambos tramos se unen', () {
      final parts = splitPathAt(path, const LatLng(0.0001, 1.9));
      expect(parts.before.last, const LatLng(0, 2));
      expect(parts.after.first, const LatLng(0, 2));
      expect(parts.before.length, 3);
      expect(parts.after.length, 2);
    });

    test('al inicio no hay tramo recorrido y al final no falta nada', () {
      final start = splitPathAt(path, const LatLng(0, 0));
      expect(start.before.length, 1);
      expect(start.after.length, 4);
      final end = splitPathAt(path, const LatLng(0, 3));
      expect(end.after.length, 1);
    });

    test('un trazado muy corto no se parte', () {
      final parts = splitPathAt([const LatLng(0, 0)], const LatLng(1, 1));
      expect(parts.before, isEmpty);
    });
  });

  group('formato', () {
    test('distancia', () {
      expect(formatDistance(850), '850 m');
      expect(formatDistance(7), '7 m');
      expect(formatDistance(1000), '1 km');
      expect(formatDistance(1234), '1,2 km');
      expect(formatDistance(12500), '12,5 km');
      expect(formatDistance(double.nan), '—');
    });

    test('duración', () {
      expect(formatDuration(10), '1 min');
      expect(formatDuration(600), '10 min');
      expect(formatDuration(3600), '1 h');
      expect(formatDuration(4500), '1 h 15 min');
      expect(formatDuration(-1), '—');
    });
  });
}
