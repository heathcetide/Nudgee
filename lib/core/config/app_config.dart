/// Application environment configuration.
///
/// Values are injected at compile time via `--dart-define`.
/// Example:
/// ```sh
/// flutter run --dart-define=ENV=dev --dart-define=API_BASE_URL=http://...
/// ```
class AppConfig {
  AppConfig._();

  /// Current environment: `dev` | `staging` | `prod`
  static const String env = String.fromEnvironment('ENV', defaultValue: 'dev');

  /// API base URL for the Go control/signaling plane.
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

  /// WebSocket signaling URL.
  static const String wsUrl =
      String.fromEnvironment('WS_URL', defaultValue: 'ws://localhost:8080/ws');

  /// WebRTC ICE servers (comma-separated STUN/TURN URLs).
  static const String iceServers = String.fromEnvironment(
    'ICE_SERVERS',
    defaultValue: 'stun:stun.l.google.com:19302',
  );

  /// App name shown in UI.
  static const String appName = String.fromEnvironment('APP_NAME', defaultValue: 'Nudgee');

  /// App version.
  static const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  // ── Environment helpers ──────────────────────────────────────────────

  static bool get isDev => env == 'dev';
  static bool get isStaging => env == 'staging';
  static bool get isProd => env == 'prod';

  /// Whether verbose logging should be enabled.
  static bool get enableVerboseLogging => !isProd;

  /// Parsed list of ICE server URLs.
  static List<String> get iceServerList =>
      iceServers.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}
