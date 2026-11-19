/// Código de país que se antepone a los teléfonos locales (Ecuador).
/// Cámbialo aquí si la operación pasa a otro país.
const String kDefaultCountryCode = '593';

/// Devuelve el teléfono en formato internacional solo con dígitos, por
/// ejemplo `0991234567` -> `593991234567`. Devuelve `null` si no parece un
/// número válido (así el botón de WhatsApp queda deshabilitado en lugar de
/// escribir a un número equivocado).
///
/// Reglas:
/// - `+593 99 123 4567` y `00593...`: ya traen el país, se respetan.
/// - `099 123 4567`: el 0 inicial se cambia por el código de país.
/// - `99 123 4567` (9 dígitos sin el 0): se antepone el código de país.
String? internationalPhone(
  String? raw, {
  String countryCode = kDefaultCountryCode,
}) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return null;
  final hasPlus = text.startsWith('+');
  var digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;

  if (hasPlus) {
    // Ya viene con país.
  } else if (digits.startsWith('00')) {
    digits = digits.substring(2);
  } else if (digits.startsWith(countryCode) && digits.length >= 11) {
    // Ya empieza con el código de país.
  } else if (digits.startsWith('0')) {
    digits = '$countryCode${digits.substring(1)}';
  } else if (digits.length == 9) {
    digits = '$countryCode$digits';
  } else {
    return null;
  }
  // E.164: entre 8 y 15 dígitos en total.
  if (digits.length < 8 || digits.length > 15) return null;
  return digits;
}

/// Enlace para abrir un chat de WhatsApp con el número, con un mensaje
/// opcional ya escrito. `null` si el teléfono no es válido.
Uri? whatsappUri(String? phone, {String? message}) {
  final number = internationalPhone(phone);
  if (number == null) return null;
  return Uri.https('wa.me', '/$number', {
    if (message != null && message.isNotEmpty) 'text': message,
  });
}

/// `09:00:00` -> `09:00`. Si no tiene el formato esperado, lo deja igual.
String shortTime(String time) {
  final match = RegExp(r'^(\d{1,2}:\d{2})(:\d{2})?').firstMatch(time.trim());
  return match?.group(1) ?? time;
}
