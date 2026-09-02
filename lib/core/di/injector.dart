import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nudgee/core/config/app_config.dart';
import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/network/api_client.dart';
import 'package:nudgee/core/network/interceptors/auth_interceptor.dart';
import 'package:nudgee/core/network/interceptors/error_interceptor.dart';
import 'package:nudgee/core/network/interceptors/logging_interceptor.dart';
import 'package:nudgee/core/network/interceptors/retry_interceptor.dart';
import 'package:nudgee/core/network/interceptors/token_refresh_interceptor.dart';
import 'package:nudgee/core/services/analytics_service.dart';
import 'package:nudgee/core/services/api_cache_service.dart';
import 'package:nudgee/core/services/app_lifecycle_service.dart';
import 'package:nudgee/core/services/app_update_service.dart';
import 'package:nudgee/core/services/ai_service.dart';
import 'package:nudgee/core/services/agent_service.dart';
import 'package:nudgee/core/services/agent_autonomous_service.dart';
import 'package:nudgee/core/services/agent_permission_service.dart';
import 'package:nudgee/core/services/workspace_service.dart';
import 'package:nudgee/core/services/cloud_sandbox_service.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/services/social_login_service.dart';
import 'package:nudgee/core/services/background_task_service.dart';
import 'package:nudgee/core/services/bluetooth_service.dart';
import 'package:nudgee/core/services/connectivity_service.dart';
import 'package:nudgee/core/services/download_service.dart';
import 'package:nudgee/core/services/file_picker_service.dart';
import 'package:nudgee/core/services/file_storage_service.dart';
import 'package:nudgee/core/services/qiniu_storage_service.dart';
import 'package:nudgee/core/services/chat_service.dart';
import 'package:nudgee/core/services/prompt_template_service.dart';
import 'package:nudgee/core/services/notification_service.dart';
import 'package:nudgee/core/services/post_service.dart';
import 'package:nudgee/core/services/schedule_service.dart';
import 'package:nudgee/core/services/frame_timing_monitor_service.dart';
import 'package:nudgee/core/services/local_database_service.dart';
import 'package:nudgee/core/services/log_file_service.dart';
import 'package:nudgee/core/services/log_reporter_service.dart';
import 'package:nudgee/core/services/logger_service.dart';
import 'package:nudgee/core/services/push_notification_service.dart';
import 'package:nudgee/core/services/secure_storage_service.dart';
import 'package:nudgee/core/services/shared_prefs_service.dart';
import 'package:nudgee/core/services/user_cache_service.dart';
import 'package:nudgee/core/services/user_storage_service.dart';
import 'package:nudgee/core/services/upload_service.dart';

/// Global service locator instance.
final GetIt sl = GetIt.instance;

