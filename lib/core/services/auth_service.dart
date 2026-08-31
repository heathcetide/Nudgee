import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'package:nudgee/core/config/app_config.dart';
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
/// User credentials are stored as JSON files on Qiniu:
///   `users/{userId}.json` → { id, name, passwordHash, createdAt }
///
/// Login flow:
///   1. Compute userId from username (SHA-256, first 16 chars)
///   2. Download `users/{userId}.json` from Qiniu CDN
///   3. Compare password hash
///   4. On success, cache session in SecureStorage
///
/// Register flow:
///   1. Check if `users/{userId}.json` already exists (download)
///   2. If not, create user JSON and upload to Qiniu
///   3. Auto-login
class AuthService {
  final SecureStorageService _storage;
  final QiniuStorageService? _qiniu;
  late final Dio _dio;

  static const _keySession = 'local_auth_session';
  static const _keyCurrentUser = 'local_auth_current_user';
  static const _usersPrefix = 'users/';

  /// Whether the user is currently authenticated.
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);

  /// The currently logged-in user, or `null` when logged out / unknown.
  final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);

  String? _accessToken;

  AuthService({
    required SecureStorageService storage,
    QiniuStorageService? qiniu,
  })  : _storage = storage,
        _qiniu = qiniu {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

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

  String _userFileUrl(String userId) {
    final domain = AppConfig.storage?.qiniuDomain ?? '';
    return '$domain/$_usersPrefix$userId.json';
  }

  /// Download user JSON from Qiniu CDN. Returns `null` if not found.
  Future<Map<String, dynamic>?> _fetchUser(String userId) async {
    try {
      final url = _userFileUrl(userId);
      final response = await _dio.get<dynamic>(url);
      if (response.statusCode != 200) return null;
      final data = response.data;
      if (data is String) {
        return jsonDecode(data) as Map<String, dynamic>;
      } else if (data is Map) {
        return data.cast<String, dynamic>();
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      debugPrint('[Auth] Fetch user error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[Auth] Fetch user error: $e');
      return null;
    }
  }

  /// Upload user JSON to Qiniu.
  Future<bool> _uploadUser(Map<String, dynamic> userJson) async {
    if (_qiniu == null) {
      debugPrint('[Auth] QiniuStorage not available — cannot upload user');
      return false;
    }
    try {
      final key = '$_usersPrefix${userJson['id']}.json';
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(userJson)));
      final url = await _qiniu!.uploadBytes(key, bytes);
      return url != null;
    } catch (e) {
      debugPrint('[Auth] Upload user error: $e');
      return false;
    }
  }

  // ── Auth actions ─────────────────────────────────────────────────────

  /// Registers a new account with [username] and [password].
  Future<bool> register({
    required String username,
    required String password,
  }) async {
    try {
      final userId = _userId(username);

      // Check if user already exists
      final existing = await _fetchUser(userId);
      if (existing != null) {
        debugPrint('[Auth] Register failed — user already exists');
        return false;
      }

      // Create user JSON
      final userJson = {
        'id': userId,
        'name': username,
        'passwordHash': _hashPassword(password),
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Upload to Qiniu
      final uploaded = await _uploadUser(userJson);
      if (!uploaded) {
        debugPrint('[Auth] Register failed — upload error');
        return false;
      }

      // Auto-login
      return _doLogin(username, password);
    } catch (e) {
      debugPrint('[Auth] Register error: $e');
      return false;
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
        debugPrint('[Auth] Login failed — user not found');
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
