import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String serverIp = '192.168.100.38';
  static const int serverPort = 5289;
  static const String scheme = 'http';

  static String get baseUrl =>
      resolve(platform: defaultTargetPlatform, isWeb: kIsWeb);

  static String resolve({
    required TargetPlatform platform,
    required bool isWeb,
    String configuredUrl = '',
    String host = serverIp,
    int port = serverPort,
  }) {
    if (configuredUrl.trim().isNotEmpty) return configuredUrl.trim();
    final resolvedHost =
        !isWeb &&
            platform == TargetPlatform.android &&
            (host == 'localhost' || host == '127.0.0.1')
        ? '10.0.2.2'
        : host;
    return Uri(
      scheme: scheme,
      host: resolvedHost,
      port: port,
      path: '/api',
    ).toString();
  }
}
