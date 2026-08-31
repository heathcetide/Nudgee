import 'package:dio/dio.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/secure_storage_service.dart';

/// Injects the `Authorization: Bearer <token>` header on every request.
///
/// This interceptor only attaches the bearer token — it does **not** handle
/// 401 responses. Token refresh and session-expiry logic is delegated to
/// [TokenRefreshInterceptor] which runs later in the chain.
class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;

  AuthInterceptor() : _storage = sl<SecureStorageService>();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip auth header for auth endpoints so login/refresh/register requests
    // are never stamped with a stale (possibly expired) token.
    if (_isAuthEndpoint(options.path) ||
        options.extra['skipAuth'] == true) {
      return handler.next(options);
    }

    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  // 401 errors are intentionally not handled here — TokenRefreshInterceptor
  // owns the refresh-and-retry flow.

  bool _isAuthEndpoint(String path) =>
      path.contains('/auth/login') ||
      path.contains('/auth/register') ||
      path.contains('/auth/refresh');
}
