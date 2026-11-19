import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/config/api_config.dart';

// Estas pruebas no dependen de a qué servidor apunte la app (`serverIp`,
// `serverPort` y `scheme` cambian entre desarrollo y despliegue): el host y
// el puerto se pasan siempre de forma explícita, y el esquema se toma de
// `ApiConfig.scheme`.
void main() {
  final scheme = ApiConfig.scheme;

  test('A server LAN IP and port are shared across Android and web', () {
    for (final isWeb in [true, false]) {
      expect(
        ApiConfig.resolve(
          platform: TargetPlatform.android,
          isWeb: isWeb,
          host: '192.168.100.38',
          port: 5050,
        ),
        '$scheme://192.168.100.38:5050/api',
      );
    }
  });
  test('Android emulator reaches the host rather than its own localhost', () {
    expect(
      ApiConfig.resolve(
        platform: TargetPlatform.android,
        isWeb: false,
        host: 'localhost',
        port: 5289,
      ),
      '$scheme://10.0.2.2:5289/api',
    );
  });

  test('Web remains on localhost even when its host platform is Android', () {
    expect(
      ApiConfig.resolve(
        platform: TargetPlatform.android,
        isWeb: true,
        host: 'localhost',
        port: 5289,
      ),
      '$scheme://localhost:5289/api',
    );
  });

  test('Explicit deployment or physical-device URL takes precedence', () {
    for (final isWeb in [true, false]) {
      expect(
        ApiConfig.resolve(
          platform: TargetPlatform.android,
          isWeb: isWeb,
          configuredUrl: ' https://delivery.example/api ',
        ),
        'https://delivery.example/api',
      );
    }
  });

  test('Desktop and iOS local defaults are unchanged', () {
    for (final platform in [TargetPlatform.windows, TargetPlatform.iOS]) {
      expect(
        ApiConfig.resolve(
          platform: platform,
          isWeb: false,
          host: 'localhost',
          port: 5289,
        ),
        '$scheme://localhost:5289/api',
      );
    }
  });

  test('Configured LAN IP remains available as an explicit host', () {
    expect(
      ApiConfig.resolve(
        platform: TargetPlatform.android,
        isWeb: false,
        host: '192.168.100.38',
        port: 5289,
      ),
      '$scheme://192.168.100.38:5289/api',
    );
  });

  test('Sin host ni URL, la app apunta al servidor configurado', () {
    final url = ApiConfig.resolve(
      platform: TargetPlatform.android,
      isWeb: false,
    );
    final uri = Uri.parse(url);
    expect(uri.scheme, ApiConfig.scheme);
    expect(uri.host, ApiConfig.serverIp);
    expect(uri.path, '/api');
    // El puerto por defecto del esquema no se escribe (443 en https).
    expect(uri.port, ApiConfig.serverPort);
  });
}
