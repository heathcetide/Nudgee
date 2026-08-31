/// Base exception type for all application errors.
///
/// All custom exceptions extend [AppException] so that the UI layer can
/// handle them uniformly via `try/catch` or `Either<AppException, T>`.
sealed class AppException implements Exception {
  final String message;
  final int? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => '$runtimeType(message: $message, code: $code)';
}

/// Network-level failures (timeout, no connection, DNS, etc.).
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.originalError, super.stackTrace});
}

/// Server returned an error response (4xx/5xx).
class ServerException extends AppException {
  final int statusCode;

  const ServerException(
    super.message, {
    required this.statusCode,
    super.originalError,
    super.stackTrace,
  });
}

/// Authentication / authorization failures.
class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.originalError, super.stackTrace});
}

/// Token expired — triggers refresh flow.
class TokenExpiredException extends AuthException {
  const TokenExpiredException({super.originalError, super.stackTrace})
      : super('Token expired', code: 401);
}

/// Local storage read/write failures.
class StorageException extends AppException {
  const StorageException(super.message, {super.originalError, super.stackTrace});
}

/// Permission denied by the user or system.
class PermissionException extends AppException {
  final String permissionName;

  const PermissionException(
    this.permissionName, {
    super.originalError,
    super.stackTrace,
  }) : super('Permission denied: $permissionName');
}

/// Validation failures (form fields, input parsing).
class ValidationException extends AppException {
  final Map<String, String> fieldErrors;

  const ValidationException(
    super.message, {
    this.fieldErrors = const {},
    super.originalError,
    super.stackTrace,
  });
}

/// Catch-all for unexpected errors.
class UnknownException extends AppException {
  const UnknownException(super.message, {super.originalError, super.stackTrace});
}

/// Bluetooth Low Energy (BLE) operation failures.
class BluetoothException extends AppException {
  const BluetoothException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}
