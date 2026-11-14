import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/data/api/api_client.dart';
import 'package:frontend_mobile/data/api/api_exception.dart';
import 'package:frontend_mobile/data/api/logistica_repository.dart';
import 'package:frontend_mobile/location/gps_service.dart';
import 'package:frontend_mobile/models/logistica_models.dart';
import 'package:frontend_mobile/realtime/seguimiento_service.dart';
import 'package:frontend_mobile/state/driver_controller.dart';
import 'package:geolocator/geolocator.dart';

class _Gateway implements LocationGateway {
  @override
  Future<bool> isServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;
  @override
  Stream<Position> positionStream({required int distanceFilter}) =>
      const Stream<Position>.empty();
  @override
  Future<bool> openLocationSettings() async => true;
  @override
  Future<bool> openAppSettings() async => true;
}

RutaDto _route({
  String state = 'Planificada',
  String orderState = 'AsignadoARuta',
}) => RutaDto(
  id: 'route-1',
  fecha: '2026-10-17',
  zonaId: 'zone-1',
  repartidorId: 'driver-1',
  capacidad: 1,
  estado: state,
  paradas: [
    ParadaDto(
      orden: 1,
      pedido: PedidoDto(
        id: 'order-1',
        clienteNombre: 'Cliente',
        clienteTelefono: '099',
        direccion: 'Dirección',
        ubicacion: const PuntoDto(latitud: -1, longitud: -2),
        fechaEntrega: '2026-10-17',
        horaEntrega: '09:00:00',
        estado: orderState,
      ),
    ),
  ],
);

class _Repo extends LogisticaRepository {
  _Repo(this.current) : super(ApiClient(baseUrl: 'http://localhost:5289/api'));
  RutaDto? current;
  ApiException? mutationError;

  @override
  Future<RutaDto?> rutaActiva(String repartidorId, String fecha) async =>
      current?.fecha == fecha ? current : null;

  @override
  Future<RutaDto> ruta(String rutaId) async => current!;

  @override
  Future<List<RepartidorDto>> repartidoresDisponibles() async => const [
    RepartidorDto(
      id: 'driver-1',
      nombre: 'D',
      telefono: '',
      capacidadMaxima: 1,
      estado: 'Disponible',
    ),
  ];

  @override
  Future<RutaDto> iniciarRuta(String rutaId) async {
    current = _route(state: 'EnCurso');
    return current!;
  }

  @override
  Future<PedidoDto> marcarEnCamino(String pedidoId) async {
    current = _route(state: 'EnCurso', orderState: 'EnCamino');
    return current!.paradas.single.pedido;
  }

  @override
  Future<PedidoDto> confirmarEntrega(String pedidoId) async {
    if (mutationError != null) throw mutationError!;
    current = _route(state: 'Completada', orderState: 'Entregado');
    return current!.paradas.single.pedido;
  }
}

void main() {
  test('Controller uses server states and serializes route actions', () async {
    final repository = _Repo(_route());
    final controller = DriverController(
      repository: repository,
      driverId: 'driver-1',
      seguimiento: SeguimientoService(hubUrl: 'http://localhost:5289'),
      gps: GpsService(gateway: _Gateway()),
      initialDate: DateTime(2026, 10, 17, 23, 55),
    );
    expect(controller.selectedDate, '2026-10-17');
    await controller.refresh();
    expect(controller.route?.paradas.single.orden, 1);
    await controller.startRoute();
    expect(controller.route?.estado, 'EnCurso');
    await controller.markEnCamino('order-1');
    expect(controller.route?.paradas.single.pedido.estado, 'EnCamino');
    await controller.confirmDelivery('order-1');
    expect(controller.route?.estado, 'Completada');
    expect(controller.gps.state, GpsState.stopped);
    await controller.logout();
  });

  test(
    'Conflict is surfaced and refresh runs before re-enabling actions',
    () async {
      final repository = _Repo(_route(state: 'EnCurso', orderState: 'EnCamino'))
        ..mutationError = const ApiException(
          statusCode: 409,
          message: 'Conflicto',
        );
      final controller = DriverController(
        repository: repository,
        driverId: 'driver-1',
        seguimiento: SeguimientoService(hubUrl: 'http://localhost:5289'),
        gps: GpsService(gateway: _Gateway()),
        initialDate: DateTime(2026, 10, 17),
      );
      await controller.refresh();
      await controller.confirmDelivery('order-1');
      expect(controller.error?.isConflict, isTrue);
      expect(controller.isBusy, isFalse);
      await controller.logout();
    },
  );
}
