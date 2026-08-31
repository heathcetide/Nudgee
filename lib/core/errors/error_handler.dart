import 'app_exception.dart';

/// Centralized error handler — converts any thrown object into [AppException].
class ErrorHandler {
  ErrorHandler._();

  /// Convert a raw [error] into a typed [AppException].
  static AppException handle(dynamic error, [StackTrace? stackTrace]) {
    if (error is AppException) return error;

    if (error is TypeError) {
      return UnknownException('Type error: ${error.toString()}', originalError: error, stackTrace: stackTrace);
    }

    if (error is StateError) {
      return UnknownException('State error: ${error.message}', originalError: error, stackTrace: stackTrace);
    }

    if (error is FormatException) {
      return UnknownException('Format error: ${error.message}', originalError: error, stackTrace: stackTrace);
    }

    if (error is ArgumentError) {
      return UnknownException('Invalid argument: ${error.message}', originalError: error, stackTrace: stackTrace);
    }

    return UnknownException(
      error?.toString() ?? 'Unknown error',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Whether [exception] is a network connectivity issue.
  static bool isNetworkError(AppException exception) =>
      exception is NetworkException ||
      (exception is ServerException && exception.statusCode >= 500);

  /// Whether [exception] is an auth issue requiring re-login.
  static bool isAuthError(AppException exception) =>
      exception is AuthException ||
      (exception is ServerException && exception.statusCode == 401);
}
