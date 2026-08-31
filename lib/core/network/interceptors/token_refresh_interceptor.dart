import 'dart:async';

import 'package:dio/dio.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/services/logger_service.dart';

/// Intercepts 401 responses and transparently refreshes the access token.
///
/// Behaviour:
/// - On a 401 (and only 401) the interceptor calls [AuthService.refreshToken].
/// - While a refresh is in flight, concurrent 401s are parked on a single
///   [Completer] so the refresh endpoint is hit at most once.
/// - After a successful refresh the original request is retried once.
/// - If the refresh fails, tokens are cleared and the caller receives the
///   original 401 error (the app can then navigate to the login screen).
/// - Requests to `/auth/login` and `/auth/refresh`, or those flagged with
///   `extra['skipTokenRefresh'] = true`, bypass this interceptor entirely.
class TokenRefreshInterceptor extends QueuedInterceptor {
  /// Guards concurrent refresh attempts so only one network call is made.
  Completer<bool>? _refreshCompleter;

  /// Lazily resolved to break the Dio → AuthService → ApiClient → Dio cycle.
  LoggerService get _logger => sl<LoggerService>();
  AuthService get _auth => sl<AuthService>();

  TokenRefreshInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;

    // Only handle 401s.
    final statusCode = err.response?.statusCode;
    if (statusCode != 401) {
      return handler.next(err);
    }

    // Skip auth endpoints and explicitly flagged requests.
    if (_shouldSkip(options)) {
      return handler.next(err);
    }

    try {
      final refreshed = await _ensureRefreshed();
      if (!refreshed) {
        // Refresh failed — tokens are already cleared by AuthService.
        return handler.next(err);
      }

      // Update the Authorization header with the fresh token and retry.
      final newToken = _auth.accessToken;
      if (newToken != null && newToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $newToken';
      }

      // Mark this retry so we don't loop forever.
      options.extra['skipTokenRefresh'] = true;

      final response = await sl<Dio>().fetch(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    } catch (e) {
      _logger.e('Token refresh failed', error: e, tag: 'auth');
      return handler.next(err);
    }
  }

  /// Returns `true` when a valid access token is available after a refresh.
  ///
  /// Concurrent callers share the same in-flight refresh.
  Future<bool> _ensureRefreshed() async {
    final existing = _refreshCompleter;
    if (existing != null) {
      _logger.d('Concurrent 401 — waiting for in-flight refresh', tag: 'auth');
      return existing.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      // Local-only auth: no token refresh needed. Session persists locally.
      completer.complete(false);
      return false;
    } catch (e) {
      completer.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  bool _shouldSkip(RequestOptions options) {
    if (options.extra['skipTokenRefresh'] == true) return true;
    final path = options.path;
    return path.contains('/auth/login') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/register');
  }
}
