import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/data/api/api_client.dart';
import 'package:frontend_mobile/data/api/logistica_repository.dart';
import 'package:frontend_mobile/data/routing/road_router.dart';
import 'package:frontend_mobile/settings/device_settings.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend_mobile/location/gps_service.dart';
import 'package:frontend_mobile/models/logistica_models.dart';
import 'package:frontend_mobile/realtime/seguimiento_service.dart';
import 'package:frontend_mobile/screens/home_screen.dart';
import 'package:frontend_mobile/state/driver_controller.dart';
import 'package:frontend_mobile/theme/app_theme.dart';

ParadaDto stop(
  int orden,
  String estado, {
  String nombre = 'Cliente',
  String direccion = 'Calle 12 #4-30',
  String? detalles,
}) => ParadaDto(
  orden: orden,
  pedido: PedidoDto(
    id: 'p$orden',
    clienteNombre: '$nombre $orden',
    clienteTelefono: '099$orden',
    direccion: direccion,
    detalles: detalles,
    ubicacion: const PuntoDto(latitud: -1, longitud: -2),
    fechaEntrega: '2026-10-17',
    horaEntrega: '09:00:00',
    estado: estado,
  ),
);

RutaDto route(String estado, List<ParadaDto> paradas) => RutaDto(
  id: 'r',
  fecha: '2026-10-17',
  zonaId: 'z',
  repartidorId: 'd',
  capacidad: 5,
  estado: estado,
  paradas: paradas,
);

class FakeRepo extends LogisticaRepository {
  FakeRepo(this.current) : super(ApiClient(baseUrl: 'http://localhost:5289'));
  RutaDto? current;

  /// Cuántas veces se envió la ubicación al servidor.
  int reports = 0;

  /// Cuántas veces se pidió iniciar la ruta al servidor.
  int startRequests = 0;

  /// Cuántas veces se volvió a pedir la ruta completa (al cerrarla).
  int routeFetches = 0;

  @override
  Future<PedidoDto> confirmarEntrega(String pedidoId) async {
    final pedido = current!.paradas
        .map((p) => p.pedido)
        .firstWhere((p) => p.id == pedidoId);
    return pedido.copyWith(estado: 'Entregado');
  }

  @override
  Future<RutaDto> ruta(String rutaId) async {
    routeFetches++;
    final base = current!;
    return RutaDto(
      id: base.id,
      fecha: base.fecha,
      zonaId: base.zonaId,
      repartidorId: base.repartidorId,
      capacidad: base.capacidad,
      estado: 'Completada',
      paradas: base.paradas,
    );
  }

  @override
  Future<RutaDto> iniciarRuta(String rutaId) async {
    startRequests++;
    final base = current!;
    final started = RutaDto(
      id: base.id,
      fecha: base.fecha,
      zonaId: base.zonaId,
      repartidorId: base.repartidorId,
      capacidad: base.capacidad,
      estado: 'EnCurso',
      paradas: base.paradas,
    );
    current = started;
    return started;
  }

  @override
  Future<RutaDto?> rutaActiva(String id, String date) async => current;

  @override
  Future<void> reportarUbicacion({
    required String rutaId,
    required double latitud,
    required double longitud,
    required double precisionMetros,
    required DateTime capturadaEnUtc,
  }) async {
    reports++;
  }
}

class FakeRealtime extends SeguimientoService {
  FakeRealtime() : super(hubUrl: 'http://localhost:5289');
  @override
  Future<void> start({required String driverId}) async {}
  @override
  Future<void> stop() async {}
}

/// GPS de prueba: no toca el plugin. [startResult] es lo que "encontró" al
/// encender (por defecto, ubicación apagada) y [emit] simula una lectura.
class FakeGps extends GpsService {
  GpsState startResult = GpsState.serviceDisabled;
  int starts = 0;
  int stops = 0;
  int settingsOpened = 0;

  @override
  Future<GpsState> start() async {
    starts++;
    state = startResult;
    onStateChanged?.call(startResult);
    return startResult;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }

  void emit(GpsSample sample) => onSample?.call(sample);
}

/// Ajustes del teléfono de prueba: no tocan el sistema. Por defecto todo está
/// activado; cada prueba cambia lo que necesita y mira qué se pidió.
class FakeSettingsGateway implements DeviceSettingsGateway {
  bool serviceOn = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPrecision precision = LocationPrecision.precise;
  NotificationsState notificationsState = NotificationsState.granted;

  // Qué pasa cuando el sistema pregunta: lo que el usuario "contesta".
  LocationPermission permissionAfterRequest = LocationPermission.whileInUse;
  LocationPrecision precisionAfterRequest = LocationPrecision.precise;
  NotificationsState notificationsAfterRequest = NotificationsState.granted;

  int locationSettingsOpened = 0;
  int appSettingsOpened = 0;
  int locationRequests = 0;
  int fullAccuracyRequests = 0;
  int notificationRequests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceOn;

  @override
  Future<LocationPermission> locationPermission() async => permission;

  @override
  Future<LocationPermission> requestLocationPermission() async {
    locationRequests++;
    permission = permissionAfterRequest;
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      precision = precisionAfterRequest;
    }
    return permission;
  }

  @override
  Future<LocationPrecision> locationPrecision() async => precision;

  @override
  Future<LocationPrecision> requestFullAccuracy() async {
    fullAccuracyRequests++;
    return precision;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return true;
  }

  @override
  Future<NotificationsState> notifications() async => notificationsState;

  @override
  Future<NotificationsState> requestNotifications() async {
    notificationRequests++;
    notificationsState = notificationsAfterRequest;
    return notificationsState;
  }
}

