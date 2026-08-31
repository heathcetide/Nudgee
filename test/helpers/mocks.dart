import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A canned-response HTTP adapter for tests.
///
/// Installed as `dio.httpClientAdapter`, it returns configured [responses]
/// without touching the network. Set [errorToThrow] to simulate failures.
class MockHttpClientAdapter implements HttpClientAdapter {
  /// Map of `path` → canned response data. The matching key is the first
  /// entry whose path is contained in the request path.
  final Map<String, dynamic> responses = {};

  /// Optional HTTP status code returned (default 200).
  int statusCode = 200;

  /// Throw this instead of returning a response when set.
  Object? errorToThrow;

  /// Handler invoked for `download()` calls. Receives the URL, save path
  /// and progress callback. Defaults to writing a small payload to disk.
  Future<void> Function(
    String url,
    String savePath, {
    required ProgressCallback onReceiveProgress,
    required CancelToken cancelToken,
  })? downloadHandler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    final data = _match(options.path);
    final bytes = Uint8List.fromList(_encode(data));
    return ResponseBody.fromBytes(
      bytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  dynamic _match(String path) {
    for (final entry in responses.entries) {
      if (path.contains(entry.key)) return entry.value;
    }
    return null;
  }

  List<int> _encode(dynamic data) {
    if (data == null) return const [];
    if (data is String) return data.codeUnits;
    if (data is List<int>) return data;
    // Treat as JSON-serializable.
    return data.toString().codeUnits;
  }
}

/// A [Dio] instance pre-configured with a [MockHttpClientAdapter].
///
/// Use [adapter] to configure canned responses / errors. The underlying
/// [Dio] is fully functional and can be passed to [ApiClient].
class MockDio {
  MockDio()
      : dio = Dio(BaseOptions(baseUrl: 'https://test.example')),
        adapter = MockHttpClientAdapter() {
    dio.httpClientAdapter = adapter;
  }

  /// The configured [Dio] instance — pass this to [ApiClient].
  final Dio dio;

  /// The mock adapter backing [dio].
  final MockHttpClientAdapter adapter;

  /// Convenience accessor for canned responses.
  Map<String, dynamic> get responses => adapter.responses;

  /// Convenience accessor for the simulated error.
  Object? get errorToThrow => adapter.errorToThrow;
  set errorToThrow(Object? value) => adapter.errorToThrow = value;

  /// Convenience accessor for the status code.
  int get statusCode => adapter.statusCode;
  set statusCode(int value) => adapter.statusCode = value;

  /// Configure the download handler used by [downloadViaAdapter].
  void setDownloadHandler(
    Future<void> Function(
      String url,
      String savePath, {
      required ProgressCallback onReceiveProgress,
      required CancelToken cancelToken,
    }) handler,
  ) =>
      adapter.downloadHandler = handler;

  /// Simulate a download by writing a small file to [savePath] and
  /// reporting progress. Mirrors what `Dio.download` does at the IO layer
  /// but without network access.
  Future<void> downloadViaAdapter(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    final token = cancelToken ?? CancelToken();
    if (token.isCancelled) {
      throw DioException(
        requestOptions: RequestOptions(path: url),
        type: DioExceptionType.cancel,
      );
    }
    final handler = adapter.downloadHandler ?? _defaultDownloadHandler;
    await handler(
      url,
      savePath,
      onReceiveProgress: onReceiveProgress ?? (_, __) {},
      cancelToken: token,
    );
  }

  Future<void> _defaultDownloadHandler(
    String url,
    String savePath, {
    required ProgressCallback onReceiveProgress,
    required CancelToken cancelToken,
  }) async {
    const total = 1024;
    final bytes = Uint8List(total);
    await File(savePath).writeAsBytes(bytes);
    onReceiveProgress(total, total);
  }
}
