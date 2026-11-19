/// `850` -> `850 m`, `1234` -> `1,2 km`, `12500` -> `12,5 km`.
String formatDistance(double meters) {
  if (!meters.isFinite || meters < 0) return '—';
  if (meters < 10) return '${meters.round()} m';
  if (meters < 1000) {
    // De 10 en 10 m: más no es creíble con GPS de teléfono.
    return '${(meters / 10).round() * 10} m';
  }
  final km = meters / 1000;
  final text = km.toStringAsFixed(1).replaceAll('.', ',');
  return '${text.endsWith(',0') ? text.substring(0, text.length - 2) : text} km';
}

/// `40` -> `1 min`, `600` -> `10 min`, `4500` -> `1 h 15 min`.
String formatDuration(double seconds) {
  if (!seconds.isFinite || seconds < 0) return '—';
  final minutes = (seconds / 60).ceil().clamp(1, 1 << 30);
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

/// `2` -> `2 kg`, `2.5` -> `2,5 kg`, `0.35` -> `350 g`.
String formatWeight(double kg) {
  if (!kg.isFinite || kg <= 0) return '—';
  if (kg < 1) return '${(kg * 1000).round()} g';
  final text = kg.toStringAsFixed(kg == kg.roundToDouble() ? 0 : 1);
  return '${text.replaceAll('.', ',')} kg';
}
