import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/settings/device_settings.dart';
import 'package:geolocator/geolocator.dart';

import 'route_screen_test.dart' as h;

void main() {
  late h.FakeSettingsGateway gateway;
  late DeviceSettingsController controller;

  setUp(() {
    gateway = h.FakeSettingsGateway();
    controller = DeviceSettingsController(gateway: gateway);
  });
  tearDown(() => controller.dispose());

  group('refresh', () {
    test('antes de leer no se sabe nada', () {
      expect(controller.state.loaded, isFalse);
      expect(controller.state.gpsReady, isFalse);
    });

    test('lee ubicación, precisión y notificaciones', () async {
      await controller.refresh();
      final st = controller.state;
      expect(st.loaded, isTrue);
      expect(st.locationServiceOn, isTrue);
      expect(st.hasLocationPermission, isTrue);
      expect(st.precision, LocationPrecision.precise);
      expect(st.notifications, NotificationsState.granted);
      expect(st.gpsReady, isTrue);
    });

    test('con el servicio apagado el GPS no está listo', () async {
      gateway.serviceOn = false;
      await controller.refresh();
      expect(controller.state.gpsReady, isFalse);
    });

    test('permiso bloqueado se reconoce', () async {
      gateway.permission = LocationPermission.deniedForever;
      await controller.refresh();
      expect(controller.state.locationBlocked, isTrue);
      expect(controller.state.hasLocationPermission, isFalse);
    });

    test('notifica a quien escucha', () async {
      var notified = 0;
      controller.addListener(() => notified++);
      await controller.refresh();
      expect(notified, greaterThan(0));
    });

    test('si el sistema falla no se rompe y queda como leído', () async {
      final broken = DeviceSettingsController(gateway: _ThrowingGateway());
      addTearDown(broken.dispose);
      await broken.refresh();
      expect(broken.state.loaded, isTrue);
      expect(broken.state.gpsReady, isFalse);
    });
  });

  group('enableGps', () {
    test('servicio apagado: abre los ajustes de ubicación', () async {
      gateway.serviceOn = false;
      await controller.refresh();
      await controller.enableGps();
      expect(gateway.locationSettingsOpened, 1);
      expect(gateway.appSettingsOpened, 0);
      expect(gateway.locationRequests, 0);
    });

    test('sin permiso: lo pide y se actualiza', () async {
      gateway.permission = LocationPermission.denied;
      await controller.refresh();
      expect(controller.state.gpsReady, isFalse);
      await controller.enableGps();
      expect(gateway.locationRequests, 1);
      expect(controller.state.hasLocationPermission, isTrue);
      expect(gateway.appSettingsOpened, 0);
    });

    test('si al pedirlo queda bloqueado, abre los ajustes de la app', () async {
      gateway.permission = LocationPermission.denied;
      gateway.permissionAfterRequest = LocationPermission.deniedForever;
      await controller.refresh();
      await controller.enableGps();
      expect(gateway.locationRequests, 1);
      expect(gateway.appSettingsOpened, 1);
    });

    test('ya bloqueado: va directo a los ajustes de la app', () async {
      gateway.permission = LocationPermission.deniedForever;
      await controller.refresh();
      await controller.enableGps();
      expect(gateway.locationRequests, 0);
      expect(gateway.appSettingsOpened, 1);
    });

    test('si ya está todo bien no hace nada', () async {
      await controller.refresh();
      await controller.enableGps();
      expect(gateway.locationRequests, 0);
      expect(gateway.locationSettingsOpened, 0);
      expect(gateway.appSettingsOpened, 0);
    });
  });

  group('enablePrecision', () {
    test('aproximada y al volver a preguntar queda precisa', () async {
      gateway.precision = LocationPrecision.approximate;
      gateway.precisionAfterRequest = LocationPrecision.precise;
      await controller.refresh();
      await controller.enablePrecision();
      expect(controller.state.precision, LocationPrecision.precise);
      expect(gateway.fullAccuracyRequests, 1);
      expect(gateway.locationRequests, 1);
      // Se resolvió sin mandar al usuario a buscar en los ajustes.
      expect(gateway.appSettingsOpened, 0);
    });

    test('si sigue aproximada abre los ajustes de la app', () async {
      gateway.precision = LocationPrecision.approximate;
      gateway.precisionAfterRequest = LocationPrecision.approximate;
      await controller.refresh();
      await controller.enablePrecision();
      expect(controller.state.precision, LocationPrecision.approximate);
      expect(gateway.appSettingsOpened, 1);
    });

    test(
      'sin permiso lo pide primero y luego comprueba la precisión',
      () async {
        gateway.permission = LocationPermission.denied;
        gateway.precision = LocationPrecision.unknown;
        gateway.permissionAfterRequest = LocationPermission.whileInUse;
        gateway.precisionAfterRequest = LocationPrecision.precise;
        await controller.refresh();
        await controller.enablePrecision();
        expect(gateway.locationRequests, 1);
        expect(controller.state.hasLocationPermission, isTrue);
        expect(controller.state.precision, LocationPrecision.precise);
        expect(gateway.appSettingsOpened, 0);
      },
    );

    test('sin permiso y bloqueado al pedirlo: abre los ajustes', () async {
      gateway.permission = LocationPermission.denied;
      gateway.permissionAfterRequest = LocationPermission.deniedForever;
      await controller.refresh();
      await controller.enablePrecision();
      expect(gateway.appSettingsOpened, 1);
    });

    test('permiso ya bloqueado: ajustes de la app sin preguntar', () async {
      gateway.permission = LocationPermission.deniedForever;
      await controller.refresh();
      await controller.enablePrecision();
      expect(gateway.locationRequests, 0);
      expect(gateway.appSettingsOpened, 1);
    });

    test('ya precisa: no molesta', () async {
      await controller.refresh();
      await controller.enablePrecision();
      expect(gateway.locationRequests, 0);
      expect(gateway.fullAccuracyRequests, 0);
      expect(gateway.appSettingsOpened, 0);
    });
  });

  group('enableNotifications', () {
    test('desactivadas: pide el permiso y queda activado', () async {
      gateway.notificationsState = NotificationsState.denied;
      await controller.refresh();
      await controller.enableNotifications();
      expect(gateway.notificationRequests, 1);
      expect(controller.state.notifications, NotificationsState.granted);
      expect(gateway.appSettingsOpened, 0);
    });

    test('si el usuario las rechaza para siempre, abre los ajustes', () async {
      gateway.notificationsState = NotificationsState.denied;
      gateway.notificationsAfterRequest = NotificationsState.blocked;
      await controller.refresh();
      await controller.enableNotifications();
      expect(gateway.notificationRequests, 1);
      expect(gateway.appSettingsOpened, 1);
    });

    test('ya bloqueadas: ajustes sin preguntar de nuevo', () async {
      gateway.notificationsState = NotificationsState.blocked;
      await controller.refresh();
      await controller.enableNotifications();
      expect(gateway.notificationRequests, 0);
      expect(gateway.appSettingsOpened, 1);
    });
  });

  group('un toque a la vez', () {
    test('mientras espera al sistema ignora otro toque', () async {
      final slow = _SlowGateway();
      final c = DeviceSettingsController(gateway: slow);
      addTearDown(c.dispose);
      slow.permission = LocationPermission.denied;
      await c.refresh();
      final first = c.enableGps();
      expect(c.busy, contains(DeviceSettingsController.gps));
      final second = c.enableGps();
      slow.releaseRequest();
      await Future.wait([first, second]);
      expect(slow.locationRequests, 1);
      expect(c.busy, isEmpty);
    });
  });

  test('tras soltar el controlador no notifica ni falla', () async {
    final c = DeviceSettingsController(gateway: gateway);
    final pending = c.refresh();
    c.dispose();
    await pending;
  });
}

class _ThrowingGateway extends h.FakeSettingsGateway {
  @override
  Future<bool> isLocationServiceEnabled() async =>
      throw Exception('sin sistema');
}

class _SlowGateway extends h.FakeSettingsGateway {
  final Completer<void> _release = Completer<void>();

  void releaseRequest() => _release.complete();

  @override
  Future<LocationPermission> requestLocationPermission() async {
    locationRequests++;
    await _release.future;
    permission = LocationPermission.whileInUse;
    return permission;
  }
}
