import 'dart:async';

import 'package:nudgee/core/services/logger_service.dart';

/// Result of a social login attempt.
class SocialLoginResult {
  /// The OAuth authorization code to send to the backend.
  final String? code;

  /// Error message if the login failed.
  final String? error;

  /// Whether the user cancelled the login.
  final bool cancelled;

  bool get isSuccess => code != null && error == null && !cancelled;

  const SocialLoginResult({this.code, this.error, this.cancelled = false});
}

/// Abstract social login service.
///
/// Provides a unified interface for WeChat, QQ, and other OAuth providers.
/// The actual native SDK integration (fluwx, tencent_qq) is plugged in
/// via platform-specific implementations registered in [GetIt].
///
/// Until native SDKs are configured, the default implementation returns
/// a "not configured" error so the UI can gracefully inform the user.
abstract class SocialLoginService {
  /// Whether the WeChat SDK is installed & configured on this device.
  bool get isWechatAvailable;

  /// Whether the QQ SDK is installed & configured on this device.
  bool get isQqAvailable;

  /// Initiates WeChat OAuth login.
  ///
  /// On success, returns a [SocialLoginResult] with the authorization [code].
  /// The caller should pass this code to [AuthService.loginWithWechat].
  Future<SocialLoginResult> loginWithWechat();

  /// Initiates QQ OAuth login.
  ///
  /// On success, returns a [SocialLoginResult] with the authorization [code].
  /// The caller should pass this code to [AuthService.loginWithQq].
  Future<SocialLoginResult> loginWithQq();
}

/// Default stub implementation that returns "not configured" errors.
///
/// Replace with a real implementation once native SDKs (fluwx, tencent_qq)
/// are added to the project and configured for each platform.
class StubSocialLoginService implements SocialLoginService {
  final LoggerService _logger;

  StubSocialLoginService({required LoggerService logger}) : _logger = logger;

  @override
  bool get isWechatAvailable => false;

  @override
  bool get isQqAvailable => false;

  @override
  Future<SocialLoginResult> loginWithWechat() async {
    _logger.w('WeChat login not configured — install fluwx and register a real SocialLoginService', tag: 'social');
    return const SocialLoginResult(error: 'WeChat login is not configured');
  }

  @override
  Future<SocialLoginResult> loginWithQq() async {
    _logger.w('QQ login not configured — install tencent SDK and register a real SocialLoginService', tag: 'social');
    return const SocialLoginResult(error: 'QQ login is not configured');
  }
}
