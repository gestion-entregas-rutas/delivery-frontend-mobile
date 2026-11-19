import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Camino por calles entre varios puntos, con su distancia y tiempo.
class RoadRoute {
  const RoadRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// Puntos del trazado siguiendo las calles.
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
}

/// Dibuja el camino por calles entre puntos dados.
///
/// IMPORTANTE: solo dibuja y estima. El ORDEN de las paradas lo decide el
/// backend (AGENTS.md, regla 2); esto nunca reordena ni elige paradas.
abstract class RoadRouter {
  /// `null` si no se pudo trazar (sin red, servicio caído, sin camino). Quien
  /// llama debe tener un plan B, por ejemplo líneas rectas.
  Future<RoadRoute?> route(List<LatLng> waypoints);
}

/// Usa el servidor público de OSRM (https://router.project-osrm.org).
///
/// Ojo: es un servidor de demostración, sin garantías ni uso intensivo, y
/// recibe las coordenadas de las paradas y del repartidor. Para producción,
/// apunta [baseUrl] a un OSRM propio.
class OsrmRoadRouter implements RoadRouter {
  OsrmRoadRouter({
    http.Client? client,
    this.baseUrl = 'https://router.project-osrm.org',
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  final Map<String, RoadRoute?> _cache = <String, RoadRoute?>{};

  /// Sin paradas repetidas ni redondeos que cambien el camino: 5 decimales
  /// (~1 m) bastan para la clave de caché.
  static String _key(List<LatLng> points) => points
      .map(
        (p) =>
            '${p.longitude.toStringAsFixed(5)},${p.latitude.toStringAsFixed(5)}',
      )
      .join(';');

  @override
  Future<RoadRoute?> route(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;
    final key = _key(waypoints);
    if (_cache.containsKey(key)) return _cache[key];
    final result = await _fetch(key);
    // Solo se recuerdan los aciertos: un fallo por red debe poder reintentarse.
    if (result != null) _cache[key] = result;
    return result;
  }

  Future<RoadRoute?> _fetch(String coordinates) async {
    final uri = Uri.parse('$baseUrl/route/v1/driving/$coordinates').replace(
      queryParameters: const {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );
    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      return parseOsrmRoute(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      return null;
    } on http.ClientException {
      return null;
    } on FormatException {
      return null;
    } on Exception {
      return null;
    }
  }

  void close() => _client.close();
}

/// Lee la respuesta de OSRM. `null` si no trae un camino utilizable.
RoadRoute? parseOsrmRoute(String body) {
  final dynamic json = jsonDecode(body);
  if (json is! Map<String, dynamic> || json['code'] != 'Ok') return null;
  final routes = json['routes'];
  if (routes is! List || routes.isEmpty) return null;
  final route = routes.first;
  if (route is! Map<String, dynamic>) return null;
  final geometry = route['geometry'];
  final coordinates = geometry is Map<String, dynamic>
      ? geometry['coordinates']
      : null;
  if (coordinates is! List || coordinates.length < 2) return null;
  final points = <LatLng>[];
  for (final c in coordinates) {
    // GeoJSON viene como [longitud, latitud].
    if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
      points.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
    }
  }
  if (points.length < 2) return null;
  return RoadRoute(
    points: points,
    distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
    durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
  );
}

/// Parte un trazado en dos por el punto más cercano a [splitAt]: lo recorrido
/// hasta ahí y lo que falta (ambos incluyen ese punto, para que se unan).
({List<LatLng> before, List<LatLng> after}) splitPathAt(
  List<LatLng> path,
  LatLng splitAt,
) {
  if (path.length < 2) return (before: const [], after: path);
  var bestIndex = 0;
  var best = double.infinity;
  for (var i = 0; i < path.length; i++) {
    final d = _squaredDistance(path[i], splitAt);
    if (d < best) {
      best = d;
      bestIndex = i;
    }
  }
  return (
    before: path.sublist(0, bestIndex + 1),
    after: path.sublist(bestIndex),
  );
}

// Distancia al cuadrado en grados: basta para comparar cercanía local.
double _squaredDistance(LatLng a, LatLng b) {
  final dLat = a.latitude - b.latitude;
  final dLng =
      (a.longitude - b.longitude) * math.cos(a.latitude * math.pi / 180);
  return dLat * dLat + dLng * dLng;
}
