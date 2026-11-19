import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/data/routing/road_router.dart';
import 'package:frontend_mobile/location/gps_service.dart';
import 'package:frontend_mobile/models/logistica_models.dart';
import 'package:frontend_mobile/widgets/route/gps_status.dart';
import 'package:frontend_mobile/theme/app_colors.dart';
import 'package:frontend_mobile/theme/app_theme.dart';
import 'package:frontend_mobile/widgets/route/map_markers.dart';
import 'package:frontend_mobile/widgets/route/route_map.dart';
import 'package:latlong2/latlong.dart';

import 'route_screen_test.dart' as h;

ParadaDto stopAt(int orden, String estado, double lat, double lng) => ParadaDto(
  orden: orden,
  pedido: PedidoDto(
    id: 'p$orden',
    clienteNombre: 'Cliente $orden',
    clienteTelefono: '09912345$orden$orden',
    direccion: 'Calle $orden',
    ubicacion: PuntoDto(latitud: lat, longitud: lng),
    fechaEntrega: '2026-10-17',
    horaEntrega: '09:0$orden:00',
    estado: estado,
  ),
);

RutaDto rutaCon(List<ParadaDto> paradas, {String id = 'r'}) => RutaDto(
  id: id,
  fecha: '2026-10-17',
  zonaId: 'z',
  repartidorId: 'd',
  capacidad: 5,
  estado: 'EnCurso',
  paradas: paradas,
);

/// Un camino por calles de mentira que pasa por los puntos dados.
RoadRoute roadThrough(List<LatLng> points) =>
    RoadRoute(points: points, distanceMeters: 4200, durationSeconds: 720);

