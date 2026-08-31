// Unified API response models for the standard envelope returned by the
// backend.
//
// The server wraps every response in:
// ```json
// {
//   "code": 0,
//   "message": "ok",
//   "data": { ... }
// }
// ```
// For list endpoints the envelope also carries pagination metadata:
// ```json
// {
//   "code": 0,
//   "message": "ok",
//   "data": [ ... ],
//   "total": 100,
//   "page": 1,
//   "page_size": 20
// }
// ```

// ────────────────────────────────────────────────────────────────────────

/// Generic single-item API response.
class ApiResponse<T> {
  /// Business-level status code (`0` typically means success).
  final int code;

  /// Human-readable message from the server.
  final String message;

  /// Decoded payload, or `null` when the envelope carries no data.
  final T? data;

  /// Convenience flag derived from [code].
  final bool success;

  ApiResponse({
    required this.code,
    required this.message,
    this.data,
    required this.success,
  });

  /// Parses a [Map<String, dynamic>] envelope into an [ApiResponse].
  ///
  /// [fromJsonT] converts the raw `data` field into the generic type [T].
  /// When omitted, the raw value is cast to `T` directly.
  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    T Function(dynamic)? fromJsonT,
  }) {
    final raw = json['data'];
    T? data;
    if (raw != null) {
      data = fromJsonT != null ? fromJsonT(raw) : raw as T?;
    }
    final code = (json['code'] as num?)?.toInt() ?? 0;
    return ApiResponse<T>(
      code: code,
      message: json['message'] as String? ?? '',
      data: data,
      success: code == 0,
    );
  }

  @override
  String toString() =>
      'ApiResponse(code: $code, message: $message, success: $success, data: $data)';
}

/// Generic paginated list API response.
class ApiListResponse<T> {
  final int code;
  final String message;
  final List<T> data;
  final int total;
  final int page;
  final int pageSize;
  final bool success;

  ApiListResponse({
    required this.code,
    required this.message,
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.success,
  });

  /// Parses a [Map<String, dynamic>] envelope into an [ApiListResponse].
  ///
  /// [fromJsonT] converts each element of the `data` array into [T].
  factory ApiListResponse.fromJson(
    Map<String, dynamic> json, {
    T Function(dynamic)? fromJsonT,
  }) {
    final rawList = json['data'];
    List<T> data = <T>[];
    if (rawList is List) {
      data = fromJsonT != null
          ? rawList.map(fromJsonT).toList()
          : rawList.cast<T>();
    }
    final code = (json['code'] as num?)?.toInt() ?? 0;
    return ApiListResponse<T>(
      code: code,
      message: json['message'] as String? ?? '',
      data: data,
      total: (json['total'] as num?)?.toInt() ?? data.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ??
          (json['pageSize'] as num?)?.toInt() ??
          data.length,
      success: code == 0,
    );
  }

  @override
  String toString() =>
      'ApiListResponse(code: $code, message: $message, success: $success, '
      'total: $total, page: $page, pageSize: $pageSize, items: ${data.length})';
}
