class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.title,
    this.detail,
    this.traceId,
    this.isNetwork = false,
    this.isTimeout = false,
    this.isInvalidResponse = false,
  });

  final String message;
  final int? statusCode;
  final String? title;
  final String? detail;
  final String? traceId;
  final bool isNetwork;
  final bool isTimeout;
  final bool isInvalidResponse;
  bool get isUncertain =>
      isNetwork ||
      isTimeout ||
      isInvalidResponse ||
      (statusCode != null && statusCode! >= 500);

  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ActiveRouteNotFound implements Exception {
  const ActiveRouteNotFound();
}
