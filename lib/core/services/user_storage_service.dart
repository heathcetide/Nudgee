import 'dart:convert';

import 'package:nudgee/core/services/secure_storage_service.dart';
import 'package:nudgee/core/services/shared_prefs_service.dart';

/// Local persistence layer for user session and profile data.
///
/// Storage strategy:
/// - **SecureStorage** (keychain/keystore): token, userId — sensitive data
/// - **SharedPreferences**: user profile JSON (name, avatar, etc.) — non-sensitive,
///   fast read for UI display
/// - **Qiniu (cloud)**: full user profile + business data — cross-device sync
///
/// This service is the single source of truth for local user state.
/// AuthService delegates persistence here.
class UserStorageService {
  final SecureStorageService _secure;
  final SharedPrefsService _prefs;

  static const _keyToken = 'nudgee_token';
  static const _keyUserId = 'nudgee_user_id';
  static const _keyUserProfile = 'nudgee_user_profile';
  static const _keyLoginTime = 'nudgee_login_time';

  UserStorageService({
    required SecureStorageService secure,
    required SharedPrefsService prefs,
  })  : _secure = secure,
        _prefs = prefs;

  // ── Token (SecureStorage) ─────────────────────────────────────────────

  Future<void> saveToken(String token) =>
      _secure.write(key: _keyToken, value: token);

  Future<String?> getToken() => _secure.read(key: _keyToken);

  Future<void> clearToken() => _secure.delete(key: _keyToken);

  // ── User ID (SecureStorage) ───────────────────────────────────────────

  Future<void> saveUserId(String userId) =>
      _secure.write(key: _keyUserId, value: userId);

  Future<String?> getUserId() => _secure.read(key: _keyUserId);

  Future<void> clearUserId() => _secure.delete(key: _keyUserId);

  // ── User Profile (SharedPreferences) ──────────────────────────────────

  /// Save user profile JSON to SharedPreferences.
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    await _prefs.setString(_keyUserProfile, jsonEncode(profile));
  }

  /// Load user profile JSON from SharedPreferences.
  Map<String, dynamic>? getProfile() {
    final raw = _prefs.getString(_keyUserProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearProfile() => _prefs.remove(_keyUserProfile);

  // ── Login time (SharedPreferences) ────────────────────────────────────

  Future<void> saveLoginTime(DateTime time) =>
      _prefs.setInt(_keyLoginTime, time.millisecondsSinceEpoch);

  DateTime? getLoginTime() {
    final ms = _prefs.getInt(_keyLoginTime);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> clearLoginTime() => _prefs.remove(_keyLoginTime);

  // ── Bulk operations ───────────────────────────────────────────────────

  /// Save all session data at once (after login/register).
  Future<void> saveSession({
    required String token,
    required String userId,
    required Map<String, dynamic> profile,
  }) async {
    await Future.wait([
      saveToken(token),
      saveUserId(userId),
      saveProfile(profile),
      saveLoginTime(DateTime.now()),
    ]);
  }

  /// Clear all local user data (on logout).
  Future<void> clearAll() async {
    await Future.wait([
      clearToken(),
      clearUserId(),
      clearProfile(),
      clearLoginTime(),
    ]);
  }

  /// Check if user has a persisted session.
  Future<bool> hasSession() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
