import 'package:dio/dio.dart';

import 'package:nudgee/core/config/app_config.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/logger_service.dart';

/// Logs HTTP requests and responses in dev/staging.
///
/// In production, this interceptor is a no-op.
class LoggingInterceptor extends Interceptor {
  final LoggerService _logger;

  LoggingInterceptor() : _logger = sl<LoggerService>();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!AppConfig.enableVerboseLogging) return handler.next(options);

    _logger.d('→ ${options.method} ${options.path}');
    if (options.queryParameters.isNotEmpty) {
      _logger.d('  Query: ${options.queryParameters}');
    }
    if (options.data != null) {
      _logger.d('  Body: ${options.data}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!AppConfig.enableVerboseLogging) return handler.next(response);

    _logger.d('← ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e(
      '✕ ${err.requestOptions.method} ${err.requestOptions.path}',
      error: err.error ?? err,
      stackTrace: err.stackTrace,
      tag: 'network',
    );
    handler.next(err);
  }
}
