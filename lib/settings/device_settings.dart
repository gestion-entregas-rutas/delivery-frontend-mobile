import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Estado del permiso de notificaciones.
enum NotificationsState {
  granted,
  denied,

  /// El sistema ya no vuelve a preguntar: solo se cambia desde los ajustes.
  blocked,
  unknown,
}

/// Qué tan exacta es la ubicación que el teléfono le deja a la app.
enum LocationPrecision { precise, approximate, unknown }

/// Acceso a los ajustes del teléfono. Es una interfaz para poder probar sin
/// el sistema operativo.
abstract class DeviceSettingsGateway {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> locationPermission();
  Future<LocationPermission> requestLocationPermission();
  Future<LocationPrecision> locationPrecision();

  /// iOS: pide precisión total temporal. Android: no existe un equivalente,
  /// devuelve la precisión actual.
  Future<LocationPrecision> requestFullAccuracy();

  Future<bool> openLocationSettings();
  Future<bool> openAppSettings();

  Future<NotificationsState> notifications();
  Future<NotificationsState> requestNotifications();
}

/// Implementación real con geolocator y permission_handler.
class SystemDeviceSettingsGateway implements DeviceSettingsGateway {
  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> locationPermission() =>
      Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestLocationPermission() =>
      Geolocator.requestPermission();

  @override
  Future<LocationPrecision> locationPrecision() async {
    try {
      final status = await Geolocator.getLocationAccuracy();
      return switch (status) {
        LocationAccuracyStatus.precise => LocationPrecision.precise,
        LocationAccuracyStatus.reduced => LocationPrecision.approximate,
        LocationAccuracyStatus.unknown => LocationPrecision.unknown,
      };
    } on Object {
      // Sin permiso de ubicación Android responde con un error.
      return LocationPrecision.unknown;
    }
  }

  @override
  Future<LocationPrecision> requestFullAccuracy() async {
    if (Platform.isIOS) {
      try {
        await Geolocator.requestTemporaryFullAccuracy(
          purposeKey: 'PreciseLocation',
        );
      } on Object {
        // Sin la clave en Info.plist o sin permiso: se resuelve en ajustes.
      }
    }
    return locationPrecision();
  }

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<bool> openAppSettings() => ph.openAppSettings();

  NotificationsState _map(ph.PermissionStatus status) {
    if (status.isGranted || status.isProvisional) {
      return NotificationsState.granted;
    }
    if (status.isPermanentlyDenied) return NotificationsState.blocked;
    if (status.isDenied) return NotificationsState.denied;
    return NotificationsState.unknown;
  }

  @override
  Future<NotificationsState> notifications() async {
    try {
      return _map(await ph.Permission.notification.status);
    } on Object {
      return NotificationsState.unknown;
    }
  }

  @override
  Future<NotificationsState> requestNotifications() async {
    try {
      return _map(await ph.Permission.notification.request());
    } on Object {
      return NotificationsState.unknown;
    }
  }
}

/// Fotografía de los ajustes del teléfono que le importan a la app.
@immutable
class DeviceSettingsState {
  const DeviceSettingsState({
    this.locationServiceOn,
    this.permission,
    this.precision = LocationPrecision.unknown,
    this.notifications = NotificationsState.unknown,
    this.loaded = false,
  });

  /// `null` mientras no se sabe.
  final bool? locationServiceOn;
  final LocationPermission? permission;
  final LocationPrecision precision;
  final NotificationsState notifications;

  /// Si ya se leyeron los ajustes al menos una vez.
  final bool loaded;

  bool get hasLocationPermission =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  bool get locationBlocked => permission == LocationPermission.deniedForever;

  /// El GPS está listo: servicio encendido y permiso concedido.
  bool get gpsReady => locationServiceOn == true && hasLocationPermission;

  DeviceSettingsState copyWith({
    bool? locationServiceOn,
    LocationPermission? permission,
    LocationPrecision? precision,
    NotificationsState? notifications,
    bool? loaded,
  }) => DeviceSettingsState(
    locationServiceOn: locationServiceOn ?? this.locationServiceOn,
    permission: permission ?? this.permission,
    precision: precision ?? this.precision,
    notifications: notifications ?? this.notifications,
    loaded: loaded ?? this.loaded,
  );
}