/// Trazador de prueba: devuelve [result] (o nada) sin tocar la red y anota
/// cada petición.
class FakeRouter implements RoadRouter {
  FakeRouter([this.result]);
  RoadRoute? result;
  final List<List<LatLng>> calls = [];

  @override
  Future<RoadRoute?> route(List<LatLng> waypoints) async {
    calls.add(List.of(waypoints));
    return result;
  }
}

Future<DriverController> pumpHome(
  WidgetTester tester,
  RutaDto? ruta, {
  Size size = const Size(360, 780),
  RoadRouter? router,
  FakeGps? gps,
  FakeSettingsGateway? settings,

  /// "Hoy" para la prueba; por defecto, el mismo día de las rutas de ejemplo.
  DateTime? today,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = FakeRepo(ruta);
  final controller = DriverController(
    repository: repo,
    driverId: 'd',
    seguimiento: FakeRealtime(),
    gps: gps ?? FakeGps(),
    initialDate: DateTime(2026, 10, 17),
    clock: () => today ?? DateTime(2026, 10, 17, 9),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: HomeScreen(
        repository: repo,
        driverId: 'd',
        controller: controller,
        // Sin red en las pruebas: un trazador falso que no responde nada.
        router: router ?? FakeRouter(),
        deviceSettings: DeviceSettingsController(
          gateway: settings ?? FakeSettingsGateway(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return controller;
}

Future<void> teardown(WidgetTester tester, DriverController c) async {
  await tester.pumpWidget(const SizedBox());
  c.dispose();
}

void main() {
  testWidgets('ruta planificada ofrece Iniciar ruta y no hay parada actual', (
    tester,
  ) async {
    final c = await pumpHome(
      tester,
      route('Planificada', [
        stop(1, 'AsignadoARuta'),
        stop(2, 'AsignadoARuta'),
      ]),
    );
    expect(find.text('Iniciar ruta'), findsOneWidget);
    expect(find.text('Siguiente parada'), findsNothing);
    expect(find.text('Cliente 1'), findsOneWidget);
    expect(find.text('Cliente 2'), findsOneWidget);
    await teardown(tester, c);
  });

  testWidgets('parada asignada muestra Voy en camino', (tester) async {
    final c = await pumpHome(
      tester,
      route('EnCurso', [stop(1, 'AsignadoARuta', detalles: '2 × Vela')]),
    );
    expect(find.text('Voy en camino'), findsOneWidget);
    expect(find.text('Siguiente parada'), findsOneWidget);
    expect(find.text('Llamar'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Ver en el mapa'), findsOneWidget);
    expect(find.text('Navegar'), findsNothing);
    expect(find.text('2 × Vela'), findsOneWidget);
    await teardown(tester, c);
  });

  testWidgets('parada en camino muestra Confirmar entrega, un solo botón', (
    tester,
  ) async {
    final c = await pumpHome(
      tester,
      route('EnCurso', [stop(1, 'Entregado'), stop(2, 'EnCamino')]),
    );
    expect(find.text('Confirmar entrega'), findsOneWidget);
    expect(find.text('En camino'), findsOneWidget);
    expect(find.text('1 de 2 entregas'), findsOneWidget);
    await teardown(tester, c);
  });

  testWidgets('ruta terminada muestra el aviso y ningún botón de acción', (
    tester,
  ) async {
    final c = await pumpHome(
      tester,
      route('Completada', [stop(1, 'Entregado'), stop(2, 'Entregado')]),
    );
    expect(find.text('Ruta completada: 2 entregas'), findsOneWidget);
    expect(find.text('Confirmar entrega'), findsNothing);
    expect(find.text('Iniciar ruta'), findsNothing);
    await teardown(tester, c);
  });

  testWidgets('sin ruta muestra estado vacío con acción', (tester) async {
    final c = await pumpHome(tester, null);
    expect(find.text('Sin entregas asignadas'), findsOneWidget);
    expect(find.text('Actualizar'), findsWidgets);
    await teardown(tester, c);
  });

  testWidgets('textos largos no desbordan en 320 px', (tester) async {
    final c = await pumpHome(
      tester,
      route('EnCurso', [
        stop(1, 'Entregado', nombre: 'Doyle, Arthur Conan Ignatius de la Vega'),
        stop(
          2,
          'EnCamino',
          nombre: 'Fyodor Mikhailovich Dostoevsky',
          direccion: '5/2, Kuznechny Lane, Saint Petersburg, Russian Empire, edificio B',
          detalles: '2 × Vela perfumada Yankee Candle grande, 1 × Jabón',
        ),
        stop(3, 'AsignadoARuta'),
      ]),
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    await teardown(tester, c);
  });

  testWidgets('pantalla ancha usa dos columnas sin desbordar', (tester) async {
    final c = await pumpHome(
      tester,
      route('EnCurso', [stop(1, 'Entregado'), stop(2, 'EnCamino')]),
      size: const Size(1100, 800),
    );
    expect(tester.takeException(), isNull);
    // La acción va dentro del panel, no en una barra fija.
    expect(find.text('Confirmar entrega'), findsOneWidget);
    await teardown(tester, c);
  });

  testWidgets('el perfil muestra cerrar sesión', (tester) async {
    final c = await pumpHome(tester, null);
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    expect(find.text('Cerrar sesión'), findsOneWidget);
    await teardown(tester, c);
  });
}
