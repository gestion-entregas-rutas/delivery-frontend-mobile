import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/utils/contact.dart';

void main() {
  group('internationalPhone (Ecuador +593)', () {
    test('cambia el 0 inicial por el código de país', () {
      expect(internationalPhone('0991234567'), '593991234567');
      expect(internationalPhone('099 123 4567'), '593991234567');
      expect(internationalPhone('(099) 123-4567'), '593991234567');
    });

    test('respeta números que ya traen el país', () {
      expect(internationalPhone('+593 99 123 4567'), '593991234567');
      expect(internationalPhone('00593991234567'), '593991234567');
      expect(internationalPhone('593991234567'), '593991234567');
      expect(internationalPhone('+57 300 123 4567'), '573001234567');
    });

    test('número móvil de 9 dígitos sin el 0', () {
      expect(internationalPhone('991234567'), '593991234567');
    });

    test('rechaza vacío, texto o números imposibles', () {
      expect(internationalPhone(null), isNull);
      expect(internationalPhone(''), isNull);
      expect(internationalPhone('   '), isNull);
      expect(internationalPhone('sin teléfono'), isNull);
      expect(internationalPhone('123'), isNull);
      expect(internationalPhone('1234567'), isNull);
      expect(internationalPhone('+1234567890123456'), isNull);
    });

    test('el código de país se puede cambiar', () {
      expect(
        internationalPhone('0991234567', countryCode: '57'),
        '57991234567',
      );
    });
  });

  group('whatsappUri', () {
    test('apunta a wa.me con el número internacional', () {
      final uri = whatsappUri('0991234567')!;
      expect(uri.host, 'wa.me');
      expect(uri.path, '/593991234567');
    });

    test('codifica el mensaje', () {
      final uri = whatsappUri('0991234567', message: 'Hola, ¿estás en casa?')!;
      expect(uri.queryParameters['text'], 'Hola, ¿estás en casa?');
      expect(uri.toString(), isNot(contains(' ')));
    });

    test('sin teléfono válido devuelve null', () {
      expect(whatsappUri(''), isNull);
      expect(whatsappUri('abc'), isNull);
    });
  });

  group('shortTime', () {
    test('quita los segundos', () {
      expect(shortTime('09:00:00'), '09:00');
      expect(shortTime('9:05:30'), '9:05');
      expect(shortTime('14:30'), '14:30');
    });

    test('deja igual lo que no es una hora', () {
      expect(shortTime('mañana'), 'mañana');
    });
  });
}