/// Lee y cambia los ajustes del teléfono. Los botones de Perfil llaman aquí.
///
/// Nada de esto cambia el estado de una ruta ni de una entrega, y no envía
/// datos al servidor.
class DeviceSettingsController extends ChangeNotifier {
  DeviceSettingsController({DeviceSettingsGateway? gateway})
    : gateway = gateway ?? SystemDeviceSettingsGateway();

  final DeviceSettingsGateway gateway;

  DeviceSettingsState _state = const DeviceSettingsState();
  DeviceSettingsState get state => _state;

  /// Qué ajuste está esperando una respuesta del sistema (evita doble toque).
  Set<String> busy = <String>{};
  bool _disposed = false;

  static const String gps = 'gps';
  static const String precision = 'precision';
  static const String notifications = 'notifications';

  void _set(DeviceSettingsState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  void _setBusy(String key, bool value) {
    if (_disposed) return;
    value ? busy.add(key) : busy.remove(key);
    notifyListeners();
  }

  /// Vuelve a leer todo. Se llama al abrir Perfil y al volver de los ajustes
  /// del teléfono.
  Future<void> refresh() async {
    try {
      final results = await Future.wait<Object?>([
        gateway.isLocationServiceEnabled(),
        gateway.locationPermission(),
        gateway.locationPrecision(),
        gateway.notifications(),
      ]);
      _set(
        DeviceSettingsState(
          locationServiceOn: results[0] as bool,
          permission: results[1] as LocationPermission,
          precision: results[2] as LocationPrecision,
          notifications: results[3] as NotificationsState,
          loaded: true,
        ),
      );
    } on Object {
      // Si el sistema no responde se deja lo que había, ya marcado como leído.
      _set(_state.copyWith(loaded: true));
    }
  }

  /// Ubicación: abre los ajustes si el servicio está apagado, pide el permiso
  /// si falta, y manda a los ajustes de la app si quedó bloqueado.
  Future<void> enableGps() async {
    if (busy.contains(gps)) return;
    _setBusy(gps, true);
    try {
      if (_state.locationServiceOn == false) {
        await gateway.openLocationSettings();
      } else if (_state.locationBlocked) {
        await gateway.openAppSettings();
      } else if (!_state.hasLocationPermission) {
        final permission = await gateway.requestLocationPermission();
        if (permission == LocationPermission.deniedForever) {
          await gateway.openAppSettings();
        }
      }
    } on Object {
      // Se vuelve a leer abajo; el estado real manda.
    } finally {
      _setBusy(gps, false);
    }
    await refresh();
  }

  /// Ubicación precisa: pide el permiso (en Android 12+ vuelve a ofrecer
  /// "Precisa" si solo diste "Aproximada"); si sigue sin ser precisa, abre los
  /// ajustes de la app, que es donde se cambia.
  Future<void> enablePrecision() async {
    if (busy.contains(precision)) return;
    _setBusy(precision, true);
    try {
      if (_state.locationBlocked) {
        await gateway.openAppSettings();
      } else {
        if (!_state.hasLocationPermission) {
          final permission = await gateway.requestLocationPermission();
          if (permission == LocationPermission.deniedForever) {
            await gateway.openAppSettings();
            return;
          }
        }
        var current = await gateway.locationPrecision();
        if (current == LocationPrecision.approximate) {
          current = await gateway.requestFullAccuracy();
        }
        if (current == LocationPrecision.approximate) {
          await gateway.requestLocationPermission();
          current = await gateway.locationPrecision();
        }
        if (current == LocationPrecision.approximate) {
          await gateway.openAppSettings();
        }
      }
    } on Object {
      // El estado real se lee abajo.
    } finally {
      _setBusy(precision, false);
      await refresh();
    }
  }

  /// Notificaciones: pide el permiso; si el sistema ya no pregunta, abre los
  /// ajustes de la app.
  Future<void> enableNotifications() async {
    if (busy.contains(notifications)) return;
    _setBusy(notifications, true);
    try {
      if (_state.notifications == NotificationsState.blocked) {
        await gateway.openAppSettings();
      } else {
        final result = await gateway.requestNotifications();
        if (result == NotificationsState.blocked) {
          await gateway.openAppSettings();
        }
      }
    } on Object {
      // El estado real se lee abajo.
    } finally {
      _setBusy(notifications, false);
      await refresh();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
