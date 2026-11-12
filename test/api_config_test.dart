import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/config/api_config.dart';

void main() {
  test('A server LAN IP and port are shared across Android and web', () {
    for (final isWeb in [true, false]) {
      expect(
        ApiConfig.resolve(
          platform: TargetPlatform.android,
          isWeb: isWeb,
          host: '192.168.100.38',
          port: 5050,
        ),
        'http://192.168.100.38:5050/api',
      );
    }
  });
  test('Android emulator reaches the host rather than its own localhost', () {
    expect(
      ApiConfig.resolve(platform: TargetPlatform.android, isWeb: false),
      'http://10.0.2.2:5289/api',
    );
  });

  test('Web remains on localhost even when its host platform is Android', () {
    expect(
      ApiConfig.resolve(platform: TargetPlatform.android, isWeb: true),
      'http://localhost:5289/api',
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
        ApiConfig.resolve(platform: platform, isWeb: false),
        'http://localhost:5289/api',
      );
    }
  });
}
