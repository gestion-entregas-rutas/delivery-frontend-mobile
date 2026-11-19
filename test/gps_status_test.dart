import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/location/gps_service.dart';
import 'package:frontend_mobile/theme/app_theme.dart';
import 'package:frontend_mobile/widgets/route/gps_status.dart';

Widget host(
  GpsState state, {
  VoidCallback? onEnable,
  VoidCallback? onSettings,
}) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: GpsStatus(
      state: state,
      onEnable: onEnable,
      onOpenSettings: onSettings,
    ),
  ),
);

void main() {
  // (estado, texto que se ve, botón que ofrece o null)
  final cases = <(GpsState, String, String?)>[
    (GpsState.stopped, 'Ubicación apagada', 'Activar'),
    (GpsState.serviceDisabled, 'Enciende la ubicación del teléfono', 'Ajustes'),
    (
      GpsState.permissionDenied,
      'Permite la ubicación para ver tu posición',
      'Permitir',
    ),
    (
      GpsState.permissionDeniedForever,
      'Permiso bloqueado: actívalo en Ajustes',
      'Ajustes',
    ),
    (
      GpsState.accuracyInsufficient,
      'Señal débil: sal a un lugar abierto',
      'Reintentar',
    ),
    (GpsState.unavailable, 'No se pudo obtener la ubicación', 'Reintentar'),
    (GpsState.waitingForSample, 'Buscando tu ubicación…', null),
    (GpsState.checking, 'Buscando tu ubicación…', null),
    (GpsState.active, 'Ubicación activa', null),
  ];

  for (final (state, text, button) in cases) {
    testWidgets(
      '$state: dice "$text" y ${button == null ? 'no ofrece botón' : 'ofrece $button'}',
      (tester) async {
        await tester.pumpWidget(
          host(state, onEnable: () {}, onSettings: () {}),
        );
        expect(find.text(text), findsOneWidget);
        if (button == null) {
          expect(find.byType(TextButton), findsNothing);
        } else {
          expect(find.widgetWithText(TextButton, button), findsOneWidget);
        }
      },
    );
  }

  testWidgets('cada botón llama a la acción correcta', (tester) async {
    var enable = 0;
    var settings = 0;
    for (final (state, _, button) in cases.where((c) => c.$3 != null)) {
      await tester.pumpWidget(
        host(state, onEnable: () => enable++, onSettings: () => settings++),
      );
      await tester.tap(find.widgetWithText(TextButton, button!));
    }
    // Activar, Permitir, Reintentar x2 -> encender; Ajustes x2 -> ajustes.
    expect(enable, 4);
    expect(settings, 2);
  });

  testWidgets('sin acciones no muestra botones que no hacen nada', (
    tester,
  ) async {
    await tester.pumpWidget(host(GpsState.stopped));
    expect(find.byType(TextButton), findsNothing);
    await tester.pumpWidget(host(GpsState.serviceDisabled));
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('mientras busca muestra un indicador de progreso', (
    tester,
  ) async {
    await tester.pumpWidget(host(GpsState.waitingForSample));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(host(GpsState.active));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no desborda con texto grande y en 280 px', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(280, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (state, _, _) in cases) {
      await tester.pumpWidget(host(state, onEnable: () {}, onSettings: () {}));
      expect(tester.takeException(), isNull, reason: '$state');
    }
  });
}
