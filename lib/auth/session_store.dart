import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_models.dart';

abstract class SessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();

  static const key = 'rutaexpress.auth.session';
  final FlutterSecureStorage storage;

  @override
  Future<AuthSession?> read() async {
    final value = await storage.read(key: key);
    if (value == null || value.trim().isEmpty) return null;
    try {
      return AuthSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) =>
      storage.write(key: key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => storage.delete(key: key);
}

class MemorySessionStore implements SessionStore {
  AuthSession? value;

  @override
  Future<AuthSession?> read() async => value;

  @override
  Future<void> write(AuthSession session) async => value = session;

  @override
  Future<void> clear() async => value = null;
}
