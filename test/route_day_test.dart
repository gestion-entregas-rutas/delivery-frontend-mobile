import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/utils/route_day.dart';

void main() {
  // Miércoles 18 de noviembre de 2026, 15:30.
  final now = DateTime(2026, 11, 18, 15, 30);

  group('routeDayOf', () {
    test('hoy', () {
      expect(routeDayOf('2026-11-18', now), RouteDay.today);
    });

    test('mañana y días futuros son futuro', () {
      expect(routeDayOf('2026-11-19', now), RouteDay.future);
      expect(routeDayOf('2026-12-31', now), RouteDay.future);
      expect(routeDayOf('2027-01-01', now), RouteDay.future);
    });

    test('ayer y días anteriores son pasado', () {
      expect(routeDayOf('2026-11-17', now), RouteDay.past);
      expect(routeDayOf('2025-01-01', now), RouteDay.past);
    });

    test('no depende de la hora del día', () {
      expect(
        routeDayOf('2026-11-18', DateTime(2026, 11, 18, 0, 0, 1)),
        RouteDay.today,
      );
      expect(
        routeDayOf('2026-11-18', DateTime(2026, 11, 18, 23, 59, 59)),
        RouteDay.today,
      );
      // Un segundo después de medianoche, la misma ruta ya es de ayer.
      expect(
        routeDayOf('2026-11-18', DateTime(2026, 11, 19, 0, 0, 1)),
        RouteDay.past,
      );
    });

    test('cruces de mes y de año', () {
      expect(
        routeDayOf('2026-12-01', DateTime(2026, 11, 30, 23, 0)),
        RouteDay.future,
      );
      expect(
        routeDayOf('2027-01-01', DateTime(2026, 12, 31, 23, 0)),
        RouteDay.future,
      );
      expect(
        routeDayOf('2026-12-31', DateTime(2027, 1, 1, 1, 0)),
        RouteDay.past,
      );
      // Año bisiesto: 2028 sí tiene 29 de febrero.
      expect(
        routeDayOf('2028-02-29', DateTime(2028, 2, 28, 12)),
        RouteDay.future,
      );
    });

    test('acepta fecha con hora (ISO completo)', () {
      expect(routeDayOf('2026-11-19T00:00:00', now), RouteDay.future);
      expect(routeDayOf('2026-11-18T23:59:00Z', now), RouteDay.today);
    });

    test('una fecha que no se entiende no bloquea (decide el servidor)', () {
      expect(routeDayOf('', now), RouteDay.today);
      expect(routeDayOf('mañana', now), RouteDay.today);
      expect(routeDayOf('2026-13-45', now), RouteDay.today);
      expect(routeDayOf('2026-02-31', now), RouteDay.today);
    });
  });

  group('daysFromToday', () {
    test('cuenta días de calendario', () {
      expect(daysFromToday('2026-11-18', now), 0);
      expect(daysFromToday('2026-11-19', now), 1);
      expect(daysFromToday('2026-11-17', now), -1);
      expect(daysFromToday('2026-11-25', now), 7);
      expect(daysFromToday('2026-11-08', now), -10);
    });

    test('no se rompe con el cambio de hora (horario de verano)', () {
      final spring = DateTime(2026, 3, 8, 12);
      expect(daysFromToday('2026-03-09', spring), 1);
      expect(daysFromToday('2026-03-15', spring), 7);
    });

    test('null si la fecha no se entiende', () {
      expect(daysFromToday('abc', now), isNull);
    });
  });

  group('relativeDayLabel', () {
    test('Hoy, Mañana y Ayer', () {
      expect(relativeDayLabel('2026-11-18', now), 'Hoy');
      expect(relativeDayLabel('2026-11-19', now), 'Mañana');
      expect(relativeDayLabel('2026-11-17', now), 'Ayer');
    });

    test('otro día no tiene etiqueta', () {
      expect(relativeDayLabel('2026-11-20', now), isNull);
      expect(relativeDayLabel('2026-11-16', now), isNull);
      expect(relativeDayLabel('basura', now), isNull);
    });
  });

  group('startBlockedReason', () {
    test('hoy se puede iniciar', () {
      expect(startBlockedReason('2026-11-18', now), isNull);
    });

    test('mañana: explica y dice cuándo se podrá', () {
      expect(
        startBlockedReason('2026-11-19', now),
        'Esta ruta es de mañana (2026-11-19). Podrás iniciarla ese día.',
      );
    });

    test('un día más lejano dice en cuántos días', () {
      expect(
        startBlockedReason('2026-11-25', now),
        'Esta ruta es del 2026-11-25 (en 7 días). Podrás iniciarla ese día.',
      );
    });

    test('ayer: ya no se puede iniciar', () {
      expect(
        startBlockedReason('2026-11-17', now),
        'Esta ruta era de ayer (2026-11-17) y ya no se puede iniciar.',
      );
    });

    test('hace varios días', () {
      expect(startBlockedReason('2026-11-10', now), contains('hace 8 días'));
    });

    test('una fecha rara no bloquea', () {
      expect(startBlockedReason('???', now), isNull);
    });
  });
}
