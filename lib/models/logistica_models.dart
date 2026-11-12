/// Modelos del contrato JSON de Delivery API.
///
/// Las fechas de ruta se mantienen como `yyyy-MM-dd`; nunca se convierten a
/// UTC porque eso puede cambiar el día seleccionado por el repartidor.
typedef Guid = String;

class PuntoDto {
  const PuntoDto({required this.latitud, required this.longitud});

  final double latitud;
  final double longitud;

  factory PuntoDto.fromJson(Map<String, dynamic> json) => PuntoDto(
    latitud: _number(json['latitud']),
    longitud: _number(json['longitud']),
  );
}

class PedidoDto {
  const PedidoDto({
    required this.id,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.direccion,
    required this.ubicacion,
    required this.fechaEntrega,
    required this.horaEntrega,
    required this.estado,
    this.zonaId,
    this.rutaId,
    this.registradoEn,
    this.entregadoEn,
  });

  final Guid id;
  final String clienteNombre;
  final String clienteTelefono;
  final String direccion;
  final PuntoDto ubicacion;
  final String fechaEntrega;
  final String horaEntrega;
  final String estado;
  final Guid? zonaId;
  final Guid? rutaId;
  final String? registradoEn;
  final String? entregadoEn;

  factory PedidoDto.fromJson(Map<String, dynamic> json) => PedidoDto(
    id: _text(json['id']),
    clienteNombre: _text(json['clienteNombre']),
    clienteTelefono: _text(json['clienteTelefono']),
    direccion: _text(json['direccion']),
    ubicacion: PuntoDto.fromJson(
      _map(json['ubicacion'] ?? <String, dynamic>{}),
    ),
    fechaEntrega: _text(json['fechaEntrega']),
    horaEntrega: _text(json['horaEntrega']),
    estado: _text(json['estado']),
    zonaId: _optionalText(json['zonaId']),
    rutaId: _optionalText(json['rutaId']),
    registradoEn: _optionalText(json['registradoEn']),
    entregadoEn: _optionalText(json['entregadoEn']),
  );

  PedidoDto copyWith({String? estado}) => PedidoDto(
    id: id,
    clienteNombre: clienteNombre,
    clienteTelefono: clienteTelefono,
    direccion: direccion,
    ubicacion: ubicacion,
    fechaEntrega: fechaEntrega,
    horaEntrega: horaEntrega,
    estado: estado ?? this.estado,
    zonaId: zonaId,
    rutaId: rutaId,
    registradoEn: registradoEn,
    entregadoEn: entregadoEn,
  );
}

class ParadaDto {
  const ParadaDto({required this.orden, required this.pedido});

  final int orden;
  final PedidoDto pedido;

  factory ParadaDto.fromJson(Map<String, dynamic> json) => ParadaDto(
    orden: _integer(json['orden']),
    pedido: PedidoDto.fromJson(_map(json['pedido'])),
  );
}

class RutaDto {
  const RutaDto({
    required this.id,
    required this.fecha,
    required this.zonaId,
    required this.repartidorId,
    required this.capacidad,
    required this.estado,
    required this.paradas,
  });

  final Guid id;
  final String fecha;
  final Guid? zonaId;
  final Guid repartidorId;
  final int capacidad;
  final String estado;
  final List<ParadaDto> paradas;

  factory RutaDto.fromJson(Map<String, dynamic> json) {
    final stops =
        (_list(json['paradas']))
            .map((item) => ParadaDto.fromJson(_map(item)))
            .toList()
          ..sort((a, b) => a.orden.compareTo(b.orden));
    return RutaDto(
      id: _text(json['id']),
      fecha: _text(json['fecha']),
      zonaId: _optionalText(json['zonaId']),
      repartidorId: _text(json['repartidorId']),
      capacidad: _integer(json['capacidad']),
      estado: _text(json['estado']),
      paradas: List.unmodifiable(stops),
    );
  }

  int get completedCount =>
      paradas.where((stop) => stop.pedido.estado == 'Entregado').length;

  RutaDto withPedido(PedidoDto pedido) => RutaDto(
    id: id,
    fecha: fecha,
    zonaId: zonaId,
    repartidorId: repartidorId,
    capacidad: capacidad,
    estado: estado,
    paradas: List.unmodifiable(
      paradas
          .map(
            (stop) => stop.pedido.id == pedido.id
                ? ParadaDto(orden: stop.orden, pedido: pedido)
                : stop,
          )
          .toList()
        ..sort((a, b) => a.orden.compareTo(b.orden)),
    ),
  );
}

class RepartidorDto {
  const RepartidorDto({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.capacidadMaxima,
    required this.estado,
  });

  final Guid id;
  final String nombre;
  final String telefono;
  final int capacidadMaxima;
  final String estado;

  factory RepartidorDto.fromJson(Map<String, dynamic> json) => RepartidorDto(
    id: _text(json['id']),
    nombre: _text(json['nombre']),
    telefono: _text(json['telefono']),
    capacidadMaxima: _integer(json['capacidadMaxima']),
    estado: _text(json['estado']),
  );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<dynamic> _list(dynamic value) => value is List ? value : const <dynamic>[];
String _text(dynamic value) => value?.toString() ?? '';
String? _optionalText(dynamic value) => value == null ? null : _text(value);
double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
int _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
