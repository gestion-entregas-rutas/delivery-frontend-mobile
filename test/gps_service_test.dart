import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/location/gps_service.dart';
import 'package:geolocator/geolocator.dart';

class _Gateway implements LocationGateway {
  _Gateway({
    this.enabled = true,
    this.permission = LocationPermission.whileInUse,
  });
  bool enabled;
  LocationPermission permission;

  @override
  Future<bool> isServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Stream<Position> positionStream({required int distanceFilter}) =>
      const Stream<Position>.empty();

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  test('GPS service reports disabled device without throwing', () async {
    final gps = GpsService(gateway: _Gateway(enabled: false));
    expect(await gps.start(), GpsState.serviceDisabled);
    expect(gps.latestSample, isNull);
  });

  test('GPS service reports permanently denied permission', () async {
    final gps = GpsService(
      gateway: _Gateway(permission: LocationPermission.deniedForever),
    );
    expect(await gps.start(), GpsState.permissionDeniedForever);
  });

  test('GPS preparation remains local and waits for a valid sample', () async {
    final gps = GpsService(gateway: _Gateway());
    expect(await gps.start(), GpsState.waitingForSample);
    expect(gps.latestSample, isNull);
    await gps.stop();
    expect(gps.state, GpsState.stopped);
  });
}
