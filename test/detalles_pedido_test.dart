import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/models/logistica_models.dart';
import 'package:frontend_mobile/theme/app_theme.dart';
import 'package:frontend_mobile/utils/format.dart';
import 'package:frontend_mobile/widgets/route/current_stop_card.dart';

/// Pedido tal como lo manda el servidor, con `detalles` en la forma que se
/// quiera probar.
PedidoDto pedido(Object? detalles) => PedidoDto.fromJson({
  'id': 'p1',
  'clienteNombre': 'Josue',
  'clienteTelefono': '0965687793',
  'direccion': 'Test',
  'ubicacion': {'latitud': -0.18, 'longitud': -78.48},
  'fechaEntrega': '2026-11-19',
  'horaEntrega': '03:31:00',
  'estado': 'AsignadoARuta',
  'detalles': detalles,
});

/// Lo que mostró la captura: `detalles` llega como OBJETO con casi todo nulo.
const objetoDeLaCaptura = {
  'remitenteNombre': null,
  'remitenteTelefono': null,
  'remitenteCorreo': null,
  'destinatarioCorreo': null,
  'observaciones': '1x Audífonos inalámbricos con cancelación de ruido',
  'tipoCarga': null,
  'pesoKg': null,
  'fragil': null,
  'prioridad': null,
};

