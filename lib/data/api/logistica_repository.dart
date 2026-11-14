import '../../models/logistica_models.dart';
import 'api_client.dart';
import 'api_exception.dart';

class LogisticaRepository {
  LogisticaRepository(this.api);

  final ApiClient api;

  Future<RutaDto?> rutaActiva(String repartidorId, String fecha) async {
    try {
      final value = await api.get(
        '/repartidores/$repartidorId/ruta',
        query: <String, String>{'fecha': fecha},
      );
      return RutaDto.fromJson(_map(value));
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<RutaDto> ruta(String rutaId) async =>
      RutaDto.fromJson(_map(await api.get('/rutas/$rutaId')));

  Future<List<RepartidorDto>> repartidoresDisponibles() async {
    final value = await api.get(
      '/repartidores',
      query: <String, String>{'soloDisponibles': 'true'},
    );
    return _list(value)
        .map((item) => RepartidorDto.fromJson(_map(item)))
        .toList();
  }

  Future<RutaDto> iniciarRuta(String rutaId) async =>
      RutaDto.fromJson(_map(await api.post('/rutas/$rutaId/iniciar')));

  Future<PedidoDto> marcarEnCamino(String pedidoId) async => PedidoDto.fromJson(
    _map(await api.post('/seguimiento/pedidos/$pedidoId/en-camino')),
  );

  Future<PedidoDto> confirmarEntrega(String pedidoId) async =>
      PedidoDto.fromJson(
        _map(await api.post('/seguimiento/pedidos/$pedidoId/entregado')),
      );

  /// Best-effort: el contrato GPS remoto puede no estar disponible aún.
  /// Los errores de endpoint ausente/no implementado se ignoran.
  Future<void> reportarUbicacion({
    required String rutaId,
    required double latitud,
    required double longitud,
    required double precisionMetros,
    required DateTime capturadaEnUtc,
  }) async {
    final body = <String, Object>{
      'rutaId': rutaId,
      'latitud': latitud,
      'longitud': longitud,
      'precisionMetros': precisionMetros,
      'capturadaEn': capturadaEnUtc.toIso8601String(),
    };
    for (final path in const <String>[
      '/seguimiento/ubicacion',
      '/repartidores/me/ubicacion',
    ]) {
      try {
        await api.post(path, body: body);
        return;
      } on ApiException catch (error) {
        if (error.statusCode == 404 ||
            error.statusCode == 405 ||
            error.statusCode == 501) {
          continue;
        }
        rethrow;
      }
    }
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map ||
        value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        value['estado'] is! String) {
      throw const ApiException(
        message: 'La respuesta del servidor está incompleta. Actualiza antes de continuar.',
        isInvalidResponse: true,
      );
    }
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> _list(dynamic value) {
    if (value is! List) {
      throw const ApiException(
        message: 'El servidor devolvió un listado inválido.',
        isInvalidResponse: true,
      );
    }
    return value;
  }
}
