import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/settings/device_settings.dart';
import 'package:geolocator/geolocator.dart';

import 'route_screen_test.dart' as h;

Future<h.FakeSettingsGateway> openProfile(
  WidgetTester tester, {
  void Function(h.FakeSettingsGateway)? configure,
  Size size = const Size(390, 900),
}) async {
  final gateway = h.FakeSettingsGateway();
  configure?.call(gateway);
  final c = await h.pumpHome(
    tester,
    h.route('EnCurso', [h.stop(1, 'EnCamino')]),
    settings: gateway,
    size: size,
  );
  addTearDown(() async {
    await h.teardown(tester, c);
  });
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
  return gateway;
}

/// Pulsa un botón de la configuración (puede estar fuera de la vista).
Future<void> pressButton(
  WidgetTester tester,
  String label, {
  int index = 0,
}) async {
  final finder = find.widgetWithText(FilledButton, label).at(index);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('todo activado', () {
    testWidgets('muestra los tres ajustes y ningún botón', (tester) async {
      await openProfile(tester);
      expect(find.text('Configuración'), findsOneWidget);
      expect(find.text('Ubicación (GPS)'), findsOneWidget);
      expect(find.text('Ubicación precisa'), findsOneWidget);
      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('Activada'), findsNWidgets(2)); // GPS y precisa
      expect(find.text('Activadas'), findsOneWidget); // notificaciones
      expect(find.widgetWithText(FilledButton, 'Activar'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Permitir'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Ajustes'), findsNothing);
    });

    testWidgets('aclara cuándo se comparte la ubicación', (tester) async {
      await openProfile(tester);
      expect(
        find.text(
          'Tu ubicación solo se comparte con la central mientras tu ruta está en curso.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('cada ajuste se anuncia con su estado', (tester) async {
      final handle = tester.ensureSemantics();
      await openProfile(tester);
      expect(
        find.bySemanticsLabel('Ubicación (GPS): Activada'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Ubicación precisa: Activada'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Notificaciones: Activadas'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('ubicación (GPS)', () {
    testWidgets('apagada en el teléfono: Activar abre sus ajustes', (
      tester,
    ) async {
      final gateway = await openProfile(
        tester,
        configure: (g) => g.serviceOn = false,
      );
      expect(find.text('Apagada en el teléfono'), findsOneWidget);
      await pressButton(tester, 'Activar');
      expect(gateway.locationSettingsOpened, 1);
    });

    testWidgets('sin permiso: Permitir lo pide y se actualiza solo', (
      tester,
    ) async {
      final gateway = await openProfile(
        tester,
        configure: (g) {
          g.permission = LocationPermission.denied;
          g.precision = LocationPrecision.unknown;
        },
      );
      expect(find.text('Sin permiso'), findsOneWidget);
      await pressButton(tester, 'Permitir');
      expect(gateway.locationRequests, 1);
      expect(find.text('Sin permiso'), findsNothing);
      expect(find.text('Activada'), findsNWidgets(2));
    });

    testWidgets('bloqueada: Ajustes abre los ajustes de la app', (
      tester,
    ) async {
      final gateway = await openProfile(
        tester,
        configure: (g) => g.permission = LocationPermission.deniedForever,
      );
      expect(find.text('Bloqueada para la app'), findsOneWidget);
      await pressButton(tester, 'Ajustes');
      expect(gateway.appSettingsOpened, 1);
    });
  });

  group('ubicación precisa', () {
    testWidgets('aproximada: Activar la vuelve precisa', (tester) async {
      final gateway = await openProfile(
        tester,
        configure: (g) {
          g.precision = LocationPrecision.approximate;
          g.precisionAfterRequest = LocationPrecision.precise;
        },
      );
      expect(find.text('Aproximada'), findsOneWidget);
      await pressButton(tester, 'Activar');
      expect(find.text('Aproximada'), findsNothing);
      expect(find.text('Activada'), findsNWidgets(2));
      expect(gateway.appSettingsOpened, 0);
    });

    testWidgets('si el sistema no la da, lleva a los ajustes de la app', (
      tester,
    ) async {
      final gateway = await openProfile(
        tester,
        configure: (g) {
          g.precision = LocationPrecision.approximate;
          g.precisionAfterRequest = LocationPrecision.approximate;
        },
      );
      await pressButton(tester, 'Activar');
      expect(gateway.appSettingsOpened, 1);
      expect(find.text('Aproximada'), findsOneWidget);
    });

    testWidgets('sin permiso de ubicación lo dice y ofrece Permitir', (
      tester,
    ) async {
      await openProfile(
        tester,
        configure: (g) {
          g.permission = LocationPermission.denied;
          g.precision = LocationPrecision.unknown;
        },
      );
      expect(find.text('Requiere el permiso de ubicación'), findsOneWidget);
      // Hay dos "Permitir": el del GPS y el de la precisión.
      expect(find.widgetWithText(FilledButton, 'Permitir'), findsNWidgets(2));
    });

    testWidgets('en un teléfono sin dato de precisión no inventa un botón', (
      tester,
    ) async {
      await openProfile(
        tester,
        configure: (g) => g.precision = LocationPrecision.unknown,
      );
      expect(find.text('No disponible en este teléfono'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Activar'), findsNothing);
    });
  });

  group('notificaciones', () {
    testWidgets('desactivadas: Activar las pide y queda activado', (
      tester,
    ) async {
      final gateway = await openProfile(
        tester,
        configure: (g) {
          g.notificationsState = NotificationsState.denied;
          g.notificationsAfterRequest = NotificationsState.granted;
        },
      );
      expect(find.text('Desactivadas'), findsOneWidget);
      await pressButton(tester, 'Activar');
      expect(gateway.notificationRequests, 1);
      expect(find.text('Desactivadas'), findsNothing);
      expect(find.text('Activadas'), findsOneWidget);
    });

    testWidgets('si las rechaza para siempre, abre los ajustes', (
      tester,
    ) async {
      final gateway = await openProfile(
        tester,
        configure: (g) {
          g.notificationsState = NotificationsState.denied;
          g.notificationsAfterRequest = NotificationsState.blocked;
        },
      );
      await pressButton(tester, 'Activar');
      expect(gateway.appSettingsOpened, 1);
      expect(find.text('Bloqueadas para la app'), findsOneWidget);
    });

    testWidgets('bloqueadas: Ajustes no vuelve a preguntar', (tester) async {
      final gateway = await openProfile(
        tester,
        configure: (g) => g.notificationsState = NotificationsState.blocked,
      );
      await pressButton(tester, 'Ajustes');
      expect(gateway.notificationRequests, 0);
      expect(gateway.appSettingsOpened, 1);
    });
  });

  group('al volver de los ajustes del teléfono', () {
    testWidgets('Perfil se actualiza solo', (tester) async {
      final gateway = await openProfile(
        tester,
        configure: (g) => g.notificationsState = NotificationsState.denied,
      );
      expect(find.text('Desactivadas'), findsOneWidget);
      // El usuario las activa en los ajustes de Android y vuelve a la app.
      gateway.notificationsState = NotificationsState.granted;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Desactivadas'), findsNothing);
      expect(find.text('Activadas'), findsOneWidget);
    });
  });

  group('pantallas pequeñas y letra grande', () {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('con todo por arreglar no desborda (letra x$scale, 320 px)', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openProfile(
          tester,
          size: const Size(320, 640),
          configure: (g) {
            g.serviceOn = false;
            g.permission = LocationPermission.denied;
            g.precision = LocationPrecision.approximate;
            g.notificationsState = NotificationsState.denied;
          },
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('el botón sigue al alcance al desplazar', (tester) async {
      await openProfile(
        tester,
        size: const Size(320, 480),
        configure: (g) => g.notificationsState = NotificationsState.denied,
      );
      final button = find.widgetWithText(FilledButton, 'Activar');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(button, findsOneWidget);
    });
  });
}