Future<void> pumpMap(
  WidgetTester tester,
  RutaDto? ruta, {
  GpsSample? me,
  RoadRouter? router,
  ValueChanged<ParadaDto>? onCall,
  ValueChanged<ParadaDto>? onWhatsapp,
  GpsState? gpsState,
  VoidCallback? onEnableLocation,
  VoidCallback? onOpenSettings,
}) async {
  tester.view.physicalSize = const Size(390, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: RouteMap(
          route: ruta,
          router: router,
          myLocation: me,
          gpsState: gpsState,
          onEnableLocation: onEnableLocation,
          onOpenSettings: onOpenSettings,
          onCall: onCall,
          onWhatsapp: onWhatsapp,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

List<Polyline> polylinesOf(WidgetTester tester) =>
    tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines;

void main() {
  setUpAll(() => RouteMap.tilesEnabled = false);

  group('mapStopsOf', () {
    test('mantiene el orden del servidor', () {
      final stops = mapStopsOf(
        rutaCon([
          stopAt(1, 'Entregado', -0.18, -78.48),
          stopAt(2, 'EnCamino', -0.19, -78.49),
        ]),
      );
      expect(stops.map((s) => s.stop.orden), [1, 2]);
    });

    test('descarta paradas sin posición válida', () {
      final stops = mapStopsOf(
        rutaCon([
          stopAt(1, 'Entregado', 0, 0),
          stopAt(2, 'EnCamino', double.nan, -78),
          stopAt(3, 'EnCamino', 95, 10),
          stopAt(4, 'EnCamino', -0.19, 200),
          stopAt(5, 'AsignadoARuta', -0.2, -78.5),
        ]),
      );
      expect(stops.map((s) => s.stop.orden), [5]);
    });

    test('sin ruta no hay paradas', () {
      expect(mapStopsOf(null), isEmpty);
    });

    test('marca como entregadas solo las entregadas', () {
      final stops = mapStopsOf(
        rutaCon([
          stopAt(1, 'Entregado', -0.18, -78.48),
          stopAt(2, 'EnCamino', -0.19, -78.49),
        ]),
      );
      expect(stops[0].delivered, isTrue);
      expect(stops[1].delivered, isFalse);
    });
  });

  group('RouteMap', () {
    final ruta = rutaCon([
      stopAt(1, 'Entregado', -0.180, -78.480),
      stopAt(2, 'EnCamino', -0.185, -78.485),
      stopAt(3, 'AsignadoARuta', -0.190, -78.490),
    ]);

    testWidgets('cada parada es una caja, no un número', (tester) async {
      await pumpMap(tester, ruta);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(StopBoxMarker), findsNWidgets(3));
      // Entregada: check. Actual y pendiente: caja.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_rounded), findsNWidgets(2));
      // Ya no se dibujan números sobre el mapa.
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la leyenda cuenta las entregadas', (tester) async {
      await pumpMap(tester, ruta);
      expect(find.text('1 de 3 entregadas'), findsOneWidget);
      expect(find.text('Entregada'), findsOneWidget);
      expect(find.text('Actual'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
    });

    testWidgets('cada marca se anuncia con su estado', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpMap(tester, ruta);
      expect(
        find.bySemanticsLabel('Parada 1, entregada, Cliente 1'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Parada 2, actual, Cliente 2'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Parada 3, pendiente, Cliente 3'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('al tocar una caja se ve su detalle y se puede cerrar', (
      tester,
    ) async {
      await pumpMap(tester, ruta);
      expect(find.text('Cliente 3'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('stop-marker-3')));
      await tester.pump();
      expect(find.text('Cliente 3'), findsOneWidget);
      expect(find.text('Calle 3'), findsOneWidget);
      expect(find.text('Llamar'), findsNothing); // sin callbacks no hay botones
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pump();
      expect(find.text('Cliente 3'), findsNothing);
    });

    testWidgets('el detalle ofrece Llamar y WhatsApp con la parada correcta', (
      tester,
    ) async {
      ParadaDto? called;
      ParadaDto? chatted;
      await pumpMap(
        tester,
        ruta,
        onCall: (s) => called = s,
        onWhatsapp: (s) => chatted = s,
      );
      await tester.tap(find.byKey(const ValueKey('stop-marker-3')));
      await tester.pump();
      await tester.tap(find.text('Llamar'));
      await tester.tap(find.text('WhatsApp'));
      expect(called?.orden, 3);
      expect(chatted?.orden, 3);
    });

    testWidgets('una entregada no ofrece contacto', (tester) async {
      await pumpMap(tester, ruta, onCall: (_) {}, onWhatsapp: (_) {});
      await tester.tap(find.byKey(const ValueKey('stop-marker-1')));
      await tester.pump();
      expect(find.text('Cliente 1'), findsOneWidget);
      expect(find.text('Llamar'), findsNothing);
      expect(find.text('WhatsApp'), findsNothing);
    });

    testWidgets('el repartidor se dibuja como una moto', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpMap(
        tester,
        ruta,
        me: GpsSample(
          latitude: -0.186,
          longitude: -78.486,
          accuracyMeters: 8,
          capturedAtUtc: DateTime.utc(2026, 10, 17),
        ),
      );
      expect(find.byType(DriverMarker), findsOneWidget);
      expect(find.byIcon(Icons.two_wheeler_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Tu ubicación'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('sin ubicación no hay moto', (tester) async {
      await pumpMap(tester, ruta);
      expect(find.byType(DriverMarker), findsNothing);
      // Sin forma de pedirla (no se dio onEnableLocation), el botón queda
      // apagado en lugar de prometer algo que no puede hacer.
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.my_location_rounded),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('no desborda con texto grande', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpMap(tester, ruta, onCall: (_) {}, onWhatsapp: (_) {});
      await tester.tap(find.byKey(const ValueKey('stop-marker-3')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('ubicación en el mapa global', () {
    final ruta = rutaCon([
      stopAt(1, 'EnCamino', -0.180, -78.480),
      stopAt(2, 'AsignadoARuta', -0.185, -78.485),
    ]);

    testWidgets('con el GPS apagado ofrece Activar y lo pide', (tester) async {
      var enabled = 0;
      await pumpMap(
        tester,
        ruta,
        gpsState: GpsState.stopped,
        onEnableLocation: () => enabled++,
      );
      expect(find.text('Ubicación apagada'), findsOneWidget);
      await tester.tap(find.text('Activar'));
      expect(enabled, 1);
    });

    testWidgets('el botón de ubicación del mapa también la pide', (
      tester,
    ) async {
      var enabled = 0;
      await pumpMap(
        tester,
        ruta,
        gpsState: GpsState.stopped,
        onEnableLocation: () => enabled++,
      );
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.my_location_rounded),
      );
      expect(button.tooltip, 'Activar mi ubicación');
      expect(button.onPressed, isNotNull);
      await tester.tap(find.byTooltip('Activar mi ubicación'));
      expect(enabled, 1);
    });

    testWidgets('con la ubicación apagada en el teléfono manda a Ajustes', (
      tester,
    ) async {
      var settings = 0;
      await pumpMap(
        tester,
        ruta,
        gpsState: GpsState.serviceDisabled,
        onEnableLocation: () {},
        onOpenSettings: () => settings++,
      );
      expect(find.text('Enciende la ubicación del teléfono'), findsOneWidget);
      await tester.tap(find.text('Ajustes'));
      expect(settings, 1);
    });

    testWidgets('con ubicación no se muestra el aviso del GPS', (tester) async {
      await pumpMap(
        tester,
        ruta,
        gpsState: GpsState.active,
        me: GpsSample(
          latitude: -0.182,
          longitude: -78.482,
          accuracyMeters: 5,
          capturedAtUtc: DateTime.utc(2026, 10, 17),
        ),
      );
      expect(find.byType(GpsStatus), findsNothing);
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.my_location_rounded),
      );
      expect(button.tooltip, 'Centrar en mi ubicación');
    });
  });

  group('trazado por calles', () {
    final stops = [
      stopAt(1, 'Entregado', -0.180, -78.480),
      stopAt(2, 'EnCamino', -0.185, -78.485),
      stopAt(3, 'AsignadoARuta', -0.190, -78.490),
    ];

    /// Camino que pasa por las tres paradas, con un punto intermedio entre
    /// cada una (como lo haría una calle con una esquina).
    final streetPath = [
      const LatLng(-0.180, -78.480),
      const LatLng(-0.180, -78.485), // esquina
      const LatLng(-0.185, -78.485),
      const LatLng(-0.185, -78.490), // esquina
      const LatLng(-0.190, -78.490),
    ];

    testWidgets('pide el camino con las paradas en el orden del servidor', (
      tester,
    ) async {
      final router = h.FakeRouter(roadThrough(streetPath));
      await pumpMap(tester, rutaCon(stops), router: router);
      expect(router.calls.length, 1);
      expect(router.calls.single, [
        const LatLng(-0.180, -78.480),
        const LatLng(-0.185, -78.485),
        const LatLng(-0.190, -78.490),
      ]);
    });

    // Dos entregadas y una actual: hay un tramo ya recorrido y otro por hacer.
    final twoDone = [
      stopAt(1, 'Entregado', -0.180, -78.480),
      stopAt(2, 'Entregado', -0.185, -78.485),
      stopAt(3, 'EnCamino', -0.190, -78.490),
    ];

    testWidgets('dibuja el camino por calles partido en hecho y por hacer', (
      tester,
    ) async {
      await pumpMap(
        tester,
        rutaCon(twoDone),
        router: h.FakeRouter(roadThrough(streetPath)),
      );
      final lines = polylinesOf(tester);
      expect(lines.length, 2);
      final remaining = lines.firstWhere(
        (l) => l.color == AppColors.brandBright,
      );
      final done = lines.firstWhere((l) => l.color == AppColors.done);
      // Por hacer: sigue la esquina de la calle, no una recta entre cajas.
      expect(remaining.points, [
        const LatLng(-0.185, -78.485),
        const LatLng(-0.185, -78.490),
        const LatLng(-0.190, -78.490),
      ]);
      // Recorrido: desde la primera parada hasta la última entregada.
      expect(done.points.first, const LatLng(-0.180, -78.480));
      expect(done.points.last, const LatLng(-0.185, -78.485));
      // Con calles el trazo es continuo, no punteado.
      expect(remaining.pattern.segments, isNull);
    });

    testWidgets('con una sola entregada solo hay tramo por hacer', (
      tester,
    ) async {
      await pumpMap(
        tester,
        rutaCon(stops),
        router: h.FakeRouter(roadThrough(streetPath)),
      );
      final lines = polylinesOf(tester);
      expect(lines.length, 1);
      expect(lines.single.color, AppColors.brandBright);
    });

    testWidgets('si falla, se avisa y se dibuja en línea recta', (
      tester,
    ) async {
      await pumpMap(tester, rutaCon(twoDone), router: h.FakeRouter());
      await tester.pump();
      expect(
        find.text('No se pudo trazar por calles: se muestra en línea recta.'),
        findsOneWidget,
      );
      // Líneas rectas: una por tramo (hecho y por hacer), la de por hacer
      // punteada.
      final lines = polylinesOf(tester);
      expect(lines.length, 2);
      final remaining = lines.firstWhere(
        (l) => l.color == AppColors.brandBright,
      );
      expect(remaining.pattern.segments, isNotNull);
    });

    testWidgets('sin trazador se dibujan líneas rectas y no hay aviso', (
      tester,
    ) async {
      await pumpMap(tester, rutaCon(twoDone));
      expect(polylinesOf(tester).length, 2);
      expect(find.textContaining('No se pudo trazar'), findsNothing);
    });

    testWidgets('mientras se traza, lo dice', (tester) async {
      final router = _SlowRouter();
      await pumpMap(tester, rutaCon(stops), router: router);
      expect(find.text('Trazando el camino por las calles…'), findsOneWidget);
      router.complete(roadThrough(streetPath));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Trazando'), findsNothing);
    });

    testWidgets('entregar una parada no vuelve a pedir el camino', (
      tester,
    ) async {
      final router = h.FakeRouter(roadThrough(streetPath));
      await pumpMap(tester, rutaCon(stops), router: router);
      expect(router.calls.length, 1);
      // Misma ruta y mismas coordenadas, una parada más entregada.
      final updated = [
        stopAt(1, 'Entregado', -0.180, -78.480),
        stopAt(2, 'Entregado', -0.185, -78.485),
        stopAt(3, 'EnCamino', -0.190, -78.490),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RouteMap(route: rutaCon(updated), router: router),
          ),
        ),
      );
      await tester.pump();
      expect(router.calls.length, 1);
      expect(find.text('2 de 3 entregadas'), findsOneWidget);
    });

    testWidgets('con una sola parada no se pide ningún camino', (tester) async {
      final router = h.FakeRouter(roadThrough(streetPath));
      await pumpMap(
        tester,
        rutaCon([stopAt(1, 'EnCamino', -0.18, -78.48)]),
        router: router,
      );
      expect(router.calls, isEmpty);
    });
  });

  group('pestaña Mapa en la app', () {
    final stops = [
      h.stop(1, 'Entregado'),
      h.stop(2, 'EnCamino', detalles: '2 × Vela'),
      h.stop(3, 'AsignadoARuta'),
    ];

    testWidgets('hay tres pestañas: Ruta, Mapa y Perfil', (tester) async {
      final c = await h.pumpHome(tester, h.route('EnCurso', stops));
      expect(find.text('Ruta'), findsOneWidget);
      expect(find.text('Mapa'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
      await h.teardown(tester, c);
    });

    testWidgets('el mapa muestra todas las paradas de la ruta', (tester) async {
      final c = await h.pumpHome(tester, h.route('EnCurso', stops));
      await tester.tap(find.text('Mapa'));
      await tester.pumpAndSettle();
      expect(find.text('1 de 3 entregadas'), findsOneWidget);
      await h.teardown(tester, c);
    });

    testWidgets('en la pestaña Mapa se puede activar la ubicación', (
      tester,
    ) async {
      final gps = h.FakeGps();
      final c = await h.pumpHome(tester, h.route('EnCurso', stops), gps: gps);
      await tester.tap(find.text('Mapa'));
      await tester.pumpAndSettle();
      expect(find.text('Ubicación apagada'), findsOneWidget);
      await tester.tap(find.text('Activar'));
      await tester.pumpAndSettle();
      expect(gps.starts, 1);
      // El GPS respondió "ubicación apagada en el teléfono": lo dice y manda a
      // Ajustes.
      expect(find.text('Enciende la ubicación del teléfono'), findsOneWidget);
      await tester.tap(find.text('Ajustes'));
      expect(gps.settingsOpened, 1);
      await h.teardown(tester, c);
    });

    testWidgets('sin ruta el mapa explica qué falta', (tester) async {
      final c = await h.pumpHome(tester, null);
      await tester.tap(find.text('Mapa'));
      await tester.pumpAndSettle();
      expect(find.text('Sin paradas para mostrar'), findsOneWidget);
      await h.teardown(tester, c);
    });
  });
}

/// Trazador que responde cuando el test lo decide.
class _SlowRouter implements RoadRouter {
  final Completer<RoadRoute?> _completer = Completer<RoadRoute?>();

  void complete(RoadRoute? route) => _completer.complete(route);

  @override
  Future<RoadRoute?> route(List<LatLng> waypoints) => _completer.future;
}
