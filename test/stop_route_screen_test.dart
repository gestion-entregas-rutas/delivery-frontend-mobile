import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/data/routing/road_router.dart';
import 'package:frontend_mobile/location/gps_service.dart';
import 'package:frontend_mobile/models/logistica_models.dart';
import 'package:frontend_mobile/screens/stop_route_screen.dart';
import 'package:frontend_mobile/state/driver_controller.dart';
import 'package:frontend_mobile/theme/app_theme.dart';
import 'package:frontend_mobile/widgets/primary_button.dart';
import 'package:frontend_mobile/widgets/route/map_markers.dart';
import 'package:frontend_mobile/widgets/route/route_map.dart';
import 'package:latlong2/latlong.dart';

import 'route_screen_test.dart' as h;

/// Controlador de prueba que permite "mover" al repartidor y ver qué hizo el
/// GPS y el repositorio.
class TestDriverController extends DriverController {
  TestDriverController({h.FakeRepo? repo})
    : this._(h.FakeGps(), repo ?? h.FakeRepo(null));

  TestDriverController._(this.fakeGps, this.fakeRepo)
    : super(
        repository: fakeRepo,
        driverId: 'd',
        seguimiento: h.FakeRealtime(),
        gps: fakeGps,
        initialDate: DateTime(2026, 10, 17),
        clock: () => DateTime(2026, 10, 17, 9),
      );

  final h.FakeGps fakeGps;
  final h.FakeRepo fakeRepo;

  void moveTo(double lat, double lng) {
    latestGpsSample = GpsSample(
      latitude: lat,
      longitude: lng,
      accuracyMeters: 6,
      capturedAtUtc: DateTime.now().toUtc(),
    );
    notifyListeners();
  }
}

GpsSample sampleAt(double lat, double lng, {int seconds = 0}) => GpsSample(
  latitude: lat,
  longitude: lng,
  accuracyMeters: 6,
  capturedAtUtc: DateTime.utc(2026, 10, 17, 9, 0, seconds),
);

// Destino de las pruebas.
const double destLat = -0.1900;
const double destLng = -78.4900;

ParadaDto destino({String estado = 'EnCamino'}) => ParadaDto(
  orden: 3,
  pedido: PedidoDto(
    id: 'p3',
    clienteNombre: 'Ana Pérez',
    clienteTelefono: '0991234567',
    direccion: 'Av. Siempre Viva 742',
    ubicacion: const PuntoDto(latitud: destLat, longitud: destLng),
    fechaEntrega: '2026-10-17',
    horaEntrega: '09:30:00',
    estado: estado,
  ),
);

RoadRoute calle({double meters = 4200, double seconds = 720}) => RoadRoute(
  points: const [
    LatLng(-0.1800, -78.4800),
    LatLng(-0.1800, -78.4900),
    LatLng(destLat, destLng),
  ],
  distanceMeters: meters,
  durationSeconds: seconds,
);