/// Initialize all core dependencies.
///
/// Must be called once in `main()` before `runApp()`.
/// Each service is registered independently so a failure in one
/// doesn't prevent the rest from loading.
Future<void> initDependencies() async {
  debugPrint('[Init] Starting initDependencies...');

  // ── App Config (load config.yaml) ────────────────────────────────────
  await AppConfig.load();
  debugPrint('[Init] AppConfig loaded (storage: ${AppConfig.hasStorage ? "yes" : "no"}, ai: ${AppConfig.hasAi ? "yes" : "no"})');

  // ── Log File Service (always available) ──────────────────────────────
  _safeRegister(() => sl.registerLazySingleton<LogFileService>(() => LogFileService()));

  // ── Logger (always available) ────────────────────────────────────────
  _safeRegister(() => sl.registerLazySingleton<LoggerService>(
        () => LoggerService(logFileService: sl<LogFileService>()),
      ));
  debugPrint('[Init] Logger registered');

  // ── Secure Storage (may fail on Web) ─────────────────────────────────
  _safeRegister(() => sl.registerLazySingleton<SecureStorageService>(() => SecureStorageService()));
  debugPrint('[Init] SecureStorage registered');

  // ── User Storage (token in SecureStorage, profile in SharedPrefs) ────
  _safeRegister(() => sl.registerLazySingleton<UserStorageService>(
        () => UserStorageService(
          secure: sl<SecureStorageService>(),
          prefs: sl<SharedPrefsService>(),
        ),
      ));
  debugPrint('[Init] UserStorage registered');

  // ── Local Database (Hive) ────────────────────────────────────────────
  try {
    final db = LocalDatabaseService();
    await db.init(preopenBoxes: [
      'user_settings',
      'user_drafts',
      'user_cache',
    ]).timeout(const Duration(seconds: 5));
    sl.registerSingleton<LocalDatabaseService>(db);
    debugPrint('[Init] LocalDatabase OK');

    // User cache service (Hive-backed)
    _safeRegister(() => sl.registerLazySingleton<UserCacheService>(
          () => UserCacheService(sl<LocalDatabaseService>()),
        ));
    debugPrint('[Init] UserCache registered');
  } catch (e) {
    debugPrint('[Init] LocalDatabase init failed (non-fatal): $e');
  }

  // ── Shared Preferences ───────────────────────────────────────────────
  try {
    final sharedPrefs = SharedPrefsService();
    await sharedPrefs.init().timeout(const Duration(seconds: 5));
    sl.registerSingleton<SharedPrefsService>(sharedPrefs);
    debugPrint('[Init] SharedPrefs OK');
  } catch (e) {
    debugPrint('[Init] SharedPrefs init failed, using fallback: $e');
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 5));
      sl.registerSingleton<SharedPreferences>(prefs);
    } catch (e2) {
      debugPrint('[Init] SharedPreferences fallback also failed: $e2');
    }
  }

  // ── Dio ──────────────────────────────────────────────────────────────
  _safeRegister(() {
    sl.registerLazySingleton<Dio>(() {
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: AppConstants.connectTimeout,
          receiveTimeout: AppConstants.receiveTimeout,
          sendTimeout: AppConstants.sendTimeout,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
      );

      dio.interceptors.addAll([
        AuthInterceptor(),
        RetryInterceptor(),
        LoggingInterceptor(),
        ErrorInterceptor(),
        // Runs last so it sees 401s first on the error path (errors traverse
        // interceptors in reverse insertion order) and can retry transparently
        // before ErrorInterceptor converts the failure.
        TokenRefreshInterceptor(),
      ]);

      return dio;
    });
  });

  // ── API Client ───────────────────────────────────────────────────────
  _safeRegister(() => sl.registerLazySingleton<ApiClient>(() => ApiClient(sl<Dio>())));

  // ── Qiniu Cloud Storage (object storage, config from config.yaml) ────
  // Registered before AuthService so it's available as a dependency.
  // Always registered — QiniuStorageService handles missing config gracefully.
  _safeRegister(() => sl.registerLazySingleton<QiniuStorageService>(() => QiniuStorageService()));
  debugPrint('[Init] QiniuStorage registered (configured: ${AppConfig.hasStorage})');

  // ── AI Service (Flutter AI SDK) ──────────────────────────────────────
  _safeRegister(() {
    sl.registerLazySingleton<AiService>(() => AiService());
    sl<AiService>().init();
  });
  debugPrint('[Init] AiService registered (configured: ${AppConfig.hasAi})');

  // ── Agent Permission Service (agent tool permission mode management) ─
  _safeRegister(() {
    sl.registerLazySingleton<AgentPermissionService>(
        () => AgentPermissionService());
  });
  debugPrint('[Init] AgentPermissionService registered');

  // ── Agent Service (Full Agent Stack — AgentCore + Tools) ─────────────
  _safeRegister(() {
    sl.registerLazySingleton<AgentService>(() => AgentService());
    sl<AgentService>().init();
  });
  debugPrint('[Init] AgentService registered');

  // ── Agent Autonomous Service (AI-generated posts) ───────────────────
  _safeRegister(() {
    sl.registerLazySingleton<AgentAutonomousService>(
      () => AgentAutonomousService(sl<AgentService>()),
    );
  });
  debugPrint('[Init] AgentAutonomousService registered');

  // ── Workspace Service (local user workspace for AI code execution) ───
  _safeRegister(() {
    sl.registerLazySingleton<WorkspaceService>(() => WorkspaceService());
    sl<WorkspaceService>().init();
  });
  debugPrint('[Init] WorkspaceService registered');

  // ── Cloud Sandbox Service (remote code execution) ───────────────────
  _safeRegister(() {
    sl.registerLazySingleton<CloudSandboxService>(() {
      final sandboxUrl = AppConfig.sandboxApiBaseUrl;
      return CloudSandboxService(sl<Dio>(), apiBaseUrl: sandboxUrl);
    });
  });
  debugPrint('[Init] CloudSandboxService registered');

  // ── Auth Service (Qiniu-backed, no backend) ──────────────────────────
  _safeRegister(() => sl.registerLazySingleton<AuthService>(
        () => AuthService(
          userStorage: sl<UserStorageService>(),
        ),
      ));

  // ── Social Login Service (stub until native SDKs are configured) ─────
  _safeRegister(() => sl.registerLazySingleton<SocialLoginService>(
        () => StubSocialLoginService(logger: sl<LoggerService>()),
      ));

  // ── Log Reporter Service ─────────────────────────────────────────────
  _safeRegister(() => sl.registerLazySingleton<LogReporterService>(
        () => LogReporterService(apiClient: sl<ApiClient>()),
      ));

  // ── Bluetooth (BLE) ──────────────────────────────────────────────────
  _safeRegister(() => sl.registerLazySingleton<BluetoothService>(() => BluetoothService()));

  // ── File Picker ──────────────────────────────────────────────────────
  _safeRegister(() => sl.registerLazySingleton<FilePickerService>(() => FilePickerService()));

  // ── File Storage (local avatars / cache / downloads) ─────────────────
  _safeRegister(() => sl.registerLazySingleton<FileStorageService>(() => FileStorageService()));

  // ── Schedule Service (local file + Qiniu cloud sync) ─────────────────
  _safeRegister(() => sl.registerLazySingleton<ScheduleService>(
        () => ScheduleService(
          fileStorage: sl<FileStorageService>(),
          qiniu: sl<QiniuStorageService>(),
          prefs: sl<SharedPrefsService>(),
        ),
      ));

  // ── Notification Service (local notifications + reminder sound) ──────
  _safeRegister(() {
    sl.registerLazySingleton<NotificationService>(() => NotificationService());
    sl<NotificationService>().init();
  });

  // ── Post Service (个人圈帖子 — local + Qiniu cloud) ──────────────────
  _safeRegister(() => sl.registerLazySingleton<PostService>(
        () => PostService(
          fileStorage: sl<FileStorageService>(),
          qiniu: sl<QiniuStorageService>(),
          prefs: sl<SharedPrefsService>(),
        ),
      ));

  // ── Chat Service (聊天 — SQLite local + Qiniu cloud) ─────────────────
  _safeRegister(() => sl.registerLazySingleton<ChatService>(
        () => ChatService(
          qiniu: sl<QiniuStorageService>(),
          prefs: sl<SharedPrefsService>(),
        ),
      ));

  // ── Prompt Template Service (提示词模板 — local + Qiniu cloud) ───────
  _safeRegister(() => sl.registerLazySingleton<PromptTemplateService>(
        () => PromptTemplateService(
          fileStorage: sl<FileStorageService>(),
          qiniu: sl<QiniuStorageService>(),
          prefs: sl<SharedPrefsService>(),
        ),
      ));

  // ── Upload Service ───────────────────────────────────────────────────
  _safeRegister(() => sl.registerLazySingleton<UploadService>(
        () => UploadService(sl<ApiClient>()),
      ));

  // ── Download Service ─────────────────────────────────────────────────
  _safeRegister(() => sl.registerLazySingleton<DownloadService>(
        () => DownloadService(sl<ApiClient>()),
      ));

  // ── Analytics ────────────────────────────────────────────────────────
  _safeRegister(() => sl.registerLazySingleton<AnalyticsService>(
        () => AnalyticsService(
          apiClient: sl<ApiClient>(),
          logger: sl<LoggerService>(),
        ),
      ));

  // ── Frame Timing Monitor ─────────────────────────────────────────────
  _safeRegister(() => sl.registerLazySingleton<FrameTimingMonitorService>(
        () => FrameTimingMonitorService(
          analytics: sl<AnalyticsService>(),
          logger: sl<LoggerService>(),
        ),
      ));

  // ── App Update ───────────────────────────────────────────────────────
  _safeRegister(() => sl.registerLazySingleton<AppUpdateService>(
        () => AppUpdateService(
          apiClient: sl<ApiClient>(),
          logger: sl<LoggerService>(),
        ),
      ));

  // ── Push Notifications ───────────────────────────────────────────────
  _safeRegister(() => sl.registerLazySingleton<PushNotificationService>(
        () => PushNotificationService(logger: sl<LoggerService>()),
      ));

  // ── Background Tasks ─────────────────────────────────────────────────
  _safeRegister(() {
    final service = BackgroundTaskService(logger: sl<LoggerService>());
    service.init();
    sl.registerLazySingleton<BackgroundTaskService>(() => service);
  });

  // ── App Lifecycle Service ────────────────────────────────────────────
  _safeRegister(() {
    final service = AppLifecycleService();
    service.init();
    sl.registerSingleton<AppLifecycleService>(service);
  });

  // ── Connectivity Service ─────────────────────────────────────────────
  _safeRegister(() {
    final service = ConnectivityService();
    service.init();
    sl.registerSingleton<ConnectivityService>(service);
  });

  // ── API Cache Service ────────────────────────────────────────────────
  _safeRegister(() => sl.registerLazySingleton<ApiCacheService>(
        () => ApiCacheService(),
      ));

  debugPrint('[Init] initDependencies complete');
}

/// Register a service safely — catches and logs errors without throwing.
void _safeRegister(void Function() registration) {
  try {
    registration();
  } catch (e) {
    debugPrint('DI registration failed: $e');
  }
}

/// Clean up all registered dependencies (useful for testing).
Future<void> resetDependencies() async {
  await sl.reset();
}
