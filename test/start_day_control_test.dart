import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/models/logistica_models.dart';
import 'package:frontend_mobile/state/driver_controller.dart';
import 'package:frontend_mobile/widgets/primary_button.dart';

import 'route_screen_test.dart' as h;

/// Rutas de ejemplo: todas son del 2026-10-17.
RutaDto planned() => h.route('Planificada', [h.stop(1, 'AsignadoARuta')]);

DriverController controllerFor(
  h.FakeRepo repo,
  DateTime Function() clock, {
  h.FakeGps? gps,
}) => DriverController(
  repository: repo,
  driverId: 'd',
  seguimiento: h.FakeRealtime(),
  gps: gps ?? h.FakeGps(),
  initialDate: DateTime(2026, 10, 17),
  clock: clock,
);

void main() {
  group('control en el controlador: no iniciar rutas de otro día', () {
    test('una ruta de mañana NO se inicia: ni servidor ni GPS', () async {
      final repo = h.FakeRepo(planned());
      final gps = h.FakeGps();
      final c = controllerFor(repo, () => DateTime(2026, 10, 16, 20), gps: gps);
      addTearDown(c.dispose);
      await c.refresh();
      await c.startRoute();
      expect(repo.startRequests, 0, reason: 'no debe llamar al servidor');
      expect(gps.starts, 0, reason: 'no debe encender el GPS');
      expect(c.route?.estado, 'Planificada');
      expect(
        c.error?.message,
        'Esta ruta es de mañana (2026-10-17). Podrás iniciarla ese día.',
      );
      expect(c.isBusy, isFalse, reason: 'el botón no queda bloqueado');
    });

    test('una ruta de ayer NO se inicia', () async {
      final repo = h.FakeRepo(planned());
      final c = controllerFor(repo, () => DateTime(2026, 10, 18, 8));
      addTearDown(c.dispose);
      await c.refresh();
      await c.startRoute();
      expect(repo.startRequests, 0);
      expect(c.route?.estado, 'Planificada');
      expect(
        c.error?.message,
        'Esta ruta era de ayer (2026-10-17) y ya no se puede iniciar.',
      );
    });

    test('una de hace varios días tampoco', () async {
      final repo = h.FakeRepo(planned());
      final c = controllerFor(repo, () => DateTime(2026, 10, 25));
      addTearDown(c.dispose);
      await c.refresh();
      await c.startRoute();
      expect(repo.startRequests, 0);
      expect(c.error?.message, contains('hace 8 días'));
    });

    test('la de hoy sí se inicia', () async {
      final repo = h.FakeRepo(planned());
      final c = controllerFor(repo, () => DateTime(2026, 10, 17, 9));
      addTearDown(c.dispose);
      await c.refresh();
      await c.startRoute();
      expect(repo.startRequests, 1);
      expect(c.route?.estado, 'EnCurso');
      expect(c.error, isNull);
    });

    test('hoy a las 00:00 y a las 23:59 sí; un minuto después ya no', () async {
      var now = DateTime(2026, 10, 17, 0, 0);
      final repo = h.FakeRepo(planned());
      final c = controllerFor(repo, () => now);
      addTearDown(c.dispose);
      await c.refresh();
      expect(c.startBlockedReason, isNull);
      now = DateTime(2026, 10, 17, 23, 59, 59);
      expect(c.startBlockedReason, isNull);
      // Pasó la medianoche con la app abierta: la ruta ya es de ayer.
      now = DateTime(2026, 10, 18, 0, 0, 1);
      expect(c.startBlockedReason, isNotNull);
      await c.startRoute();
      expect(repo.startRequests, 0);
    });

    test('se puede volver a intentar al llegar el día', () async {
      var now = DateTime(2026, 10, 16, 22);
      final repo = h.FakeRepo(planned());
      final c = controllerFor(repo, () => now);
      addTearDown(c.dispose);
      await c.refresh();
      await c.startRoute();
      expect(repo.startRequests, 0);
      // Amanece el 17: ahora sí.
      now = DateTime(2026, 10, 17, 6);
      await c.startRoute();
      expect(repo.startRequests, 1);
      expect(c.route?.estado, 'EnCurso');
    });
  });

  group('startBlockedReason', () {
    test('sin ruta no hay motivo', () {
      final c = controllerFor(h.FakeRepo(null), () => DateTime(2026, 10, 1));
      addTearDown(c.dispose);
      expect(c.startBlockedReason, isNull);
    });

    test(
      'una ruta ya en curso de otro día NO se bloquea (no deja varado)',
      () async {
        // Empezó ayer y sigue abierta: el repartidor debe poder terminarla.
        final repo = h.FakeRepo(h.route('EnCurso', [h.stop(1, 'EnCamino')]));
        final c = controllerFor(repo, () => DateTime(2026, 10, 18, 1));
        addTearDown(c.dispose);
        await c.refresh();
        expect(c.startBlockedReason, isNull);
      },
    );

    test('una ruta completada tampoco tiene motivo', () async {
      final repo = h.FakeRepo(h.route('Completada', [h.stop(1, 'Entregado')]));
      final c = controllerFor(repo, () => DateTime(2026, 11, 30));
      addTearDown(c.dispose);
      await c.refresh();
      expect(c.startBlockedReason, isNull);
    });

    test('mañana: da el motivo', () async {
      final c = controllerFor(
        h.FakeRepo(planned()),
        () => DateTime(2026, 10, 16),
      );
      addTearDown(c.dispose);
      await c.refresh();
      expect(c.startBlockedReason, contains('de mañana'));
    });
  });

  group('en la pantalla', () {
    PrimaryButton button(WidgetTester tester) =>
        tester.widget<PrimaryButton>(find.byType(PrimaryButton));

    Future<DriverController> open(
      WidgetTester tester,
      DateTime today, {
      String estado = 'Planificada',
    }) => h.pumpHome(
      tester,
      h.route(estado, [
        h.stop(1, estado == 'EnCurso' ? 'EnCamino' : 'AsignadoARuta'),
      ]),
      today: today,
    );

    testWidgets('hoy: sin aviso y el botón está activo', (tester) async {
      final c = await open(tester, DateTime(2026, 10, 17, 9));
      expect(find.textContaining('Podrás iniciarla'), findsNothing);
      expect(find.textContaining('ya no se puede iniciar'), findsNothing);
      expect(find.text('Hoy · 2026-10-17'), findsOneWidget);
      expect(button(tester).label, 'Iniciar ruta');
      expect(button(tester).onPressed, isNotNull);
      await h.teardown(tester, c);
    });

    testWidgets('mañana: avisa, etiqueta la fecha y apaga el botón', (
      tester,
    ) async {
      final c = await open(tester, DateTime(2026, 10, 16, 9));
      expect(
        find.text(
          'Esta ruta es de mañana (2026-10-17). Podrás iniciarla ese día.',
        ),
        findsOneWidget,
      );
      expect(find.text('Mañana · 2026-10-17'), findsOneWidget);
      expect(button(tester).label, 'Iniciar ruta');
      expect(button(tester).onPressed, isNull);
      await h.teardown(tester, c);
    });

    testWidgets('tocar el botón apagado no abre nada ni llama al servidor', (
      tester,
    ) async {
      final c = await open(tester, DateTime(2026, 10, 16, 9));
      await tester.tap(find.text('Iniciar ruta'), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      await h.teardown(tester, c);
    });

    testWidgets('ayer: dice que ya no se puede iniciar', (tester) async {
      final c = await open(tester, DateTime(2026, 10, 18, 9));
      expect(
        find.text(
          'Esta ruta era de ayer (2026-10-17) y ya no se puede iniciar.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ayer · 2026-10-17'), findsOneWidget);
      expect(button(tester).onPressed, isNull);
      await h.teardown(tester, c);
    });

    testWidgets('otro día: solo la fecha, sin Hoy/Mañana/Ayer', (tester) async {
      final c = await open(tester, DateTime(2026, 10, 10, 9));
      expect(find.text('2026-10-17'), findsOneWidget);
      expect(find.textContaining('Mañana'), findsNothing);
      expect(find.textContaining('Hoy'), findsNothing);
      expect(button(tester).onPressed, isNull);
      await h.teardown(tester, c);
    });

    testWidgets('"Ir a hoy" cambia a la fecha de hoy', (tester) async {
      final c = await open(tester, DateTime(2026, 10, 16, 9));
      expect(c.selectedDate, '2026-10-17');
      await tester.tap(find.text('Ir a hoy'));
      await tester.pump();
      await tester.pump();
      expect(c.selectedDate, '2026-10-16');
      await h.teardown(tester, c);
    });

    testWidgets('una ruta en curso de ayer sigue operable', (tester) async {
      final c = await open(
        tester,
        DateTime(2026, 10, 18, 1),
        estado: 'EnCurso',
      );
      expect(find.textContaining('ya no se puede iniciar'), findsNothing);
      // Con la parada en camino la acción es confirmar la entrega.
      expect(button(tester).label, 'Confirmar entrega');
      expect(button(tester).onPressed, isNotNull);
      await h.teardown(tester, c);
    });

    testWidgets('el aviso no desborda con letra grande en 320 px', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final c = await h.pumpHome(
        tester,
        planned(),
        today: DateTime(2026, 10, 16),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      await h.teardown(tester, c);
    });
  });
}