Future<void> pumpScreen(
  WidgetTester tester,
  TestDriverController controller,
  h.FakeRouter router, {
  VoidCallback? onCall,
  VoidCallback? onWhatsapp,
  Size size = const Size(390, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: StopRouteScreen(
        stop: destino(),
        controller: controller,
        router: router,
        onCall: onCall,
        onWhatsapp: onWhatsapp,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() => RouteMap.tilesEnabled = false);

  late TestDriverController controller;
  setUp(() => controller = TestDriverController());
  tearDown(() => controller.dispose());

  PrimaryButton primary(WidgetTester tester) =>
      tester.widget<PrimaryButton>(find.byType(PrimaryButton));

  group('sin ubicación', () {
    testWidgets('explica qué falta y no deja iniciar', (tester) async {
      final router = h.FakeRouter(calle());
      await pumpScreen(tester, controller, router);
      expect(
        find.text('Necesitamos tu ubicación para trazar el camino hasta aquí.'),
        findsOneWidget,
      );
      // Dice qué pasa y cómo arreglarlo, sin mandar a configurar en otra parte.
      expect(find.text('Enciende la ubicación del teléfono'), findsOneWidget);
      expect(find.text('Ajustes'), findsOneWidget);
      expect(primary(tester).onPressed, isNull);
      expect(primary(tester).label, 'Iniciar');
      // Sin origen no se pide ningún camino.
      expect(router.calls, isEmpty);
      // El destino sí se ve, y el cliente se puede contactar.
      expect(find.byKey(const ValueKey('destination-marker')), findsOneWidget);
      expect(find.byType(DriverMarker), findsNothing);
      expect(find.text('Llamar'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Ruta a Ana Pérez'), findsOneWidget);
    });

    testWidgets('cuando llega la ubicación pide el camino', (tester) async {
      final router = h.FakeRouter(calle());
      await pumpScreen(tester, controller, router);
      controller.moveTo(-0.18, -78.48);
      await tester.pump();
      await tester.pump();
      expect(router.calls.length, 1);
      expect(find.byType(DriverMarker), findsOneWidget);
      expect(primary(tester).onPressed, isNotNull);
      expect(find.textContaining('Necesitamos tu ubicación'), findsNothing);
    });
  });

  group('ubicación sin ruta iniciada', () {
    testWidgets('al abrir enciende el GPS por su cuenta', (tester) async {
      await pumpScreen(tester, controller, h.FakeRouter(calle()));
      expect(controller.fakeGps.starts, 1);
    });

    testWidgets('si ya hay ubicación no lo vuelve a encender', (tester) async {
      controller.moveTo(-0.18, -78.48);
      await pumpScreen(tester, controller, h.FakeRouter(calle()));
      expect(controller.fakeGps.starts, 0);
    });

    testWidgets('mientras busca la señal lo dice', (tester) async {
      controller.fakeGps.startResult = GpsState.waitingForSample;
      await pumpScreen(tester, controller, h.FakeRouter(calle()));
      expect(find.text('Buscando tu ubicación…'), findsOneWidget);
      expect(primary(tester).onPressed, isNull);
    });

    testWidgets('cuando el GPS da una lectura aparece la moto y el camino', (
      tester,
    ) async {
      controller.fakeGps.startResult = GpsState.waitingForSample;
      final router = h.FakeRouter(calle());
      await pumpScreen(tester, controller, router);
      expect(find.byType(DriverMarker), findsNothing);
      controller.fakeGps.emit(sampleAt(-0.18, -78.48));
      await tester.pump();
      await tester.pump();
      expect(find.byType(DriverMarker), findsOneWidget);
      expect(router.calls.length, 1);
      expect(primary(tester).onPressed, isNotNull);
    });

    testWidgets('"Ajustes" abre los ajustes del teléfono', (tester) async {
      await pumpScreen(tester, controller, h.FakeRouter(calle()));
      await tester.ensureVisible(find.text('Ajustes'));
      await tester.tap(find.text('Ajustes'));
      expect(controller.fakeGps.settingsOpened, 1);
    });

    testWidgets('con el permiso denegado ofrece Permitir y reintenta', (
      tester,
    ) async {
      controller.fakeGps.startResult = GpsState.permissionDenied;
      await pumpScreen(tester, controller, h.FakeRouter(calle()));
      expect(
        find.text('Permite la ubicación para ver tu posición'),
        findsOneWidget,
      );
      expect(controller.fakeGps.starts, 1);
      await tester.ensureVisible(find.text('Permitir'));
      await tester.tap(find.text('Permitir'));
      await tester.pump();
      expect(controller.fakeGps.starts, 2);
    });

    testWidgets('al salir apaga el GPS si la ruta no está en curso', (
      tester,
    ) async {
      controller.fakeGps.startResult = GpsState.waitingForSample;
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StopRouteScreen(
                        stop: destino(),
                        controller: controller,
                        router: h.FakeRouter(calle()),
                      ),
                    ),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      // Sin pumpAndSettle: el indicador de "Buscando…" anima sin parar.
      await tester.tap(find.text('abrir'));
      await tester.pump(const Duration(milliseconds: 600));
      controller.fakeGps.emit(sampleAt(-0.18, -78.48));
      await tester.pump();
      expect(controller.latestGpsSample, isNotNull);
      final stopsBefore = controller.fakeGps.stops;
      await tester.tap(find.byTooltip('Volver'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.fakeGps.stops, greaterThan(stopsBefore));
      // La posición guardada ya no es la actual.
      expect(controller.latestGpsSample, isNull);
    });

    test(
      'la posición NO se envía al servidor si la ruta no está en curso',
      () async {
        final repo = h.FakeRepo(null);
        final c = TestDriverController(repo: repo);
        addTearDown(c.dispose);
        await c.enableLocationPreview();
        c.fakeGps.emit(sampleAt(-0.18, -78.48));
        await Future<void>.delayed(Duration.zero);
        expect(c.latestGpsSample, isNotNull); // se usa en el teléfono
        expect(repo.reports, 0); // pero no sale de él
      },
    );

    test('con la ruta en curso sí se sigue enviando', () async {
      final repo = h.FakeRepo(h.route('EnCurso', [h.stop(1, 'EnCamino')]));
      final c = TestDriverController(repo: repo);
      addTearDown(c.dispose);
      await c.initialize();
      await c.enableLocationPreview();
      c.fakeGps.emit(sampleAt(-0.18, -78.48));
      await Future<void>.delayed(Duration.zero);
      expect(repo.reports, 1);
    });

    test(
      'con la ruta en curso, soltar la vista previa no apaga el GPS',
      () async {
        final c = TestDriverController(
          repo: h.FakeRepo(h.route('EnCurso', [h.stop(1, 'EnCamino')])),
        );
        addTearDown(c.dispose);
        await c.initialize();
        await c.enableLocationPreview();
        final stopsBefore = c.fakeGps.stops;
        await c.releaseLocationPreview();
        expect(c.fakeGps.stops, stopsBefore);
      },
    );
  });

  group('con ubicación', () {
    setUp(() => controller.moveTo(-0.18, -78.48));

    testWidgets('pide el camino desde mi posición hasta el cliente', (
      tester,
    ) async {
      final router = h.FakeRouter(calle());
      await pumpScreen(tester, controller, router);
      expect(router.calls.length, 1);
      expect(router.calls.single, [
        const LatLng(-0.18, -78.48),
        const LatLng(destLat, destLng),
      ]);
    });

    testWidgets('muestra tiempo, distancia, dirección y cliente', (
      tester,
    ) async {
      await pumpScreen(tester, controller, h.FakeRouter(calle()));
      expect(find.text('12 min · 4,2 km'), findsOneWidget);
      expect(find.text('hasta Av. Siempre Viva 742'), findsOneWidget);
      expect(find.text('Ana Pérez · 09:30'), findsOneWidget);
      expect(find.text('Parada 3'), findsOneWidget);
    });

    testWidgets('dibuja el camino por calles y a la moto', (tester) async {
      await pumpScreen(tester, controller, h.FakeRouter(calle()));
      expect(find.byType(DriverMarker), findsOneWidget);
      expect(find.byIcon(Icons.two_wheeler_rounded), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_rounded), findsOneWidget);
    });

    testWidgets('Iniciar cambia a Detener y vuelve', (tester) async {
      await pumpScreen(tester, controller, h.FakeRouter(calle()));
      expect(primary(tester).label, 'Iniciar');
      await tester.tap(find.text('Iniciar'));
      await tester.pump();
      expect(primary(tester).label, 'Detener');
      await tester.tap(find.text('Detener'));
      await tester.pump();
      expect(primary(tester).label, 'Iniciar');
    });

    testWidgets('mientras avanzo no vuelve a pedir si me muevo poco', (
      tester,
    ) async {
      final router = h.FakeRouter(calle());
      await pumpScreen(tester, controller, router);
      await tester.tap(find.text('Iniciar'));
      await tester.pump();
      // ~11 m: por debajo del umbral de 50 m.
      controller.moveTo(-0.1801, -78.4800);
      await tester.pump();
      expect(router.calls.length, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('si el camino no se puede trazar, estima en línea recta', (
      tester,
    ) async {
      await pumpScreen(tester, controller, h.FakeRouter());
      expect(
        find.text('En línea recta. No se pudo trazar por calles.'),
        findsOneWidget,
      );
      expect(find.textContaining('≈ '), findsOneWidget);
      // Iniciar sigue disponible: seguirme no depende del trazado.
      expect(primary(tester).onPressed, isNotNull);
    });

    testWidgets('Llamar y WhatsApp avisan a quien abrió la pantalla', (
      tester,
    ) async {
      var calls = 0;
      var chats = 0;
      await pumpScreen(
        tester,
        controller,
        h.FakeRouter(calle()),
        onCall: () => calls++,
        onWhatsapp: () => chats++,
      );
      await tester.ensureVisible(find.text('Llamar'));
      await tester.tap(find.text('Llamar'));
      await tester.ensureVisible(find.text('WhatsApp'));
      await tester.tap(find.text('WhatsApp'));
      expect(calls, 1);
      expect(chats, 1);
    });

    testWidgets('cerca del destino dice que ya llegaste', (tester) async {
      // ~10 m del destino.
      controller.moveTo(destLat + 0.00009, destLng);
      await pumpScreen(tester, controller, h.FakeRouter(calle(meters: 12)));
      expect(find.text('Ya llegaste'), findsOneWidget);
      expect(find.text('En el destino'), findsOneWidget);
    });

    testWidgets('no desborda con texto grande ni en 320 px', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpScreen(
        tester,
        controller,
        h.FakeRouter(calle()),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('desde la ruta', () {
    final stops = [
      h.stop(1, 'Entregado'),
      h.stop(2, 'EnCamino', detalles: '2 × Vela'),
    ];

    testWidgets(
      '"Ver en el mapa" abre la pantalla de esa parada, no la pestaña Mapa',
      (tester) async {
        final router = h.FakeRouter(calle());
        final c = await h.pumpHome(
          tester,
          h.route('EnCurso', stops),
          router: router,
        );
        await tester.ensureVisible(find.text('Ver en el mapa'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver en el mapa'));
        await tester.pumpAndSettle();
        expect(find.byType(StopRouteScreen), findsOneWidget);
        expect(find.text('Ruta a Cliente 2'), findsOneWidget);
        // No se cambió de pestaña: la pantalla va por encima de la ruta.
        expect(find.byType(RouteMap), findsNothing);
        // Y no se pidió el camino global ni se salió a otra app.
        await tester.tap(find.byTooltip('Volver'));
        await tester.pumpAndSettle();
        expect(find.byType(StopRouteScreen), findsNothing);
        expect(find.text('Confirmar entrega'), findsOneWidget);
        await h.teardown(tester, c);
      },
    );
  });
}
