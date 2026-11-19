/// Qué día es una ruta respecto a hoy.
enum RouteDay { past, today, future }

/// Lee una fecha `yyyy-MM-dd` (o `yyyy-MM-ddTHH:mm...`) como día de calendario.
/// `null` si no tiene ese formato.
DateTime? _calendarDay(String fecha) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(fecha.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  // DateTime.utc "corrige" fechas imposibles (31 de febrero -> marzo): se
  // descartan.
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

/// Días de calendario entre [fecha] y el día de [now]: negativo si ya pasó,
/// positivo si es futuro. `null` si [fecha] no se entiende.
int? daysFromToday(String fecha, DateTime now) {
  final day = _calendarDay(fecha);
  if (day == null) return null;
  final today = DateTime.utc(now.year, now.month, now.day);
  return day.difference(today).inDays;
}

/// Si la fecha no se entiende devuelve [RouteDay.today]: no se bloquea por un
/// dato raro; la decisión final es del servidor (AGENTS.md, regla 3).
RouteDay routeDayOf(String fecha, DateTime now) {
  final diff = daysFromToday(fecha, now);
  if (diff == null || diff == 0) return RouteDay.today;
  return diff > 0 ? RouteDay.future : RouteDay.past;
}

/// "Hoy", "Mañana" o "Ayer"; `null` para cualquier otro día.
String? relativeDayLabel(String fecha, DateTime now) =>
    switch (daysFromToday(fecha, now)) {
      0 => 'Hoy',
      1 => 'Mañana',
      -1 => 'Ayer',
      _ => null,
    };

/// "de mañana (2026-11-19)", "del 2026-11-25 (en 7 días)", "de ayer
/// (2026-11-17)", "del 2026-11-10 (hace 8 días)".
String _describe(String fecha, int diff) {
  if (diff == 1) return 'de mañana ($fecha)';
  if (diff == -1) return 'de ayer ($fecha)';
  return diff > 0
      ? 'del $fecha (en $diff días)'
      : 'del $fecha (hace ${-diff} días)';
}

/// Por qué una ruta aún no iniciada NO se puede iniciar hoy; `null` si sí se
/// puede (es de hoy, o la fecha no se entiende y decide el servidor).
String? startBlockedReason(String fecha, DateTime now) {
  final diff = daysFromToday(fecha, now);
  if (diff == null || diff == 0) return null;
  final when = _describe(fecha, diff);
  return diff > 0
      ? 'Esta ruta es $when. Podrás iniciarla ese día.'
      : 'Esta ruta era $when y ya no se puede iniciar.';
}
