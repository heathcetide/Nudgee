/// App-wide constants.
class AppConstants {
  AppConstants._();

  /// Default HTTP connect timeout.
  static const Duration connectTimeout = Duration(seconds: 15);

  /// Default HTTP receive timeout.
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Default HTTP send timeout.
  static const Duration sendTimeout = Duration(seconds: 15);

  /// WebSocket reconnect interval.
  static const Duration wsReconnectInterval = Duration(seconds: 3);

  /// Max WebSocket reconnect attempts.
  static const int wsMaxReconnectAttempts = 10;

  /// Secure storage keys.
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLocale = 'locale';

  /// Animation durations.
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationMedium = Duration(milliseconds: 350);
  static const Duration durationSlow = Duration(milliseconds: 500);

  /// UI spacing tokens (in logical pixels).
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacingXxl = 48;

  /// UI radius tokens.
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  static const double radiusFull = 999;

  /// UI icon sizes.
  static const double iconSm = 16;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double iconXl = 48;
}
