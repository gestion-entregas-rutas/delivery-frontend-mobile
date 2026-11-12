import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend_mobile/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/data/api/api_client.dart';
import 'package:frontend_mobile/data/api/api_exception.dart';
import 'package:frontend_mobile/data/api/logistica_repository.dart';
import 'package:frontend_mobile/location/gps_service.dart';
import 'package:frontend_mobile/models/logistica_models.dart';
import 'package:frontend_mobile/realtime/seguimiento_service.dart';
import 'package:frontend_mobile/state/driver_controller.dart';

RutaDto sample({
  String state = 'EnCurso',
  String date = '2026-10-17',
  String driver = 'd',
  String id = 'r',
}) => RutaDto(
  id: id,
  fecha: date,
  zonaId: 'z',
  repartidorId: driver,
  capacidad: 1,
  estado: state,
  paradas: [
    ParadaDto(
      orden: 1,
      pedido: PedidoDto(
        id: 'p',
        clienteNombre: 'Cliente',
        clienteTelefono: '099',
        direccion: 'Dirección',
        ubicacion: const PuntoDto(latitud: -1, longitud: -2),
        fechaEntrega: date,
        horaEntrega: '09:00:00',
        estado: state == 'Completada' ? 'Entregado' : 'EnCamino',
      ),
    ),
  ],
);

class Repo extends LogisticaRepository {
  Repo() : super(ApiClient(baseUrl: 'http://localhost:5289'));
  Future<RutaDto?> Function(String date)? active;
  RutaDto? current = sample();
  int posts = 0;
  int gets = 0;
  @override
  Future<RutaDto?> rutaActiva(String id, String date) async {
    gets++;
    return active != null ? await active!(date) : current;
  }

  @override
  Future<RutaDto> ruta(String id) async => sample(state: 'Completada');
  @override
  Future<PedidoDto> confirmarEntrega(String id) async {
    posts++;
    throw const ApiException(message: 'Network', isNetwork: true);
  }
}

class Realtime extends SeguimientoService {
  Realtime() : super(hubUrl: 'http://localhost:5289');
  int starts = 0;
  bool stopped = false;
  @override
  Future<void> start({required String driverId}) async {
    starts++;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

class Gps extends GpsService {
  int stops = 0;
  @override
  Future<void> stop() async {
    stops++;
  }
}

DriverController create(Repo repo, {Realtime? hub, Gps? gps}) =>
    DriverController(
      repository: repo,
      driverId: 'd',
      seguimiento: hub ?? Realtime(),
      gps: gps ?? Gps(),
      initialDate: DateTime(2026, 10, 17),
    );
void main() {
  test('A stale GET cannot overwrite a newer date', () async {
    final repo = Repo();
    final first = Completer<RutaDto?>();
    repo.active = (date) => date == '2026-10-17'
        ? first.future
        : Future.value(sample(date: date, id: 'next'));
    final c = create(repo);
    final old = c.refresh();
    await c.changeDate(DateTime(2026, 10, 18));
    first.complete(sample());
    await old;
    expect(c.route?.id, 'next');
    expect(c.selectedDate, '2026-10-18');
    c.dispose();
  });
  test(
    'Uncertain POST and failed refresh block subsequent mutations',
    () async {
      final repo = Repo();
      final c = create(repo);
      await c.refresh();
      repo.active = (_) =>
          Future.error(const ApiException(message: 'Offline', isNetwork: true));
      await c.confirmDelivery('p');
      expect(c.uncertainMutation, isTrue);
      await c.confirmDelivery('p');
      expect(repo.posts, 1);
      expect(c.route?.paradas.single.pedido.estado, 'EnCamino');
      c.dispose();
    },
  );
  test('Completed route remains visible after active endpoint 404', () async {
    final repo = Repo();
    final c = create(repo);
    await c.refresh();
    repo.current = null;
    await c.refresh();
    expect(c.route?.estado, 'Completada');
    expect(c.loadState, DriverLoadState.loaded);
    c.dispose();
  });
  test(
    'Reconnect refreshes REST and foreign notifications are discarded',
    () async {
      final repo = Repo();
      final hub = Realtime();
      final c = create(repo, hub: hub);
      await c.initialize();
      hub.onRutaActualizada?.call(
        sample(driver: 'foreign', state: 'Completada'),
      );
      expect(c.route?.estado, 'EnCurso');
      hub.onRutaActualizada?.call(
        sample(date: '2026-10-18', state: 'Completada'),
      );
      expect(c.route?.estado, 'EnCurso');
      await hub.onReconexion?.call();
      expect(repo.gets, 2);
      await c.logout();
      hub.onRutaActualizada?.call(sample());
      expect(c.route, isNull);
      expect(hub.stopped, isTrue);
      c.dispose();
    },
  );
  test('A push update invalidates an older in-flight REST response', () async {
    final repo = Repo();
    final hub = Realtime();
    final c = create(repo, hub: hub);
    await c.refresh();
    final delayed = Completer<RutaDto?>();
    repo.active = (_) => delayed.future;
    final refreshing = c.refresh();
    hub.onRutaActualizada?.call(sample(state: 'Completada'));
    delayed.complete(sample());
    await refreshing;
    expect(c.route?.estado, 'Completada');
    c.dispose();
  });
  testWidgets('Route actions fit a 320px device', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = Repo();
    final c = create(repo);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repo, driverId: 'd', controller: c),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(find.text('Confirmar entrega'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Confirmar entrega'));
    await tester.pumpAndSettle();
    expect(find.text('¿Confirmas la entrega a Cliente?'), findsOneWidget);
    expect(repo.posts, 0);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  test(
    'A stale empty response cannot stop GPS for a newer active route',
    () async {
      final repo = Repo();
      final gps = Gps();
      final c = create(repo, gps: gps);
      final delayed = Completer<RutaDto?>();
      repo.active = (_) => delayed.future;
      final old = c.refresh();
      repo.active = (_) async => sample();
      await c.refresh();
      final stopped = gps.stops;
      delayed.complete(null);
      await old;
      expect(gps.stops, stopped);
      expect(c.route?.estado, 'EnCurso');
      c.dispose();
    },
  );
}
