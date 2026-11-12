import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../data/api/api_exception.dart';
import '../data/api/logistica_repository.dart';
import 'auth_models.dart';
import 'auth_repository.dart';
import 'session_store.dart';

enum AuthStatus {
  unknown,
  restoring,
  signedOut,
  authenticating,
  signedIn,
  needsCredentialChange,
  temporarilyUnavailable,
  changingCredentials,
  signingOut,
}

class AuthController extends ChangeNotifier {
  AuthController({
    required this.api,
    SessionStore? store,
    AuthRepository? repository,
    DateTime Function()? clock,
  }) : store = store ?? SecureSessionStore(),
       repository = repository ?? AuthRepository(api),
       _clock = clock ?? DateTime.now;

  final ApiClient api;
  final SessionStore store;
  final AuthRepository repository;
  final DateTime Function() _clock;

  AuthStatus status = AuthStatus.unknown;
  AuthSession? session;
  AuthUser? user;
  ApiException? error;
  String? lastWarning;
  bool _disposed = false;
  int _generation = 0;
  Timer? _expiryTimer;
  Future<void> _operations = Future<void>.value();
  Future<void> _storageOperations = Future<void>.value();
  bool _credentialChangeInFlight = false;

  String? get accessToken {
    final current = session;
    if (current == null) return null;
    if (current.isExpired(_clock())) {
      scheduleMicrotask(() => unawaited(_expire(current.accessToken)));
      return null;
    }
    return current.accessToken;
  }

  String? get driverId => user?.repartidorId;
  bool get isSignedIn => status == AuthStatus.signedIn;
  bool get needsCredentialChange => status == AuthStatus.needsCredentialChange;
  bool get canUseProtectedOperations =>
      isSignedIn &&
      _validConductor(user) &&
      !(user?.debeCambiarCredenciales ?? true) &&
      accessToken != null;
  LogisticaRepository get logisticsRepository => LogisticaRepository(api);

  Future<void> restore() {
    final generation = ++_generation;
    return _enqueue(() async {
      _setStatus(AuthStatus.restoring, clearError: true);
      AuthSession? saved;
      try {
        saved = await _readStorage();
      } on Object {
        error = const ApiException(
          message: 'No se pudo leer la sesión segura.',
        );
        _setStatus(AuthStatus.temporarilyUnavailable, clearError: false);
        return;
      }
      if (!_current(generation)) return;
      if (saved == null) {
        _setStatus(AuthStatus.signedOut);
        return;
      }
      if (saved.isExpired(_clock())) {
        await _clearStorage();
        if (_current(generation)) _setStatus(AuthStatus.signedOut);
        return;
      }
      session = saved;
      _armExpiry(saved);
      try {
        final me = await repository.me();
        if (!_current(generation)) return;
        if (!_validConductor(me)) {
          await _invalidateLocal(generation);
          return;
        }
        user = me;
        session = saved.copyWith(user: me);
        try {
          await _writeStorage(session!);
        } on Object {
          error = const ApiException(
            message: 'No se pudo actualizar la sesión segura.',
          );
          _setStatus(AuthStatus.temporarilyUnavailable, clearError: false);
          return;
        }
        if (!_current(generation)) return;
        _setStatus(
          me.debeCambiarCredenciales
              ? AuthStatus.needsCredentialChange
              : AuthStatus.signedIn,
        );
      } on ApiException catch (exception) {
        if (!_current(generation)) return;
        if (exception.statusCode == 401 || saved.isExpired(_clock())) {
          await _invalidateLocal(generation);
        } else {
          error = exception;
          _setStatus(AuthStatus.temporarilyUnavailable, clearError: false);
        }
      } on Object {
        if (!_current(generation)) return;
        error = const ApiException(message: 'No se pudo validar la sesión.');
        _setStatus(AuthStatus.temporarilyUnavailable, clearError: false);
      }
    });
  }

  Future<void> retryRestore() => restore();

