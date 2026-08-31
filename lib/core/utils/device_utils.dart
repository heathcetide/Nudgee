import 'dart:io';

import 'package:flutter/foundation.dart';

/// Device / platform information utilities.
///
/// Uses only `dart:io` [Platform] and `kIsWeb` — no extra dependencies.
/// Platform-specific getters (`isAndroid`, …) are synchronous; the
/// `Future`-returning getters (`getDeviceId`, …) provide best-effort
/// values where native plugins are unavailable in this build.
class LingDeviceUtils {
  LingDeviceUtils._();

  // ── Synchronous platform checks ──────────────────────────────────────

  /// Whether the app is running on Android.
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Whether the app is running on iOS.
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Whether the app is running on the Web.
  static bool get isWeb => kIsWeb;

  /// Whether the app is running on a desktop OS (macOS / Windows / Linux).
  static bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  // ── Async info getters ───────────────────────────────────────────────

  /// Current platform name: `android` / `ios` / `macos` / `windows` /
  /// `linux` / `web`.
  static Future<String> getPlatform() async {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Best-effort device identifier.
  ///
  /// Without `device_info_plus` we cannot read a stable hardware id, so
  /// this returns a synthetic value derived from the platform + hostname
  /// (desktop) or `'unknown'` (mobile). Replace once the plugin is restored.
  static Future<String> getDeviceId() async {
    if (kIsWeb) return 'web';
    try {
      final platform = await getPlatform();
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final host = Platform.environment['HOSTNAME'] ??
            Platform.environment['COMPUTERNAME'] ??
            'localhost';
        return '$platform-$host';
      }
      return platform;
    } catch (_) {
      return 'unknown';
    }
  }

  /// Human-readable device name (best-effort).
  static Future<String> getDeviceName() async {
    if (kIsWeb) return 'Web Browser';
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iOS Device';
    if (Platform.isMacOS) return 'Mac';
    if (Platform.isWindows) return 'Windows PC';
    if (Platform.isLinux) return 'Linux Machine';
    return 'Unknown Device';
  }

  /// OS version string.
  static Future<String> getSystemVersion() async {
    if (kIsWeb) return 'web';
    return Platform.operatingSystemVersion;
  }

  /// App version. Without a packaging plugin we read the
  /// `APP_VERSION` env var if present, otherwise `'1.0.0'`.
  static Future<String> getAppVersion() async {
    return Platform.environment['APP_VERSION'] ?? '1.0.0';
  }

  /// Build number. Reads `BUILD_NUMBER` env var if present, otherwise `'1'`.
  static Future<String> getBuildNumber() async {
    return Platform.environment['BUILD_NUMBER'] ?? '1';
  }

  /// Aggregate all available info into a single map.
  static Future<Map<String, String>> getAllInfo() async {
    return {
      'platform': await getPlatform(),
      'deviceId': await getDeviceId(),
      'deviceName': await getDeviceName(),
      'systemVersion': await getSystemVersion(),
      'appVersion': await getAppVersion(),
      'buildNumber': await getBuildNumber(),
    };
  }
}
