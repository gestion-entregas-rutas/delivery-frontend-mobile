import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/data/api/api_client.dart';
import 'package:frontend_mobile/data/api/api_exception.dart';
import 'package:frontend_mobile/data/api/logistica_repository.dart';
import 'package:frontend_mobile/models/logistica_models.dart';
import 'package:frontend_mobile/state/driver_controller.dart';
import 'package:frontend_mobile/theme/app_theme.dart';
import 'package:frontend_mobile/widgets/route/current_stop_card.dart';
import 'package:frontend_mobile/widgets/route/route_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'route_screen_test.dart' as h;

/// Respuesta de ejemplo de `GET /api/repartidores/{id}/ruta?fecha=...`, tal
/// como la documentó el equipo de backend.
const String rutaDeEjemplo = '''
{
  "id": "r1", "fecha": "2026-11-20", "zonaId": "z1", "repartidorId": "d1",
  "capacidad": 4, "estado": "Planificada", "version": 3,
  "paradas": [
    { "orden": 1, "pedido": {
        "id": "p1", "clienteNombre": "Ana Pérez", "clienteTelefono": "0991234567",
        "direccion": "Av. Cevallos y Montalvo",
        "ubicacion": { "latitud": -1.23436, "longitud": -78.61547 },
        "zonaId": "z1", "fechaEntrega": "2026-11-20", "horaEntrega": "10:00:00",
        "estado": "AsignadoARuta", "rutaId": "r1",
        "registradoEn": "2026-11-19T15:02:11.123+00:00", "entregadoEn": null,
        "detalles": { "remitenteNombre": "Tienda X", "remitenteTelefono": "0987654321",
          "remitenteCorreo": "a@b.com", "destinatarioCorreo": "c@d.com",
          "observaciones": "Entregar en portería", "tipoCarga": "Alimentos",
          "pesoKg": 2.5, "fragil": true, "prioridad": "Urgente" },
        "version": 1, "destinatarioNombre": "Ana Pérez", "destinatarioTelefono": "0991234567" } },
    { "orden": 2, "pedido": {
        "id": "p2", "clienteNombre": "Luis Mora", "clienteTelefono": "+593 98 765 4321",
        "direccion": "Calle Bolívar 12",
        "ubicacion": { "latitud": -1.24, "longitud": -78.62 },
        "zonaId": "z1", "fechaEntrega": "2026-11-20", "horaEntrega": "11:30:00",
        "estado": "AsignadoARuta", "rutaId": "r1",
        "registradoEn": "2026-11-19T15:05:00+00:00", "entregadoEn": null,
        "detalles": { "remitenteNombre": null, "remitenteTelefono": null, "remitenteCorreo": null,
          "destinatarioCorreo": null, "observaciones": "2x Audífonos, 1x Mouse",
          "tipoCarga": null, "pesoKg": null, "fragil": null, "prioridad": null } } }
  ]
}
''';

RutaDto parseRuta() =>
    RutaDto.fromJson(jsonDecode(rutaDeEjemplo) as Map<String, dynamic>);