  Future<bool> validateCurrentSession() async {
    if (!canUseProtectedOperations || session == null) return false;
    final generation = _generation;
    final current = session!;
    if (current.isExpired(_clock())) {
      await _expire(current.accessToken);
      return false;
    }
    try {
      final me = await repository.me();
      if (!_current(generation)) return false;
      if (!_validConductor(me)) {
        await _invalidateLocal(generation);
        return false;
      }
      final bindingChanged =
          me.id != current.user.id ||
          me.repartidorId != current.user.repartidorId;
      user = me;
      session = current.copyWith(user: me);
      if (me.debeCambiarCredenciales) {
        _setStatus(AuthStatus.needsCredentialChange);
        return false;
      }
      await _writeStorage(session!);
      if (!_current(generation)) return false;
      if (bindingChanged) {
        // The keyed authenticated screen must recreate its driver controller.
        _notify();
        return false;
      }
      return _current(generation) && canUseProtectedOperations;
    } on ApiException catch (exception) {
      if (exception.statusCode == 401) await _expire(current.accessToken);
      if (_current(generation) && exception.statusCode != 401) {
        error = exception;
        _setStatus(AuthStatus.temporarilyUnavailable, clearError: false);
      }
      return false;
    } on Object {
      if (_current(generation)) {
        error = const ApiException(message: 'No se pudo validar la sesión.');
        _setStatus(AuthStatus.temporarilyUnavailable, clearError: false);
      }
      return false;
    }
  }

  Future<void> login({required String username, required String password}) {
    final generation = ++_generation;
    _cancelExpiry();
    // Login is anonymous. Clear the in-memory bearer synchronously so a
    // queued login request can never inherit a previous session token.
    session = null;
    user = null;
    unawaited(_clearStorage());
    return _enqueue(() async {
      _setStatus(AuthStatus.authenticating, clearError: true);
      try {
        final next = await repository.login(
          username: username.trim(),
          password: password,
        );
        if (!_current(generation)) return;
        if (!_validConductor(next.user) || next.isExpired(_clock())) {
          throw const ApiException(
            message: 'La cuenta no tiene un perfil de conductor activo.',
          );
        }
        await _writeStorage(next);
        if (!_current(generation)) return;
        session = next;
        user = next.user;
        _armExpiry(next);
        _setStatus(
          next.user.debeCambiarCredenciales
              ? AuthStatus.needsCredentialChange
              : AuthStatus.signedIn,
        );
      } on ApiException catch (exception) {
        if (!_current(generation)) return;
        // Keep credential failures indistinguishable so the login surface
        // cannot enumerate existing users or account state.
        error = exception.statusCode == 401
            ? const ApiException(
                statusCode: 401,
                message:
                    'Usuario o contraseña incorrectos, o cuenta no disponible.',
              )
            : exception;
        session = null;
        user = null;
        _setStatus(AuthStatus.signedOut, clearError: false);
      } on Object {
        if (!_current(generation)) return;
        // A secure write may throw after partially persisting the token.
        await _clearStorage();
        if (!_current(generation)) return;
        error = const ApiException(message: 'No se pudo completar el ingreso.');
        session = null;
        user = null;
        _setStatus(AuthStatus.signedOut, clearError: false);
      }
    });
  }

