import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'package:nudgee/core/config/app_config.dart';
import 'package:nudgee/core/di/injector.dart' as di;
import 'package:nudgee/core/services/qiniu_storage_service.dart';
import 'package:nudgee/core/services/user_cache_service.dart';
import 'package:nudgee/core/services/user_storage_service.dart';

/// Lightweight representation of the authenticated user.
class AuthUser {
  final String id;
  final String name;
  final String? avatar;

  const AuthUser({
    required this.id,
    required this.name,
    this.avatar,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
      };

  @override
  String toString() => 'AuthUser(id: $id, name: $name)';
}

/// Authentication service backed by Qiniu object storage.
///
/// Storage layout:
///   **Cloud (Qiniu)**: `nudgee/{userId}/profile.json` — full profile + passwordHash
///   **Local (SecureStorage)**: token, userId — sensitive, encrypted
///   **Local (SharedPreferences)**: user profile JSON — fast read for UI
///
/// Register: check Qiniu → upload profile → save local session → auto-login
/// Login: download from Qiniu → verify password → save local session
/// Restore: read local session on app startup
class AuthService {
  final UserStorageService _userStorage;
  QiniuStorageService? _qiniu;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 10),
    responseType: ResponseType.plain,
  ));

  static const _appPrefix = 'nudgee';

  /// Whether the user is currently authenticated.
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);

  /// The currently logged-in user, or `null` when logged out / unknown.
  final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);

  String? _accessToken;

  AuthService({required UserStorageService userStorage})
      : _userStorage = userStorage {
    // Try to resolve QiniuStorageService from DI
    try {
      _qiniu = di.sl<QiniuStorageService>();
    } catch (_) {
      // Will be resolved lazily in _uploadUser
    }
  }

  // ── Public getters ───────────────────────────────────────────────────

  String? get accessToken => _accessToken;

  /// Fetch user profile from Qiniu CDN by [userId].
  /// Public wrapper around [_fetchUser] for use by other services/pages.
  Future<Map<String, dynamic>?> fetchUserProfile(String userId) =>
      _fetchUser(userId);

  // ── Helpers ──────────────────────────────────────────────────────────

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  String _userId(String username) {
    return sha256
        .convert(utf8.encode(username.toLowerCase()))
        .toString()
        .substring(0, 16);
  }

  /// Storage key for a user's profile: `nudgee/{userId}/profile.json`
  String _profileKey(String userId) => '$_appPrefix/$userId/profile.json';

  /// CDN URL for a user's profile.
  String _profileUrl(String userId) {
    final domain = AppConfig.storage?.qiniuDomain ?? '';
    return '$domain/${_profileKey(userId)}';
  }

  /// Download user profile from Qiniu CDN.
  ///
  /// Returns the parsed JSON if the file exists AND has a `passwordHash`
  /// field. Returns `null` if not found or invalid.
  Future<Map<String, dynamic>?> _fetchUser(String userId) async {
    try {
      final url = _profileUrl(userId);
      debugPrint('[Auth] Fetching user: $url');
      final response = await _dio.get<String>(url);

      if (response.statusCode != 200) {
        debugPrint('[Auth] Fetch user — status ${response.statusCode}');
        return null;
      }

      final body = response.data ?? '';
      if (body.isEmpty) {
        debugPrint('[Auth] Fetch user — empty response');
        return null;
      }

      // Parse JSON — if this fails, it's a CDN error page, not a user file
      Map<String, dynamic> json;
      try {
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          debugPrint('[Auth] Fetch user — response is not a JSON object');
          return null;
        }
        json = decoded;
      } catch (e) {
        debugPrint('[Auth] Fetch user — not valid JSON (CDN error page?)');
        return null;
      }

      // Validate: must have passwordHash to be a real user profile
      if (!json.containsKey('passwordHash')) {
        debugPrint('[Auth] Fetch user — missing passwordHash field');
        return null;
      }

      return json;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        debugPrint('[Auth] Fetch user — 404 not found (new user)');
        return null;
      }
      debugPrint('[Auth] Fetch user error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[Auth] Fetch user error: $e');
      return null;
    }
  }

  /// Upload user profile JSON to Qiniu.
  /// Returns (success, errorMessage).
  Future<(bool, String?)> _uploadUser(Map<String, dynamic> userJson) async {
    // Resolve QiniuStorageService — try cached instance first, then GetIt
    QiniuStorageService? qiniu = _qiniu;
    if (qiniu == null) {
      try {
        qiniu = di.sl<QiniuStorageService>();
        _qiniu = qiniu; // cache for next time
        debugPrint('[Auth] Resolved QiniuStorage from GetIt');
      } catch (e) {
        debugPrint('[Auth] QiniuStorage not in GetIt: $e');
      }
    }
    if (qiniu == null) {
      return (false, 'QiniuStorage 未注册');
    }
    if (!qiniu.isConfigured) {
      return (false, '七牛配置为空（config.yaml 未加载）');
    }
    try {
      final key = _profileKey(userJson['id'] as String);
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(userJson)));
      debugPrint('[Auth] Uploading user profile: $key');
      final url = await qiniu.uploadBytes(key, bytes);
      if (url != null) {
        debugPrint('[Auth] Upload success: $url');
        return (true, null);
      }
      return (false, '七牛上传返回 null（查看 QiniuStorage 日志）');
    } catch (e) {
      debugPrint('[Auth] Upload user error: $e');
      return (false, '上传异常: $e');
    }
  }

  /// Save session to local storage (token + userId + profile).
  Future<void> _saveLocalSession({
    required String token,
    required String userId,
    required Map<String, dynamic> profile,
  }) async {
    await _userStorage.saveSession(
      token: token,
      userId: userId,
      profile: profile,
    );
    debugPrint('[Auth] Local session saved (token + userId + profile)');
  }

  // ── Auth actions ─────────────────────────────────────────────────────

  /// Registers a new account with [username] and [password].
  ///
  /// Returns `(true, null)` on success, `(false, errorMessage)` on failure.
  Future<(bool, String?)> register({
    required String username,
    required String password,
  }) async {
    try {
      final userId = _userId(username);

      if (!AppConfig.hasStorage) {
        debugPrint('[Auth] Register failed — no storage config');
        return (false, '存储配置未加载，请检查 config.yaml');
      }

      // Check if user already exists
      final existing = await _fetchUser(userId);
      if (existing != null) {
        debugPrint('[Auth] Register failed — user "$username" already exists');
        return (false, '用户名已存在');
      }

      // Create user profile JSON
      final userJson = {
        'id': userId,
        'name': username,
        'passwordHash': _hashPassword(password),
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Upload to Qiniu (cloud)
      final (uploaded, uploadError) = await _uploadUser(userJson);
      if (!uploaded) {
        debugPrint('[Auth] Register failed — upload error: $uploadError');
        return (false, uploadError ?? '上传到七牛失败');
      }

      // Save local session
      final sessionToken = _hashPassword(
          '$username:${DateTime.now().millisecondsSinceEpoch}');
      _accessToken = sessionToken;

      final authUser = AuthUser(
        id: userId,
        name: username,
      );

      await _saveLocalSession(
        token: sessionToken,
        userId: userId,
        profile: authUser.toJson(),
      );

      currentUser.value = authUser;
      isAuthenticated.value = true;

      debugPrint('[Auth] Register + login success — ${authUser.name}');
      return (true, null);
    } catch (e) {
      debugPrint('[Auth] Register error: $e');
      return (false, '注册异常: $e');
    }
  }

  /// Logs in with [username] and [password].
  Future<bool> login(String username, String password) async {
    try {
      final userId = _userId(username);
      final userJson = await _fetchUser(userId);
      if (userJson == null) {
        debugPrint('[Auth] Login failed — user "$username" not found');
        return false;
      }

      final storedHash = userJson['passwordHash'] as String?;
      if (storedHash == null || storedHash != _hashPassword(password)) {
        debugPrint('[Auth] Login failed — wrong password');
        return false;
      }

      // Create session
      final sessionToken = _hashPassword(
          '$username:${DateTime.now().millisecondsSinceEpoch}');
      _accessToken = sessionToken;

      final authUser = AuthUser(
        id: userJson['id'] as String? ?? userId,
        name: userJson['name'] as String? ?? username,
        avatar: userJson['avatar'] as String?,
      );

      // Save to local storage (token in SecureStorage, profile in SharedPrefs)
      await _saveLocalSession(
        token: sessionToken,
        userId: userId,
        profile: authUser.toJson(),
      );

      currentUser.value = authUser;
      isAuthenticated.value = true;
      debugPrint('[Auth] Login success — ${authUser.name}');
      return true;
    } catch (e) {
      debugPrint('[Auth] Login error: $e');
      return false;
    }
  }

  /// Logs out, clears local session.
  Future<void> logout() async {
    // Clear user-specific Hive cache (settings, drafts, offline data)
    final user = currentUser.value;
    if (user != null) {
      try {
        final cache = di.sl<UserCacheService>();
        await cache.clearAllForUser(user.id);
      } catch (e) {
        debugPrint('[Auth] Logout — clear user cache failed: $e');
      }
    }

    _accessToken = null;
    await _userStorage.clearAll();
    currentUser.value = null;
    isAuthenticated.value = false;
    debugPrint('[Auth] Logout — local session + cache cleared');
  }

  /// Checks persisted session and hydrates the in-memory auth state.
  ///
  /// Called at app startup to restore a previous session.
  Future<bool> checkAuthStatus() async {
    try {
      final token = await _userStorage.getToken();
      if (token == null || token.isEmpty) {
        isAuthenticated.value = false;
        currentUser.value = null;
        return false;
      }

      _accessToken = token;

      // Load profile from SharedPreferences (fast, non-sensitive)
      final profile = _userStorage.getProfile();
      if (profile != null) {
        currentUser.value = AuthUser.fromJson(profile);
        isAuthenticated.value = true;
        debugPrint('[Auth] Session restored — ${currentUser.value?.name}');
        return true;
      }

      // No profile locally — need to re-login
      isAuthenticated.value = false;
      currentUser.value = null;
      return false;
    } catch (e) {
      debugPrint('[Auth] Check auth status error: $e');
      isAuthenticated.value = false;
      currentUser.value = null;
      return false;
    }
  }

  /// Clears all stored auth data.
  Future<void> clearTokens() async {
    _accessToken = null;
    isAuthenticated.value = false;
    currentUser.value = null;
    await _userStorage.clearAll();
  }
}
