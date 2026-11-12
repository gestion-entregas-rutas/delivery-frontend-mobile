class AuthUser {
  const AuthUser({
    required this.id,
    required this.nombreUsuario,
    required this.rol,
    required this.repartidorId,
    required this.activo,
    required this.debeCambiarCredenciales,
  });

  final String id;
  final String nombreUsuario;
  final String rol;
  final String? repartidorId;
  final bool activo;
  final bool debeCambiarCredenciales;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final username = json['nombreUsuario'];
    final role = json['rol'];
    final active = json['activo'];
    final mustChange = json['debeCambiarCredenciales'];
    if (id is! String ||
        id.trim().isEmpty ||
        username is! String ||
        username.trim().isEmpty ||
        role is! String ||
        role.trim().isEmpty ||
        active is! bool ||
        mustChange is! bool) {
      throw const FormatException('Perfil de usuario inválido');
    }
    final driver = json['repartidorId'];
    if (driver != null && driver is! String) {
      throw const FormatException('Vínculo de repartidor inválido');
    }
    return AuthUser(
      id: id.trim(),
      nombreUsuario: username.trim(),
      rol: role.trim(),
      repartidorId: driver?.trim(),
      activo: active,
      debeCambiarCredenciales: mustChange,
    );
  }

  bool get isConductor => rol.toLowerCase() == 'conductor';
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.expiresAt,
    required this.user,
    this.tokenType = 'Bearer',
  });

  final String accessToken;
  final DateTime expiresAt;
  final AuthUser user;
  final String tokenType;

  bool isExpired(DateTime now) => !expiresAt.toUtc().isAfter(now.toUtc());

  Map<String, dynamic> toJson() => <String, dynamic>{
    'accessToken': accessToken,
    'expiraEn': expiresAt.toUtc().toIso8601String(),
    'tokenType': tokenType,
    'usuario': <String, dynamic>{
      'id': user.id,
      'nombreUsuario': user.nombreUsuario,
      'rol': user.rol,
      'repartidorId': user.repartidorId,
      'activo': user.activo,
      'debeCambiarCredenciales': user.debeCambiarCredenciales,
    },
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final rawUser = json['usuario'] ?? json['user'];
    final expires = DateTime.tryParse(json['expiraEn']?.toString() ?? '');
    if (json['accessToken'] is! String ||
        (json['accessToken'] as String).trim().isEmpty ||
        expires == null ||
        rawUser is! Map) {
      throw const FormatException('Sesión almacenada inválida');
    }
    final tokenType = json['tokenType'];
    if (tokenType != null && tokenType.toString().toLowerCase() != 'bearer') {
      throw const FormatException('Tipo de token no soportado');
    }
    return AuthSession(
      accessToken: (json['accessToken'] as String).trim(),
      expiresAt: expires.toUtc(),
      tokenType: 'Bearer',
      user: AuthUser.fromJson(Map<String, dynamic>.from(rawUser)),
    );
  }

  AuthSession copyWith({AuthUser? user}) => AuthSession(
    accessToken: accessToken,
    expiresAt: expiresAt,
    tokenType: tokenType,
    user: user ?? this.user,
  );
}

Map<String, dynamic> authJsonMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
