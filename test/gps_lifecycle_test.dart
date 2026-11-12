import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/location/gps_service.dart';
import 'package:geolocator/geolocator.dart';

class Gateway implements LocationGateway {
  final positions = StreamController<Position>.broadcast();
  LocationPermission permission = LocationPermission.whileInUse;
  bool cancelled = false;
  @override
  Future<bool> isServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Stream<Position> positionStream({required int distanceFilter}) =>
      positions.stream;
  @override
  Future<bool> openLocationSettings() async => true;
  @override
  Future<bool> openAppSettings() async => true;
}

Position position(DateTime timestamp) => Position(
  longitude: -78,
  latitude: -1,
  timestamp: timestamp,
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
void main() {
  test(
    'Latest GPS sample keeps its original UTC time and ignores older samples',
    () async {
      final gateway = Gateway();
      final gps = GpsService(gateway: gateway);
      final captured = DateTime.utc(2026, 10, 17, 12);
      await gps.start();
      gateway.positions.add(position(captured));
      await Future<void>.delayed(Duration.zero);
      gateway.positions.add(
        position(captured.subtract(const Duration(minutes: 1))),
      );
      await Future<void>.delayed(Duration.zero);
      expect(gps.latestSample?.capturedAtUtc, captured);
      await gps.stop();
      expect(gateway.positions.hasListener, isFalse);
      await gateway.positions.close();
    },
  );
  test(
    'A GPS stream error cancels capture instead of only changing its label',
    () async {
      final gateway = Gateway();
      final gps = GpsService(gateway: gateway);
      await gps.start();
      gateway.positions.addError(StateError('Permission revoked'));
      await Future<void>.delayed(Duration.zero);
      expect(gateway.positions.hasListener, isFalse);
      expect(gps.state, GpsState.unavailable);
      await gateway.positions.close();
    },
  );
  test('Denied permission never subscribes to a location stream', () async {
    final gateway = Gateway()..permission = LocationPermission.denied;
    final gps = GpsService(gateway: gateway);
    expect(await gps.start(), GpsState.permissionDenied);
    expect(gateway.positions.hasListener, isFalse);
    await gateway.positions.close();
  });
}
