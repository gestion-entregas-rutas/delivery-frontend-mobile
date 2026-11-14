import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/auth/auth_controller.dart';
import 'package:frontend_mobile/auth/auth_models.dart';
import 'package:frontend_mobile/auth/auth_repository.dart';
import 'package:frontend_mobile/auth/session_store.dart';
import 'package:frontend_mobile/data/api/api_client.dart';
import 'package:frontend_mobile/data/api/api_exception.dart';

AuthSession session({
  String token = 'fake-token',
  bool temporary = false,
  DateTime? expires,
}) => AuthSession(
  accessToken: token,
  expiresAt: expires ?? DateTime.now().add(const Duration(minutes: 30)),
  user: AuthUser(
    id: 'u',
    nombreUsuario: 'driver',
    rol: 'Conductor',
    repartidorId: 'd',
    activo: true,
    debeCambiarCredenciales: temporary,
  ),
);

class Repository extends AuthRepository {
  Repository() : super(ApiClient(baseUrl: 'https://example.test'));
  Future<AuthSession> Function()? pendingLogin;
  AuthSession next = session();
  AuthUser? identity;
  ApiException? meError;
  bool logoutFailed = false;
  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async => pendingLogin != null ? await pendingLogin!() : next;
  @override
  Future<AuthUser> me() async {
    if (meError != null) throw meError!;
    return identity ?? next.user;
  }

  @override
  Future<AuthSession> changeCredentials({
    required String currentPassword,
    required String username,
    required String newPassword,
  }) async => next;
  @override
  Future<void> logout() async {
    if (logoutFailed) {
      throw const ApiException(message: 'offline', isNetwork: true);
    }
  }
}

class FailingStore extends MemorySessionStore {
  bool failWrites = false;
  @override
  Future<void> write(AuthSession session) async {
    if (failWrites) throw StateError('Storage unavailable');
    await super.write(session);
  }
}

class PartialWriteStore extends MemorySessionStore {
  @override
  Future<void> write(AuthSession session) async {
    value = session;
    throw StateError('Write failed after persistence');
  }
}

