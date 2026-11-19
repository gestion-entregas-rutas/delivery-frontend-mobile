import 'dart:convert';

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
    this.detalles,
    this.fragil = false,
    this.prioridad,
    this.pesoKg,
    this.tipoCarga,
    this.destinatarioNombre,
    this.destinatarioTelefono,
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

  /// Resumen de lo que hay que entregar (los artículos), en texto.
  final String? detalles;

  /// Datos de la carga que vienen dentro de `detalles` cuando el servidor lo
  /// manda como objeto.
  final bool fragil;
  final String? prioridad;
  final double? pesoKg;
  final String? tipoCarga;

  /// Quien recibe, si el servidor lo manda aparte del cliente. Hoy la pantalla
  /// usa `clienteNombre` y `clienteTelefono`; estos quedan disponibles hasta
  /// confirmar con el backend cuál mostrar cuando difieren.
  final String? destinatarioNombre;
  final String? destinatarioTelefono;
  final Guid? zonaId;

  /// Pedido cancelado: sigue en la ruta pero ya no hay que entregarlo.
  bool get cancelado => estado == 'Cancelado';
  bool get entregado => estado == 'Entregado';
  final Guid? rutaId;
  final String? registradoEn;
  final String? entregadoEn;

  factory PedidoDto.fromJson(Map<String, dynamic> json) {
    final carga = _parseDetalles(json['detalles']);
    return PedidoDto(
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
      detalles: carga.resumen,
      fragil: carga.fragil,
      prioridad: carga.prioridad,
      pesoKg: carga.pesoKg,
      tipoCarga: carga.tipoCarga,
      destinatarioNombre: _clean(json['destinatarioNombre']),
      destinatarioTelefono: _clean(json['destinatarioTelefono']),
      zonaId: _optionalText(json['zonaId']),
      rutaId: _optionalText(json['rutaId']),
      registradoEn: _optionalText(json['registradoEn']),
      entregadoEn: _optionalText(json['entregadoEn']),
    );
  }

  PedidoDto copyWith({String? estado}) => PedidoDto(
    id: id,
    clienteNombre: clienteNombre,
    clienteTelefono: clienteTelefono,
    direccion: direccion,
    ubicacion: ubicacion,
    fechaEntrega: fechaEntrega,
    horaEntrega: horaEntrega,
    estado: estado ?? this.estado,
    detalles: detalles,
    fragil: fragil,
    prioridad: prioridad,
    pesoKg: pesoKg,
    tipoCarga: tipoCarga,
    destinatarioNombre: destinatarioNombre,
    destinatarioTelefono: destinatarioTelefono,
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
      paradas.where((stop) => stop.pedido.entregado).length;

  /// Paradas que hay que entregar: las canceladas no cuentan.
  int get activeCount => paradas.where((stop) => !stop.pedido.cancelado).length;

  /// Todas las paradas no canceladas están entregadas (y hay al menos una).
  bool get allResolved => activeCount > 0 && completedCount == activeCount;

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

/// Lo que se entiende del campo `detalles` de un pedido.
class CargaDetalles {
  const CargaDetalles({
    this.resumen,
    this.fragil = false,
    this.prioridad,
    this.pesoKg,
    this.tipoCarga,
  });

  final String? resumen;
  final bool fragil;
  final String? prioridad;
  final double? pesoKg;
  final String? tipoCarga;
}

/// Texto limpio o `null`: sin espacios y sin los "null" que salen de convertir
/// un valor vacío a texto.
String? _clean(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return text;
}

bool _truthy(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = _clean(value)?.toLowerCase();
  return text == 'true' || text == 'si' || text == 'sí' || text == '1';
}

/// `detalles` puede llegar como texto ("2x Vela, 1x Jabón") o como objeto con
/// la carga ({observaciones: ..., fragil: ..., prioridad: ...}). También se
/// acepta ese objeto escrito como texto JSON. Nunca se muestra el objeto
/// crudo: solo el resumen de artículos y los datos de la carga que tengan
/// valor.
CargaDetalles _parseDetalles(dynamic raw) {
  if (raw == null) return const CargaDetalles();
  if (raw is Map) return _cargaDeMapa(raw);
  final text = _clean(raw);
  if (text == null) return const CargaDetalles();
  if (text.startsWith('{') && text.endsWith('}')) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return _cargaDeMapa(decoded);
    } on FormatException {
      // No era JSON: se trata como texto normal.
    }
  }
  return CargaDetalles(resumen: text);
}

CargaDetalles _cargaDeMapa(Map<dynamic, dynamic> map) {
  String? resumen =
      _clean(map['observaciones']) ??
      _clean(map['descripcion']) ??
      _clean(map['detalle']);
  final articulos = map['articulos'] ?? map['items'];
  if (resumen == null && articulos is List) {
    final names = articulos.map(_clean).whereType<String>().toList();
    if (names.isNotEmpty) resumen = names.join(', ');
  }
  final peso = map['pesoKg'];
  final kg = peso is num
      ? peso.toDouble()
      : double.tryParse(_clean(peso) ?? '');
  return CargaDetalles(
    resumen: resumen,
    fragil: _truthy(map['fragil']),
    prioridad: _clean(map['prioridad']),
    pesoKg: kg != null && kg > 0 ? kg : null,
    tipoCarga: _clean(map['tipoCarga']),
  );
}

String _text(dynamic value) => value?.toString() ?? '';
String? _optionalText(dynamic value) => value == null ? null : _text(value);
double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
int _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
