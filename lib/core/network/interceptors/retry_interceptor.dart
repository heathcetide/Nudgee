import 'package:dio/dio.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/logger_service.dart';

/// Retries failed requests with exponential backoff.
///
/// Only retries on network errors and 5xx server errors.
/// Default: 3 retries with 1s, 2s, 4s delays.
class RetryInterceptor extends Interceptor {
  final LoggerService _logger;
  final int maxRetries;
  final Duration initialDelay;

  RetryInterceptor({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
  }) : _logger = sl<LoggerService>();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retries = _getRetryCount(err.requestOptions);

    final shouldRetry = _isRetryable(err) && retries < maxRetries;
    if (!shouldRetry) return handler.next(err);

    final delay = initialDelay * (1 << retries); // 1s, 2s, 4s...
    _logger.w('Retrying ${err.requestOptions.path} (${retries + 1}/$maxRetries) after ${delay.inSeconds}s');

    await Future.delayed(delay);

    err.requestOptions.extra['retry-count'] = retries + 1;
    try {
      final response = await sl<Dio>().fetch(err.requestOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _isRetryable(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }
    if (err.response?.statusCode != null && err.response!.statusCode! >= 500) {
      return true;
    }
    return false;
  }

  int _getRetryCount(RequestOptions options) =>
      options.extra['retry-count'] as int? ?? 0;
}