Future<void> showCard(WidgetTester tester, PedidoDto p) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CurrentStopCard(
            stop: ParadaDto(orden: 1, pedido: p),
            onCall: () {},
            onWhatsapp: () {},
            onShowMap: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('detalles que llega como objeto (el caso de la captura)', () {
    test('solo se queda con los artículos, sin claves ni "null"', () {
      final p = pedido(objetoDeLaCaptura);
      expect(p.detalles, '1x Audífonos inalámbricos con cancelación de ruido');
      expect(p.detalles, isNot(contains('null')));
      expect(p.detalles, isNot(contains('remitenteNombre')));
      expect(p.detalles, isNot(contains('{')));
    });

    test('sin datos de carga: no hay marcas', () {
      final p = pedido(objetoDeLaCaptura);
      expect(p.fragil, isFalse);
      expect(p.prioridad, isNull);
      expect(p.pesoKg, isNull);
      expect(p.tipoCarga, isNull);
    });

    testWidgets('la tarjeta muestra solo el artículo', (tester) async {
      await showCard(tester, pedido(objetoDeLaCaptura));
      expect(find.text('Para entregar'), findsOneWidget);
      expect(
        find.text('1x Audífonos inalámbricos con cancelación de ruido'),
        findsOneWidget,
      );
      // Nada del objeto crudo.
      expect(find.textContaining('null'), findsNothing);
      expect(find.textContaining('remitente'), findsNothing);
      expect(find.textContaining('tipoCarga'), findsNothing);
      expect(find.textContaining('{'), findsNothing);
      expect(find.text('Frágil'), findsNothing);
    });
  });

  group('datos de la carga con valor', () {
    final completo = {
      ...objetoDeLaCaptura,
      'observaciones': '2x Vela, 1x Jabón',
      'fragil': true,
      'prioridad': 'Alta',
      'pesoKg': 2.5,
      'tipoCarga': 'Cristalería',
    };

    test('se leen', () {
      final p = pedido(completo);
      expect(p.detalles, '2x Vela, 1x Jabón');
      expect(p.fragil, isTrue);
      expect(p.prioridad, 'Alta');
      expect(p.pesoKg, 2.5);
      expect(p.tipoCarga, 'Cristalería');
    });

    testWidgets('la tarjeta los muestra como marcas', (tester) async {
      await showCard(tester, pedido(completo));
      expect(find.text('2x Vela'), findsOneWidget);
      expect(find.text('1x Jabón'), findsOneWidget);
      expect(find.text('Frágil'), findsOneWidget);
      expect(find.text('Prioridad: Alta'), findsOneWidget);
      expect(find.text('2,5 kg'), findsOneWidget);
      expect(find.text('Cristalería'), findsOneWidget);
    });

    test('frágil acepta texto o número, no solo true', () {
      expect(pedido({'fragil': 'true'}).fragil, isTrue);
      expect(pedido({'fragil': 'Sí'}).fragil, isTrue);
      expect(pedido({'fragil': 1}).fragil, isTrue);
      expect(pedido({'fragil': false}).fragil, isFalse);
      expect(pedido({'fragil': 'no'}).fragil, isFalse);
      expect(pedido({'fragil': 0}).fragil, isFalse);
    });

    test('el peso acepta texto y descarta cero o negativo', () {
      expect(pedido({'pesoKg': '3.2'}).pesoKg, 3.2);
      expect(pedido({'pesoKg': 4}).pesoKg, 4);
      expect(pedido({'pesoKg': 0}).pesoKg, isNull);
      expect(pedido({'pesoKg': -1}).pesoKg, isNull);
      expect(pedido({'pesoKg': 'pesado'}).pesoKg, isNull);
    });

    testWidgets('solo datos de carga, sin artículos: igual se ven', (
      tester,
    ) async {
      await showCard(tester, pedido({'fragil': true, 'prioridad': 'Alta'}));
      expect(find.text('Frágil'), findsOneWidget);
      expect(find.text('Prioridad: Alta'), findsOneWidget);
    });
  });

  group('otras formas de mandar detalles', () {
    test('texto normal (como antes) no cambia', () {
      final p = pedido('2x Vela perfumada Yankee Candle');
      expect(p.detalles, '2x Vela perfumada Yankee Candle');
      expect(p.fragil, isFalse);
    });

    test('el objeto escrito como texto JSON también se entiende', () {
      final p = pedido(
        '{"observaciones":"1x Cable","fragil":true,"prioridad":null}',
      );
      expect(p.detalles, '1x Cable');
      expect(p.fragil, isTrue);
      expect(p.prioridad, isNull);
    });

    test('texto con llaves que no es JSON se muestra tal cual', () {
      final p = pedido('{pedido especial}');
      expect(p.detalles, '{pedido especial}');
    });

    test('lista de artículos dentro del objeto', () {
      final p = pedido({
        'articulos': ['2x Vela', '1x Jabón', null, ''],
      });
      expect(p.detalles, '2x Vela, 1x Jabón');
    });

    test('vacío, nulo o la palabra "null" no producen texto', () {
      expect(pedido(null).detalles, isNull);
      expect(pedido('').detalles, isNull);
      expect(pedido('   ').detalles, isNull);
      expect(pedido('null').detalles, isNull);
      expect(pedido({'observaciones': 'null'}).detalles, isNull);
      expect(pedido({'observaciones': '  '}).detalles, isNull);
      expect(pedido(<String, Object?>{}).detalles, isNull);
    });

    testWidgets('sin detalles la tarjeta no muestra la caja', (tester) async {
      await showCard(tester, pedido(null));
      expect(find.text('Para entregar'), findsNothing);
    });

    test('cambiar el estado conserva los datos de la carga', () {
      final p = pedido({
        'observaciones': '1x Cable',
        'fragil': true,
        'prioridad': 'Alta',
        'pesoKg': 1.5,
        'tipoCarga': 'Eléctrico',
      }).copyWith(estado: 'EnCamino');
      expect(p.estado, 'EnCamino');
      expect(p.detalles, '1x Cable');
      expect(p.fragil, isTrue);
      expect(p.prioridad, 'Alta');
      expect(p.pesoKg, 1.5);
      expect(p.tipoCarga, 'Eléctrico');
    });
  });

  group('formatWeight', () {
    test('kilos y gramos', () {
      expect(formatWeight(2), '2 kg');
      expect(formatWeight(2.5), '2,5 kg');
      expect(formatWeight(0.35), '350 g');
      expect(formatWeight(0), '—');
      expect(formatWeight(double.nan), '—');
    });
  });
}
