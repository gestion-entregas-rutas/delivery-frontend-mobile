import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/screens/login_screen.dart';
import 'package:frontend_mobile/theme/app_theme.dart';
import 'package:frontend_mobile/widgets/primary_button.dart';

import 'route_screen_test.dart' as h;

void setTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  group('semántica', () {
    testWidgets('cada nodo se lee como "Parada N, estado"', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await h.pumpHome(
        tester,
        h.route('EnCurso', [
          h.stop(1, 'Entregado'),
          h.stop(2, 'EnCamino'),
          h.stop(3, 'AsignadoARuta'),
        ]),
      );
      expect(find.bySemanticsLabel('Parada 1, entregada'), findsOneWidget);
      expect(find.bySemanticsLabel('Parada 2, actual'), findsOneWidget);
      expect(find.bySemanticsLabel('Parada 3, pendiente'), findsOneWidget);
      await h.teardown(tester, c);
      handle.dispose();
    });

    testWidgets('el progreso y la fecha tienen etiqueta propia', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final c = await h.pumpHome(
        tester,
        h.route('EnCurso', [h.stop(1, 'Entregado'), h.stop(2, 'EnCamino')]),
      );
      expect(
        find.bySemanticsLabel('1 de 2 entregas completadas'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Cambiar fecha. Fecha actual: ')),
        findsOneWidget,
      );
      await h.teardown(tester, c);
      handle.dispose();
    });

    testWidgets('el botón en proceso lo anuncia', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PrimaryButton(
              label: 'Confirmar entrega',
              loading: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Confirmar entrega, en proceso'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });
  });

  group('texto grande', () {
    for (final scale in const [1.3, 1.6, 2.0]) {
      testWidgets('la ruta no desborda con texto x$scale en 360 px', (
        tester,
      ) async {
        setTextScale(tester, scale);
        final c = await h.pumpHome(
          tester,
          h.route('EnCurso', [
            h.stop(1, 'Entregado'),
            h.stop(
              2,
              'EnCamino',
              nombre: 'Fyodor Mikhailovich Dostoevsky',
              direccion: '5/2, Kuznechny Lane, Saint Petersburg',
              detalles: '2 × Vela perfumada, 1 × Jabón artesanal',
            ),
            h.stop(3, 'AsignadoARuta'),
          ]),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await h.teardown(tester, c);
      });

      testWidgets('el login no desborda con texto x$scale en 360 px', (
        tester,
      ) async {
        setTextScale(tester, scale);
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
