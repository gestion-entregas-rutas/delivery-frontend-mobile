import 'dart:async';

import 'package:geolocator/geolocator.dart';

class GpsSample {
  const GpsSample({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAtUtc,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAtUtc;
}

enum GpsState {
  stopped,
  checking,
  waitingForSample,
  active,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  accuracyInsufficient,
  unavailable,
}

abstract class LocationGateway {
  Future<bool> isServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Stream<Position> positionStream({required int distanceFilter});
  Future<bool> openLocationSettings();
  Future<bool> openAppSettings();
}

class GeolocatorGateway implements LocationGateway {
  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Stream<Position> positionStream({required int distanceFilter}) =>
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      );

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

/// Preparación GPS local. El contrato GPS del backend aún no existe, por lo
/// que esta clase nunca hace POST ni publica eventos de ubicación.
class GpsService {
  GpsService({LocationGateway? gateway})
    : gateway = gateway ?? GeolocatorGateway();

  final LocationGateway gateway;
  StreamSubscription<Position>? _subscription;
  GpsState state = GpsState.stopped;
  GpsSample? latestSample;
  void Function(GpsSample sample)? onSample;
  void Function(GpsState state)? onStateChanged;

  Future<GpsState> start() async {
    await stop();
    final token = _startToken;
    final readiness = await checkReadiness();
    if (token != _startToken) {
      _setState(GpsState.stopped);
      return state;
    }
    if (readiness != GpsState.waitingForSample) return state;
    final streamToken = ++_startToken;
    try {
      _subscription = gateway
          .positionStream(distanceFilter: 20)
          .listen(
            (position) {
              if (streamToken == _startToken) _onPosition(position);
            },
            onError: (_) {
              if (streamToken == _startToken) {
                unawaited(_stopUnavailable());
              }
            },
          );
      _setState(GpsState.waitingForSample);
    } on Object {
      await _stopUnavailable();
    }
    return state;
  }

  Future<void> _stopUnavailable() async {
    await stop();
    _setState(GpsState.unavailable);
  }

  /// Checks service and permission without subscribing to a stream.
  Future<GpsState> checkReadiness() async {
    try {
      _setState(GpsState.checking);
      if (!await gateway.isServiceEnabled()) {
        _setState(GpsState.serviceDisabled);
        return state;
      }
      var permission = await gateway.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await gateway.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setState(GpsState.permissionDenied);
        return state;
      }
      if (permission == LocationPermission.deniedForever) {
        _setState(GpsState.permissionDeniedForever);
        return state;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _setState(GpsState.permissionDenied);
        return state;
      }
      _setState(GpsState.waitingForSample);
      return state;
    } on Object {
      _setState(GpsState.unavailable);
      return state;
    }
  }

  void _onPosition(Position position) {
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180 ||
        !position.accuracy.isFinite ||
        position.accuracy < 0 ||
        position.accuracy > 1000) {
      _setState(GpsState.accuracyInsufficient);
      return;
    }
    final sample = GpsSample(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      capturedAtUtc: position.timestamp.toUtc(),
    );
    if (latestSample != null &&
        !sample.capturedAtUtc.isAfter(latestSample!.capturedAtUtc)) {
      return;
    }
    latestSample = sample;
    _setState(GpsState.active);
    onSample?.call(sample);
  }

  Future<void> stop() async {
    _startToken++;
    final subscription = _subscription;
    _subscription = null;
    if (state != GpsState.stopped) _setState(GpsState.stopped);
    await subscription?.cancel();
  }

  Future<bool> openSettings() async {
    if (state == GpsState.serviceDisabled) {
      return gateway.openLocationSettings();
    }
    return gateway.openAppSettings();
  }

  void _setState(GpsState value) {
    state = value;
    onStateChanged?.call(value);
  }

  int _startToken = 0;
}
