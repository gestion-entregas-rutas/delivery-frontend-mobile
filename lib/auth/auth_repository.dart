import '../data/api/api_client.dart';
import '../data/api/api_exception.dart';
import 'auth_models.dart';

class AuthRepository {
  AuthRepository(this.api);

  final ApiClient api;

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final value = await api.post(
      '/autenticacion/login',
      body: <String, String>{'nombreUsuario': username, 'clave': password},
    );
    return _session(value);
  }

  Future<AuthUser> me() async {
    final value = await api.get('/autenticacion/me');
    final map = authJsonMap(value);
    return AuthUser.fromJson(authJsonMap(map['usuario'] ?? map));
  }

  Future<AuthSession> changeCredentials({
    required String currentPassword,
    required String username,
    required String newPassword,
  }) async {
    final value = await api.put(
      '/autenticacion/credenciales',
      body: <String, String>{
        'claveActual': currentPassword,
        'nuevoNombreUsuario': username,
        'nuevaClave': newPassword,
      },
    );
    return _session(value);
  }

  Future<void> logout() async {
    await api.post('/autenticacion/logout');
  }

  static AuthSession _session(dynamic value) {
    final map = authJsonMap(value);
    if (map['accessToken'] == null) {
      throw const ApiException(
        message: 'La respuesta de autenticación no contiene un token.',
      );
    }
    return AuthSession.fromJson(map);
  }
}
