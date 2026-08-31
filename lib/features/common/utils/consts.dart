import 'package:dio/dio.dart';

/// Global Dio instance for simple one-off requests (image downloads, etc.).
/// For API calls with interceptors, use the DI-registered Dio instance.
var dio = Dio();

final Options FromOptions = Options(
  headers: {
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
  },
);
