import 'package:dio/dio.dart';

import 'package:nudgee/core/errors/app_exception.dart';

/// Typed HTTP client wrapping [Dio].
///
/// All methods throw [AppException] subtypes on failure — never raw [DioException].
/// The UI/repository layer can catch [AppException] uniformly.
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  Dio get dio => _dio;

  // ── GET ──────────────────────────────────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _safeRequest(() => _dio.get<T>(
            path,
            queryParameters: queryParameters,
            options: options,
            cancelToken: cancelToken,
          ));

  // ── POST ─────────────────────────────────────────────────────────────

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) =>
      _safeRequest(() => _dio.post<T>(
            path,
            data: data,
            queryParameters: queryParameters,
            options: options,
            cancelToken: cancelToken,
            onSendProgress: onSendProgress,
            onReceiveProgress: onReceiveProgress,
          ));

  // ── PUT ──────────────────────────────────────────────────────────────

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _safeRequest(() => _dio.put<T>(
            path,
            data: data,
            queryParameters: queryParameters,
            options: options,
            cancelToken: cancelToken,
          ));

  // ── PATCH ────────────────────────────────────────────────────────────

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _safeRequest(() => _dio.patch<T>(
            path,
            data: data,
            queryParameters: queryParameters,
            options: options,
            cancelToken: cancelToken,
          ));

  // ── DELETE ───────────────────────────────────────────────────────────

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _safeRequest(() => _dio.delete<T>(
            path,
            data: data,
            queryParameters: queryParameters,
            options: options,
            cancelToken: cancelToken,
          ));

  // ── Multipart upload ─────────────────────────────────────────────────

  Future<Response<T>> upload<T>(
    String path, {
    required FormData formData,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) =>
      _safeRequest(() => _dio.post<T>(
            path,
            data: formData,
            options: options,
            cancelToken: cancelToken,
            onSendProgress: onSendProgress,
          ));

  // ── Download ─────────────────────────────────────────────────────────

  Future<Response> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    Options? options,
  }) =>
      _safeRequest(() => _dio.download(
            urlPath,
            savePath,
            onReceiveProgress: onReceiveProgress,
            cancelToken: cancelToken,
            options: options,
          ));

  // ── Private ──────────────────────────────────────────────────────────

  Future<Response<T>> _safeRequest<T>(Future<Response<T>> Function() request) {
    return request().catchError((error) {
      if (error is DioException) {
        // ErrorInterceptor has already converted to AppException in `error` field.
        throw error.error ?? ServerException(
              error.message ?? 'Server error',
              statusCode: error.response?.statusCode ?? 0,
              originalError: error,
            );
      }
      throw error;
    });
  }
}
