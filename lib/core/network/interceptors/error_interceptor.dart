import 'package:dio/dio.dart';

import 'package:nudgee/core/errors/app_exception.dart';

/// Converts [DioException]s into typed [AppException]s.
///
/// Runs last in the interceptor chain so it sees the final error state.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final exception = _convert(err);

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: exception,
        type: err.type,
        response: err.response,
        stackTrace: err.stackTrace,
      ),
    );
  }

  AppException _convert(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException('Connection timeout', originalError: err, stackTrace: err.stackTrace);

      case DioExceptionType.badResponse:
        return _convertResponseError(err);

      case DioExceptionType.cancel:
        return const NetworkException('Request cancelled');

      case DioExceptionType.connectionError:
        return NetworkException('No internet connection', originalError: err, stackTrace: err.stackTrace);

      case DioExceptionType.badCertificate:
        return NetworkException('Bad certificate', originalError: err, stackTrace: err.stackTrace);

      case DioExceptionType.unknown:
      default:
        return NetworkException(
          err.message ?? 'Network error',
          originalError: err,
          stackTrace: err.stackTrace,
        );
    }
  }

  AppException _convertResponseError(DioException err) {
    final statusCode = err.response?.statusCode ?? 0;
    final data = err.response?.data;
    String message = 'Server error';

    if (data is Map<String, dynamic>) {
      message = data['message'] as String? ??
          data['error'] as String? ??
          data['detail'] as String? ??
          'Server error ($statusCode)';
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }

    if (statusCode == 401) {
      return AuthException(message, code: statusCode, originalError: err, stackTrace: err.stackTrace);
    }

    if (statusCode == 403) {
      return AuthException('Forbidden', code: statusCode, originalError: err, stackTrace: err.stackTrace);
    }

    if (statusCode == 422) {
      final fieldErrors = <String, String>{};
      if (data is Map<String, dynamic> && data['errors'] is Map) {
        final errors = data['errors'] as Map;
        for (final entry in errors.entries) {
          fieldErrors[entry.key.toString()] = entry.value.toString();
        }
      }
      return ValidationException(message, fieldErrors: fieldErrors, originalError: err, stackTrace: err.stackTrace);
    }

    return ServerException(
      message,
      statusCode: statusCode,
      originalError: err,
      stackTrace: err.stackTrace,
    );
  }
}