void main() {
  test('Temporary login gates operational routes and replacement removes obsolete token', () async {
    final repo = Repository()..next = session(temporary: true);
    final store = MemorySessionStore();
    final auth = AuthController(api: repo.api, repository: repo, store: store);
    await auth.login(username: 'driver', password: 'Temporary1!test');
    expect(auth.canUseProtectedOperations, isFalse);
    expect(auth.needsCredentialChange, isTrue);
    repo.next = session(token: 'replacement');
    await auth.changeCredentials(
      currentPassword: 'Temporary1!test',
      username: 'driver',
      newPassword: 'NewPassword2!test',
    );
    expect(auth.accessToken, 'replacement');
    expect(store.value?.accessToken, 'replacement');
    expect(auth.canUseProtectedOperations, isTrue);
    auth.dispose();
    repo.api.close();
  });
  test(
    'Failed storage after credential rotation cannot restore the revoked token',
    () async {
      final repo = Repository()..next = session(temporary: true);
      final store = FailingStore();
      final auth = AuthController(
        api: repo.api,
        repository: repo,
        store: store,
      );
      await auth.login(username: 'driver', password: 'Temporary1!test');
      store.failWrites = true;
      repo.next = session(token: 'replacement');
      await auth.changeCredentials(
        currentPassword: 'Temporary1!test',
        username: 'driver',
        newPassword: 'NewPassword2!test',
      );
      expect(store.value, isNull);
      expect(auth.canUseProtectedOperations, isFalse);
      auth.dispose();
      repo.api.close();
    },
  );
  test('Offline restore retains encrypted token but does not open protected screens', () async {
    final repo = Repository()
      ..meError = const ApiException(message: 'offline', isNetwork: true);
    final store = MemorySessionStore()..value = session();
    final auth = AuthController(api: repo.api, repository: repo, store: store);
    await auth.restore();
    expect(auth.status, AuthStatus.temporarilyUnavailable);
    expect(store.value, isNotNull);
    expect(auth.canUseProtectedOperations, isFalse);
    auth.dispose();
    repo.api.close();
  });
  test(
    'Logout intent prevents a pending successful login from opening Home',
    () async {
      final delayed = Completer<AuthSession>();
      final repo = Repository()..pendingLogin = () => delayed.future;
      final store = MemorySessionStore();
      final auth = AuthController(
        api: repo.api,
        repository: repo,
        store: store,
      );
      var operational = false;
      auth.addListener(() {
        if (auth.isSignedIn) operational = true;
      });
      final login = auth.login(username: 'driver', password: 'test');
      await Future<void>.delayed(Duration.zero);
      final logout = auth.logout();
      delayed.complete(session());
      await login;
      await logout;
      expect(operational, isFalse);
      expect(store.value, isNull);
      auth.dispose();
      repo.api.close();
    },
  );
  test(
    'A 401 for an obsolete token does not remove the current session',
    () async {
      final repo = Repository();
      final store = MemorySessionStore();
      final auth = AuthController(
        api: repo.api,
        repository: repo,
        store: store,
      );
      await auth.login(username: 'driver', password: 'test');
      auth.handleUnauthorized('obsolete');
      expect(auth.isSignedIn, isTrue);
      auth.dispose();
      repo.api.close();
    },
  );
  test(
    'Logout clears local session even when server revocation fails',
    () async {
      final repo = Repository()..logoutFailed = true;
      final store = MemorySessionStore();
      final auth = AuthController(
        api: repo.api,
        repository: repo,
        store: store,
      );
      await auth.login(username: 'driver', password: 'test');
      await auth.logout();
      expect(auth.status, AuthStatus.signedOut);
      expect(store.value, isNull);
      expect(auth.lastWarning, isNotNull);
      auth.dispose();
      repo.api.close();
    },
  );
  testWidgets(
    'Token expiry closes the session without waiting for another request',
    (tester) async {
      var now = DateTime.utc(2026, 10, 17, 12);
      final repo = Repository()
        ..next = session(expires: now.add(const Duration(seconds: 1)));
      final store = MemorySessionStore();
      final auth = AuthController(
        api: repo.api,
        repository: repo,
        store: store,
        clock: () => now,
      );
      await auth.login(username: 'driver', password: 'test');
      expect(auth.isSignedIn, isTrue);
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(auth.accessToken, isNull);
      expect(auth.canUseProtectedOperations, isFalse);
      expect(store.value, isNull);
      auth.dispose();
      repo.api.close();
    },
  );
  test(
    'A changed identity requiring new credentials suspends operational access',
    () async {
      final repo = Repository();
      final store = MemorySessionStore();
      final auth = AuthController(
        api: repo.api,
        repository: repo,
        store: store,
      );
      await auth.login(username: 'driver', password: 'test');
      repo.identity = session(temporary: true).user;
      expect(await auth.validateCurrentSession(), isFalse);
      expect(auth.canUseProtectedOperations, isFalse);
      expect(auth.status, AuthStatus.needsCredentialChange);
      auth.dispose();
      repo.api.close();
    },
  );
  test(
    'A partially failed login write is cleared before reporting failure',
    () async {
      final repo = Repository();
      final store = PartialWriteStore();
      final auth = AuthController(
        api: repo.api,
        repository: repo,
        store: store,
      );
      await auth.login(username: 'driver', password: 'test');
      expect(auth.status, AuthStatus.signedOut);
      expect(store.value, isNull);
      auth.dispose();
      repo.api.close();
    },
  );
  test('An authoritative driver binding change replaces the operational controller', () async {
    final repo = Repository();
    final store = MemorySessionStore();
    final auth = AuthController(api: repo.api, repository: repo, store: store);
    await auth.login(username: 'driver', password: 'test');
    var notifications = 0;
    auth.addListener(() => notifications++);
    repo.identity = const AuthUser(
      id: 'u',
      nombreUsuario: 'driver',
      rol: 'Conductor',
      repartidorId: 'new-driver',
      activo: true,
      debeCambiarCredenciales: false,
    );
    expect(await auth.validateCurrentSession(), isFalse);
    expect(auth.driverId, 'new-driver');
    expect(notifications, greaterThan(0));
    expect(store.value?.user.repartidorId, 'new-driver');
    auth.dispose();
    repo.api.close();
  });
}
