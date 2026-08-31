import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'package:nudgee/core/config/app_config.dart';
import 'package:nudgee/core/di/injector.dart' as di;
import 'package:nudgee/core/services/qiniu_storage_service.dart';
import 'package:nudgee/core/services/secure_storage_service.dart';

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
/// Storage structure (tenant-style, one folder per user):
///   nudgee/{userId}/profile.json  → { id, name, passwordHash, createdAt, avatar }
///   nudgee/{userId}/data/...      → user data files
///
/// Login flow:
///   1. Compute userId from username (SHA-256, first 16 chars)
///   2. GET `nudgee/{userId}/profile.json` from Qiniu CDN
///   3. Validate response is real user JSON (has passwordHash field)
///   4. Compare password hash
///   5. On success, cache session in SecureStorage
///
/// Register flow:
///   1. Check if `nudgee/{userId}/profile.json` already exists
///   2. If not, create profile JSON and upload to Qiniu
///   3. Auto-login
class AuthService {
  final SecureStorageService _storage;
  final QiniuStorageService? _qiniu;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 10),
    responseType: ResponseType.plain,
  ));

  static const _keySession = 'local_auth_session';
  static const _keyCurrentUser = 'local_auth_current_user';
  static const _appPrefix = 'nudgee';

  /// Whether the user is currently authenticated.
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);

  /// The currently logged-in user, or `null` when logged out / unknown.
  final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);

  String? _accessToken;

  AuthService({
    required SecureStorageService storage,
    QiniuStorageService? qiniu,
  })  : _storage = storage,
        _qiniu = qiniu;

  // ── Public getters ───────────────────────────────────────────────────

  String? get accessToken => _accessToken;

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
  /// field (validating it's a real user file, not a CDN error page).
  /// Returns `null` if not found or invalid.
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
      // 404 = user not found (normal for registration)
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
    // Resolve QiniuStorageService — try injected instance first,
    // then fall back to GetIt (handles hot-reload where DI wasn't re-run).
    QiniuStorageService? qiniu = _qiniu;
    if (qiniu == null) {
      try {
        qiniu = di.sl<QiniuStorageService>();
        debugPrint('[Auth] Resolved QiniuStorage from GetIt fallback');
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

      // Check if Qiniu is configured
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

      // Upload to Qiniu
      final (uploaded, uploadError) = await _uploadUser(userJson);
      if (!uploaded) {
        debugPrint('[Auth] Register failed — upload error: $uploadError');
        return (false, uploadError ?? '上传到七牛失败');
      }

      // Auto-login
      debugPrint('[Auth] Register success — auto-logging in');
      final loginOk = await _doLogin(username, password);
      if (!loginOk) {
        return (false, '注册成功但自动登录失败');
      }
      return (true, null);
    } catch (e) {
      debugPrint('[Auth] Register error: $e');
      return (false, '注册异常: $e');
    }
  }

  /// Logs in with [username] and [password].
  Future<bool> login(String username, String password) async {
    return _doLogin(username, password);
  }

  Future<bool> _doLogin(String username, String password) async {
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
      await _storage.write(key: _keySession, value: sessionToken);

      final authUser = AuthUser(
        id: userJson['id'] as String? ?? userId,
        name: userJson['name'] as String? ?? username,
        avatar: userJson['avatar'] as String?,
      );
      await _storage.write(
          key: _keyCurrentUser, value: jsonEncode(authUser.toJson()));

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
    _accessToken = null;
    await _storage.delete(key: _keySession);
    await _storage.delete(key: _keyCurrentUser);
    currentUser.value = null;
    isAuthenticated.value = false;
  }

  /// Checks persisted session and hydrates the in-memory auth state.
  Future<bool> checkAuthStatus() async {
    try {
      final session = await _storage.read(key: _keySession);
      final userJson = await _storage.read(key: _keyCurrentUser);

      if (session == null || session.isEmpty || userJson == null) {
        isAuthenticated.value = false;
        currentUser.value = null;
        return false;
      }

      _accessToken = session;
      currentUser.value =
          AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      isAuthenticated.value = true;
      return true;
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
    try {
      await _storage.delete(key: _keySession);
      await _storage.delete(key: _keyCurrentUser);
    } catch (_) {}
  }
}
