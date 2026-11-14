import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

typedef AccessTokenProvider = String? Function();

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.accessTokenProvider,
    this.onUnauthorized,
  }) : client = client ?? http.Client(),
       baseUrl = _normalizeBaseUrl(baseUrl);

  final String baseUrl;
  final http.Client client;
  final Duration timeout;
  final AccessTokenProvider? accessTokenProvider;
  final void Function(String? usedToken)? onUnauthorized;

  void close() => client.close();

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  /// Transition endpoints deliberately send no body and are never retried.
  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, {required Object body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = Uri.parse('$baseUrl${path.startsWith('/') ? path : '/$path'}')
        .replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    final token = accessTokenProvider?.call();
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    int? responseStatus;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final response = await client.send(request).timeout(timeout);
      responseStatus = response.statusCode;
      if (response.statusCode == 401) {
        // Bind invalidation to this request's token, not the token that may
        // have replaced it while the request was in flight.
        onUnauthorized?.call(token);
      }
      final raw = await response.stream.bytesToString().timeout(timeout);
      final decoded = raw.trim().isEmpty ? null : _decode(raw);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _problem(response.statusCode, decoded);
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        message: 'La solicitud tardó demasiado. Comprueba la conexión.',
        isNetwork: true,
        isTimeout: true,
      );
    } on SocketException {
      throw const ApiException(
        message: 'No hay conexión con el servidor.',
        isNetwork: true,
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'No se pudo conectar con el servidor.',
        isNetwork: true,
      );
    } on FormatException {
      if (responseStatus != null) {
        throw ApiException(
          statusCode: responseStatus,
          message: _statusMessage(responseStatus),
        );
      }
      throw const ApiException(message: 'Respuesta inválida del servidor.');
    }
  }

  static dynamic _decode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return raw;
    }
  }

  static ApiException _problem(int status, dynamic value) {
    final map = value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
    final title = map['title']?.toString();
    final detail = map['detail']?.toString();
    final errors = map['errors'];
    final validation = errors is Map
        ? errors.entries
              .map(
                (entry) =>
                    '${entry.key}: ${entry.value is List ? (entry.value as List).join(', ') : entry.value}',
              )
              .join('\n')
        : null;
    final message = detail?.trim().isNotEmpty == true
        ? detail!
        : validation?.trim().isNotEmpty == true
        ? validation!
        : _statusMessage(status);
    return ApiException(
      statusCode: status,
      title: title,
      detail: detail,
      traceId: map['traceId']?.toString(),
      message: message,
    );
  }

  static String _statusMessage(int status) {
    switch (status) {
      case 400:
        return 'Los datos enviados no son válidos.';
      case 401:
        return 'La sesión no está autorizada.';
      case 403:
        return 'No tienes permiso para esta operación.';
      case 404:
        return 'No se encontró el recurso solicitado.';
      case 409:
        return 'El estado cambió en el servidor. Actualiza la ruta antes de continuar.';
      case 422:
        return 'La operación no cumple una regla del negocio.';
      case 429:
        return 'Demasiados intentos. Espera un momento antes de volver a intentar.';
      default:
        return 'Ocurrió un error en el servidor (HTTP $status).';
    }
  }

  static String _normalizeBaseUrl(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    if (result.endsWith('/api')) return result;
    return '$result/api';
  }
}
