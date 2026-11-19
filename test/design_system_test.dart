import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/theme/app_colors.dart';
import 'package:frontend_mobile/theme/app_theme.dart';
import 'package:frontend_mobile/widgets/primary_button.dart';
import 'package:frontend_mobile/widgets/route_node_tile.dart';
import 'package:frontend_mobile/widgets/status_chip.dart';

Widget _host(Widget child, {double width = 360}) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  group('AppTheme', () {
    test('usa el morado de marca como color primario', () {
      final theme = AppTheme.light();
      expect(theme.colorScheme.primary, AppColors.brand);
      expect(theme.colorScheme.onPrimary, Colors.white);
      expect(theme.scaffoldBackgroundColor, AppColors.paper);
    });

    test('los controles táctiles miden al menos 48', () {
      final theme = AppTheme.light();
      expect(
        theme.outlinedButtonTheme.style!.minimumSize!.resolve({})!.height,
        greaterThanOrEqualTo(AppTheme.minTouchTarget),
      );
      expect(
        theme.textButtonTheme.style!.minimumSize!.resolve({})!.height,
        greaterThanOrEqualTo(AppTheme.minTouchTarget),
      );
      expect(
        theme.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
        greaterThanOrEqualTo(AppTheme.minTouchTarget),
      );
    });
  });

  group('PrimaryButton', () {
    testWidgets('llama a onPressed al tocarlo', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PrimaryButton(label: 'Confirmar entrega', onPressed: () => taps++),
        ),
      );
      await tester.tap(find.text('Confirmar entrega'));
      expect(taps, 1);
    });

    testWidgets('con loading se bloquea y no permite doble toque', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PrimaryButton(
            label: 'Confirmar entrega',
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Confirmar entrega'), findsNothing);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('sin onPressed queda deshabilitado', (tester) async {
      await tester.pumpWidget(
        _host(const PrimaryButton(label: 'Sin paradas', onPressed: null)),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
        isFalse,
      );
    });

    testWidgets('no desborda en 320 px con texto largo', (tester) async {
      await tester.pumpWidget(
        _host(
          PrimaryButton(
            label: 'Confirmar entrega de todos los paquetes',
            icon: Icons.check_circle_outline,
            onPressed: () {},
          ),
          width: 280,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('StatusChip', () {
    testWidgets('muestra texto e icono del estado', (tester) async {
      await tester.pumpWidget(
        _host(const StatusChip(status: AppStatus.done, label: 'Entregada')),
      );
      expect(find.text('Entregada'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    test('cada estado tiene un color distinto', () {
      final colors = AppStatus.values.map((s) => s.color).toSet();
      expect(colors.length, AppStatus.values.length);
    });
  });

  group('RouteNodeTile', () {
    testWidgets('entregada muestra check y no el número', (tester) async {
      await tester.pumpWidget(
        _host(
          const RouteNodeTile(
            status: AppStatus.done,
            number: 1,
            isFirst: true,
            child: Text('Tove Jansson'),
          ),
        ),
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(find.text('Tove Jansson'), findsOneWidget);
    });

    testWidgets('actual y pendiente muestran su número', (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              RouteNodeTile(
                status: AppStatus.active,
                number: 3,
                child: Text('Parada actual'),
              ),
              RouteNodeTile(
                status: AppStatus.pending,
                number: 4,
                isLast: true,
                child: Text('Siguiente'),
              ),
            ],
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('una lista de paradas no desborda en 320 px', (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              RouteNodeTile(
                status: AppStatus.done,
                number: 1,
                isFirst: true,
                child: Text(
                  'Entregada con un nombre bastante largo de cliente',
                ),
              ),
              RouteNodeTile(
                status: AppStatus.active,
                number: 2,
                child: Text('Calle 12 #4-30, barrio con nombre largo, ciudad'),
              ),
              RouteNodeTile(
                status: AppStatus.pending,
                number: 3,
                isLast: true,
                child: Text('Pendiente'),
              ),
            ],
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