Future<void> showCard(WidgetTester tester, PedidoDto p) async {
  tester.view.physicalSize = const Size(390, 1400);
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
  // Las teselas del mapa necesitan red: en pruebas se apagan.
  setUpAll(() => RouteMap.tilesEnabled = false);

  group('la respuesta de ejemplo del backend se lee completa', () {
    test('ruta', () {
      final r = parseRuta();
      expect(r.id, 'r1');
      expect(r.fecha, '2026-11-20');
      expect(r.estado, 'Planificada');
      expect(r.paradas.length, 2);
    });

    test('pedido con todos los datos de carga', () {
      final p = parseRuta().paradas[0].pedido;
      expect(p.clienteNombre, 'Ana Pérez');
      expect(p.horaEntrega, '10:00:00');
      expect(p.detalles, 'Entregar en portería');
      expect(p.fragil, isTrue);
      expect(p.prioridad, 'Urgente');
      expect(p.pesoKg, 2.5);
      expect(p.tipoCarga, 'Alimentos');
      expect(p.destinatarioNombre, 'Ana Pérez');
      expect(p.destinatarioTelefono, '0991234567');
      expect(p.ubicacion.latitud, -1.23436);
    });

    test('pedido de la tienda con la carga en null', () {
      final p = parseRuta().paradas[1].pedido;
      expect(p.detalles, '2x Audífonos, 1x Mouse');
      expect(p.fragil, isFalse);
      expect(p.prioridad, isNull);
      expect(p.pesoKg, isNull);
      expect(p.tipoCarga, isNull);
      // El teléfono es texto libre: se conserva tal cual.
      expect(p.clienteTelefono, '+593 98 765 4321');
      expect(p.destinatarioNombre, isNull);
    });

    test('pedido histórico con detalles null no falla', () {
      final json = jsonDecode(rutaDeEjemplo) as Map<String, dynamic>;
      final paradas = json['paradas'] as List;
      ((paradas[0] as Map)['pedido'] as Map)['detalles'] = null;
      final p = RutaDto.fromJson(json).paradas[0].pedido;
      expect(p.detalles, isNull);
      expect(p.fragil, isFalse);
    });
  });

  group('observaciones: artículos de la tienda o texto libre', () {
    test('checkout: cantidad x producto separados por ", "', () {
      final o = parseObservaciones('2x Audífonos, 1x Mouse');
      expect(o.items, ['2x Audífonos', '1x Mouse']);
      expect(o.note, isNull);
    });

    test('una coma dentro del nombre del producto no corta el artículo', () {
      final o = parseObservaciones('2x Audífonos, con estuche, 1x Mouse');
      expect(o.items, ['2x Audífonos, con estuche', '1x Mouse']);
    });

    test('acepta × y espacios, como en pantallas anteriores', () {
      expect(parseObservaciones('2 × Vela, 1 × Jabón').items, [
        '2 × Vela',
        '1 × Jabón',
      ]);
      expect(parseObservaciones('3X Taza').items, ['3X Taza']);
    });

    test('texto libre se deja entero, aunque tenga comas', () {
      final o = parseObservaciones('Entregar en portería, tocar el timbre');
      expect(o.items, isEmpty);
      expect(o.note, 'Entregar en portería, tocar el timbre');
    });

    test('una "x" de medidas no lo convierte en lista', () {
      expect(parseObservaciones('Caja 2x3 grande, frágil').items, isEmpty);
      expect(parseObservaciones('2x3 cm, caja').items, isEmpty);
      expect(parseObservaciones('2x3 cm, caja').note, '2x3 cm, caja');
    });

    test('varias líneas de artículos', () {
      expect(parseObservaciones('2x Vela\n1x Jabón').items, [
        '2x Vela',
        '1x Jabón',
      ]);
    });

    test('vacío o solo espacios no es nada', () {
      for (final raw in [null, '', '   ', '\n']) {
        final o = parseObservaciones(raw);
        expect(o.items, isEmpty);
        expect(o.note, isNull);
      }
    });

    test('parseStopItems devuelve solo artículos', () {
      expect(parseStopItems('2x Vela, 1x Jabón'), ['2x Vela', '1x Jabón']);
      expect(parseStopItems('Entregar en portería'), isEmpty);
    });
  });

  group('la tarjeta muestra lo que corresponde', () {
    testWidgets('artículos de la tienda: "Para entregar" con su lista', (
      tester,
    ) async {
      await showCard(tester, parseRuta().paradas[1].pedido);
      expect(find.text('Para entregar'), findsOneWidget);
      expect(find.text('2x Audífonos'), findsOneWidget);
      expect(find.text('1x Mouse'), findsOneWidget);
      expect(find.text('Observaciones'), findsNothing);
    });

    testWidgets('texto libre: "Observaciones" con el texto entero', (
      tester,
    ) async {
      await showCard(tester, parseRuta().paradas[0].pedido);
      expect(find.text('Observaciones'), findsOneWidget);
      expect(find.text('Entregar en portería'), findsOneWidget);
      expect(find.text('Para entregar'), findsNothing);
    });

    testWidgets('datos de carga del pedido con todo: marcas visibles', (
      tester,
    ) async {
      await showCard(tester, parseRuta().paradas[0].pedido);
      expect(find.text('Frágil'), findsOneWidget);
      expect(find.text('Prioridad: Urgente'), findsOneWidget);
      expect(find.text('2,5 kg'), findsOneWidget);
      expect(find.text('Alimentos'), findsOneWidget);
    });

    testWidgets('con la carga en null no hay marcas', (tester) async {
      await showCard(tester, parseRuta().paradas[1].pedido);
      expect(find.text('Frágil'), findsNothing);
      expect(find.textContaining('Prioridad'), findsNothing);
      expect(find.textContaining('kg'), findsNothing);
    });
  });

  group('pedidos cancelados', () {
    PedidoDto pedido(String id, String estado) => PedidoDto(
      id: id,
      clienteNombre: 'Cliente $id',
      clienteTelefono: '099',
      direccion: 'Dir $id',
      ubicacion: const PuntoDto(latitud: -1.2, longitud: -78.6),
      fechaEntrega: '2026-10-17',
      horaEntrega: '09:00:00',
      estado: estado,
    );

    RutaDto ruta(List<String> estados, {String estado = 'EnCurso'}) => RutaDto(
      id: 'r',
      fecha: '2026-10-17',
      zonaId: 'z',
      repartidorId: 'd',
      capacidad: 5,
      estado: estado,
      paradas: [
        for (var i = 0; i < estados.length; i++)
          ParadaDto(orden: i + 1, pedido: pedido('${i + 1}', estados[i])),
      ],
    );

    test('no cuentan en el avance', () {
      final r = ruta(['Entregado', 'Cancelado', 'EnCamino']);
      expect(r.paradas.length, 3);
      expect(r.activeCount, 2);
      expect(r.completedCount, 1);
      expect(r.allResolved, isFalse);
    });

    test('con todo entregado salvo lo cancelado, la ruta está resuelta', () {
      expect(ruta(['Entregado', 'Cancelado', 'Entregado']).allResolved, isTrue);
    });

    test('si todo está cancelado no hay nada resuelto', () {
      final r = ruta(['Cancelado', 'Cancelado']);
      expect(r.activeCount, 0);
      expect(r.allResolved, isFalse);
    });

    testWidgets('no es la parada actual: se salta a la siguiente', (
      tester,
    ) async {
      final c = await h.pumpHome(
        tester,
        ruta(['Entregado', 'Cancelado', 'EnCamino']),
      );
      // La parada actual es la 3, no la cancelada.
      expect(find.text('Cliente 3'), findsOneWidget);
      expect(find.text('En camino'), findsOneWidget);
      expect(find.text('Confirmar entrega'), findsOneWidget);
      // La cancelada aparece marcada y sin hora.
      expect(find.text('Cancelado'), findsOneWidget);
      expect(find.text('Cliente 2'), findsOneWidget);
      // El avance: 1 de 2 (la cancelada no cuenta).
      expect(find.text('1 de 2 entregas'), findsOneWidget);
      await h.teardown(tester, c);
    });

    testWidgets('el nodo se anuncia como cancelada', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await h.pumpHome(tester, ruta(['Cancelado', 'EnCamino']));
      expect(find.bySemanticsLabel('Parada 1, cancelada'), findsOneWidget);
      await h.teardown(tester, c);
      handle.dispose();
    });

    testWidgets(
      'si lo único que falta es lo cancelado, la ruta está completa',
      (tester) async {
        final c = await h.pumpHome(
          tester,
          ruta(['Entregado', 'Cancelado'], estado: 'Completada'),
        );
        expect(find.text('Ruta completada: 1 entregas'), findsOneWidget);
        await h.teardown(tester, c);
      },
    );

    test(
      'al entregar lo último, aunque haya canceladas, se cierra la ruta',
      () async {
        final repo = h.FakeRepo(ruta(['Cancelado', 'EnCamino']));
        final c = DriverController(
          repository: repo,
          driverId: 'd',
          seguimiento: h.FakeRealtime(),
          gps: h.FakeGps(),
          initialDate: DateTime(2026, 10, 17),
          clock: () => DateTime(2026, 10, 17, 9),
        );
        addTearDown(c.dispose);
        await c.refresh();
        await c.confirmDelivery('2');
        expect(repo.routeFetches, 1, reason: 'debe pedir la ruta ya cerrada');
        expect(c.route?.estado, 'Completada');
      },
    );

    testWidgets('no aparece en el mapa de la ruta', (tester) async {
      final c = await h.pumpHome(
        tester,
        ruta(['Entregado', 'Cancelado', 'EnCamino']),
      );
      await tester.tap(find.text('Mapa'));
      await tester.pumpAndSettle();
      // 2 paradas con posición (la cancelada no se visita).
      expect(find.text('1 de 2 entregadas'), findsOneWidget);
      await h.teardown(tester, c);
    });
  });

  group('reportar ubicación: contrato confirmado', () {
    LogisticaRepository repoWith(http.Client client) => LogisticaRepository(
      ApiClient(baseUrl: 'https://example.test', client: client),
    );

    test(
      'POST a /api/repartidores/me/ubicacion, una sola vez, sin adivinar',
      () async {
        final requests = <http.Request>[];
        final repo = repoWith(
          MockClient((request) async {
            requests.add(request);
            return http.Response(jsonEncode({'actualizada': true}), 200);
          }),
        );
        await repo.reportarUbicacion(
          rutaId: 'r1',
          latitud: -1.23436,
          longitud: -78.61547,
          precisionMetros: 12.5,
          capturadaEnUtc: DateTime.utc(2026, 11, 20, 15, 5),
        );
        expect(requests.length, 1);
        expect(requests.single.method, 'POST');
        expect(requests.single.url.path, '/api/repartidores/me/ubicacion');
        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body, {
          'rutaId': 'r1',
          'latitud': -1.23436,
          'longitud': -78.61547,
          'precisionMetros': 12.5,
          'capturadaEn': '2026-11-20T15:05:00.000Z',
        });
      },
    );

    test(
      'capturadaEn lleva siempre offset (Z), aun si llega en hora local',
      () async {
        String? sent;
        final repo = repoWith(
          MockClient((request) async {
            sent = (jsonDecode(request.body) as Map)['capturadaEn'] as String;
            return http.Response('{}', 200);
          }),
        );
        await repo.reportarUbicacion(
          rutaId: 'r1',
          latitud: 0.5,
          longitud: 0.5,
          precisionMetros: 5,
          capturadaEnUtc: DateTime(2026, 11, 20, 10, 5), // hora local
        );
        expect(sent, endsWith('Z'));
      },
    );

    test(
      'un 422 (ruta no en curso) llega como error para quien llama',
      () async {
        final repo = repoWith(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'status': 422,
                'title': 'Solicitud no procesable',
                'detail': 'Solo se publica GPS durante una ruta en curso.',
              }),
              422,
              headers: {'content-type': 'application/problem+json'},
            ),
          ),
        );
        expect(
          () => repo.reportarUbicacion(
            rutaId: 'r1',
            latitud: 0.5,
            longitud: 0.5,
            precisionMetros: 5,
            capturadaEnUtc: DateTime.utc(2026),
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'Solo se publica GPS durante una ruta en curso.',
            ),
          ),
        );
      },
    );

    test(
      'un 404 ya no se ignora: no hay segundo intento a otra ruta',
      () async {
        final paths = <String>[];
        final repo = repoWith(
          MockClient((request) async {
            paths.add(request.url.path);
            return http.Response('', 404);
          }),
        );
        await expectLater(
          repo.reportarUbicacion(
            rutaId: 'r1',
            latitud: 0.5,
            longitud: 0.5,
            precisionMetros: 5,
            capturadaEnUtc: DateTime.utc(2026),
          ),
          throwsA(isA<ApiException>()),
        );
        expect(paths, ['/api/repartidores/me/ubicacion']);
      },
    );
  });
}