  Future<void> changeCredentials({
    required String currentPassword,
    required String username,
    required String newPassword,
  }) {
    final old = session;
    if (_credentialChangeInFlight ||
        old == null ||
        status != AuthStatus.needsCredentialChange) {
      return Future<void>.value();
    }
    // Disable the form and reserve the generation synchronously. This drops
    // duplicate taps before either request can enter the serialized queue.
    _credentialChangeInFlight = true;
    final generation = ++_generation;
    _setStatus(AuthStatus.changingCredentials, clearError: true);
    return _enqueue(() async {
      try {
        if (!_current(generation) || session != old) return;
        final next = await repository.changeCredentials(
          currentPassword: currentPassword,
          username: username.trim(),
          newPassword: newPassword,
        );
        if (!_current(generation)) return;
        // A credential rotation must return a fresh operational conductor
        // session. Never let a temporary or malformed response sign in.
        if (!_validConductor(next.user) ||
            next.user.debeCambiarCredenciales ||
            next.isExpired(_clock())) {
          await _clearStorage();
          await _invalidateMemory(generation);
          return;
        }
        await _clearStorage();
        if (!_current(generation)) return;
        try {
          await _writeStorage(next);
        } on Object {
          await _clearStorage();
          await _invalidateMemory(generation);
          return;
        }
        if (!_current(generation)) return;
        session = next;
        user = next.user;
        _armExpiry(next);
        _setStatus(AuthStatus.signedIn);
      } on ApiException catch (exception) {
        if (!_current(generation)) return;
        final statusCode = exception.statusCode;
        if (statusCode == null ||
            statusCode >= 500 ||
            exception.isNetwork ||
            exception.isTimeout) {
          await _clearStorage();
          await _invalidateMemory(generation);
        } else {
          error = exception;
          _setStatus(AuthStatus.needsCredentialChange, clearError: false);
        }
      } on Object {
        if (!_current(generation)) return;
        await _clearStorage();
        await _invalidateMemory(generation);
      } finally {
        _credentialChangeInFlight = false;
      }
    });
  }

  Future<void> logout() {
    final generation = ++_generation;
    _cancelExpiry();
    _setStatus(AuthStatus.signingOut, clearError: true);
    lastWarning = null;
    return _enqueue(() async {
      final captured = session;
      if (captured != null) {
        try {
          await repository.logout();
        } on Object {
          lastWarning = 'Se cerró la sesión local. No se pudo confirmar revocación en servidor; puede seguir válida hasta expirar.';
        }
      }
      await _clearStorage();
      if (!_current(generation)) return;
      await _invalidateMemory(generation);
    });
  }

  void handleUnauthorized(String? usedToken) {
    if (_disposed || usedToken == null || usedToken != session?.accessToken) {
      return;
    }
    final generation = ++_generation;
    _cancelExpiry();
    unawaited(_clearStorage());
    unawaited(_invalidateMemory(generation));
  }

  Future<void> _expire(String token) async {
    if (_disposed || session?.accessToken != token) return;
    final generation = ++_generation;
    _cancelExpiry();
    await _invalidateMemory(generation);
    await _clearStorage();
  }

  Future<void> _invalidateLocal(int generation) async {
    await _clearStorage();
    await _invalidateMemory(generation);
  }

  Future<void> _invalidateMemory(int generation) async {
    if (!_current(generation)) return;
    session = null;
    user = null;
    _setStatus(AuthStatus.signedOut, clearError: false);
  }

  Future<void> _writeStorage(AuthSession value) {
    final next = _storageOperations.then((_) => store.write(value));
    _storageOperations = next.catchError((_) {});
    return next;
  }

  Future<AuthSession?> _readStorage() {
    final next = _storageOperations.then((_) => store.read());
    _storageOperations = next.then<void>((_) {}).catchError((_) {});
    return next;
  }

  Future<void> _clearStorage() async {
    final next = _storageOperations.then((_) => store.clear());
    _storageOperations = next.catchError((_) {});
    try {
      await next;
    } on Object {
      lastWarning ??= 'No se pudo limpiar la sesión segura del dispositivo.';
    }
  }

  Future<void> _enqueue(Future<void> Function() task) {
    final next = _operations.then((_) => task());
    _operations = next.catchError((_) {});
    return next;
  }

  void _armExpiry(AuthSession value) {
    _cancelExpiry();
    final duration = value.expiresAt.toUtc().difference(_clock().toUtc());
    _expiryTimer = Timer(
      duration.isNegative ? Duration.zero : duration,
      () => _expire(value.accessToken),
    );
  }

  void _cancelExpiry() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  static bool _validConductor(AuthUser? value) =>
      value != null &&
      value.activo &&
      value.isConductor &&
      (value.repartidorId?.trim().isNotEmpty ?? false);

  void _setStatus(AuthStatus value, {bool clearError = true}) {
    status = value;
    if (clearError) error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelExpiry();
    super.dispose();
  }
}
