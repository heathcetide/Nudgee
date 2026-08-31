import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/network/api_client.dart';
import 'package:nudgee/core/services/download_service.dart';

import 'mocks.dart';

export 'mocks.dart';

/// Helpers for setting up test dependencies without real network / native
/// plugins.
class TestHelpers {
  TestHelpers._();

  /// Initialize a lightweight DI graph suitable for unit / widget tests.
  ///
  /// Registers a [MockDio]-backed [ApiClient], a [DownloadService], and
  /// mock [SharedPreferences]. Safe to call repeatedly — resets `sl` first.
  static Future<void> setupTestDependencies() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await resetDependencies();

    final mockDio = MockDio();
    sl.registerLazySingleton<Dio>(() => mockDio.dio);
    sl.registerLazySingleton<ApiClient>(() => ApiClient(sl<Dio>()));
    sl.registerLazySingleton<DownloadService>(
      () => DownloadService(sl<ApiClient>()),
    );
  }

  /// Create a fresh [ApiClient] backed by a [MockDio] (not registered in `sl`).
  static ApiClient createMockApiClient() => ApiClient(createMockDio().dio);

  /// Create a fresh [MockDio].
  static MockDio createMockDio() => MockDio();

  /// Print a debug message prefixed with `[test]`.
  static void log(String message) => debugPrint('[test] $message');
}
