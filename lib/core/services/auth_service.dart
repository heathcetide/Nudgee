import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:nudgee/core/errors/app_exception.dart';
import 'package:nudgee/core/network/api_client.dart';
import 'package:nudgee/core/network/api_response.dart';
import 'package:nudgee/core/services/logger_service.dart';
import 'package:nudgee/core/services/secure_storage_service.dart';

/// Lightweight representation of the authenticated user.
class AuthUser {
  final String id;
  final String name;
  final String? avatar;
  final String? email;
  final String? phone;

  const AuthUser({
    required this.id,
    required this.name,
    this.avatar,
    this.email,
    this.phone,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'email': email,
        'phone': phone,
      };

  @override
  String toString() =>
      'AuthUser(id: $id, name: $name, email: $email, phone: $phone)';
}

/// Central authentication service.
///
/// Owns token persistence, the refresh flow, and reactive auth state that the
/// UI can observe via [ValueListenable]s. Implements the `isAuthenticated`
/// contract consumed by [RouteGuard].
class AuthService {
  final SecureStorageService _storage;
  final ApiClient _api;
  final LoggerService _logger;

  /// Whether the user is currently authenticated (has a non-empty access token).
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);

  /// The currently logged-in user, or `null` when logged out / unknown.
  final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);

  /// Cached access token (also persisted in secure storage).
  String? _accessToken;

  /// Cached refresh token (also persisted in secure storage).
  String? _refreshToken;

  AuthService({
    required SecureStorageService storage,
    required ApiClient api,
    required LoggerService logger,
  })  : _storage = storage,
        _api = api,
        _logger = logger;

  // ── Public getters ───────────────────────────────────────────────────

  /// The current access token, or `null` when not authenticated.
  String? get accessToken => _accessToken;

  /// The current refresh token, or `null` when not authenticated.
  String? get refreshToken => _refreshToken;

  // ── Auth actions ─────────────────────────────────────────────────────

  /// Logs in with [username] and [password].
  ///
  /// Returns `true` on success. Tokens and user info are persisted and the
  /// [isAuthenticated] / [currentUser] notifiers are updated.
  Future<bool> login(String username, String password) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
        },
        options: Options(extra: {'skipTokenRefresh': true}),
      );

      final body = response.data ?? const <String, dynamic>{};
      final apiResponse = ApiResponse.fromJson(
        body,
        fromJsonT: (raw) =>
            raw is Map<String, dynamic> ? raw : <String, dynamic>{},
      );

      if (!apiResponse.success) {
        _logger.w('Login failed: ${apiResponse.message}', tag: 'auth');
        return false;
      }

      final data = (apiResponse.data ?? const <String, dynamic>{});
      final access = data['access_token'] as String? ??
          data['accessToken'] as String?;
      final refresh = data['refresh_token'] as String? ??
          data['refreshToken'] as String?;

      if (access == null || access.isEmpty) {
        _logger.w('Login response missing access token', tag: 'auth');
        return false;
      }

      await _persistTokens(access: access, refresh: refresh ?? '');

      final user = data['user'] is Map<String, dynamic>
          ? AuthUser.fromJson(data['user'] as Map<String, dynamic>)
          : AuthUser(id: data['user_id']?.toString() ?? '', name: username);

      currentUser.value = user;
      isAuthenticated.value = true;

      return true;
    } on AppException catch (e) {
      _logger.e('Login error: ${e.message}', error: e, tag: 'auth');
      return false;
    } catch (e, st) {
      _logger.e('Login error', error: e, stackTrace: st, tag: 'auth');
      return false;
    }
  }

  /// Registers a new account with [username], [password], and optional [email].
  ///
  /// Returns `true` on success. On success, tokens and user info are persisted
  /// and the [isAuthenticated] / [currentUser] notifiers are updated.
  Future<bool> register({
    required String username,
    required String password,
    String? email,
  }) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'username': username,
          'password': password,
          if (email != null && email.isNotEmpty) 'email': email,
        },
        options: Options(extra: {'skipTokenRefresh': true}),
      );

      final body = response.data ?? const <String, dynamic>{};
      final apiResponse = ApiResponse.fromJson(
        body,
        fromJsonT: (raw) =>
            raw is Map<String, dynamic> ? raw : <String, dynamic>{},
      );

      if (!apiResponse.success) {
        _logger.w('Register failed: ${apiResponse.message}', tag: 'auth');
        return false;
      }

      final data = (apiResponse.data ?? const <String, dynamic>{});
      final access = data['access_token'] as String? ??
          data['accessToken'] as String?;
      final refresh = data['refresh_token'] as String? ??
          data['refreshToken'] as String?;

      if (access == null || access.isEmpty) {
        // Some backends don't return tokens on register — try auto-login.
        _logger.d('Register response missing token, attempting auto-login', tag: 'auth');
        return login(username, password);
      }

      await _persistTokens(access: access, refresh: refresh ?? '');

      final user = data['user'] is Map<String, dynamic>
          ? AuthUser.fromJson(data['user'] as Map<String, dynamic>)
          : AuthUser(id: data['user_id']?.toString() ?? '', name: username, email: email);

      currentUser.value = user;
      isAuthenticated.value = true;

      return true;
    } on AppException catch (e) {
      _logger.e('Register error: ${e.message}', error: e, tag: 'auth');
      return false;
    } catch (e, st) {
      _logger.e('Register error', error: e, stackTrace: st, tag: 'auth');
      return false;
    }
  }

  /// Logs out, clears local tokens and resets auth state.
  ///
  /// Best-effort notifies the server; network failures are ignored.
  Future<void> logout() async {
    try {
      await _api.post<void>(
        '/auth/logout',
        options: Options(extra: {'skipTokenRefresh': true}),
      );
    } catch (e) {
      // Ignore — we clear locally regardless.
      _logger.d('Logout request failed (ignored): $e', tag: 'auth');
    }

    await clearTokens();
    currentUser.value = null;
    isAuthenticated.value = false;
  }

  /// Refreshes the access token using the stored refresh token.
  ///
  /// Returns `true` on success. On failure the tokens are cleared and the
  /// auth state is reset.
  Future<bool> refreshAccessToken() async {
    final refresh = _refreshToken ?? await _storage.getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      _logger.w('No refresh token available — clearing session', tag: 'auth');
      await clearTokens();
      return false;
    }

    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(extra: {'skipTokenRefresh': true}),
      );

      final body = response.data ?? const <String, dynamic>{};
      final apiResponse = ApiResponse.fromJson(
        body,
        fromJsonT: (raw) =>
            raw is Map<String, dynamic> ? raw : <String, dynamic>{},
      );

      if (!apiResponse.success) {
        _logger.w('Token refresh rejected: ${apiResponse.message}', tag: 'auth');
        await clearTokens();
        return false;
      }

      final data = (apiResponse.data ?? const <String, dynamic>{});
      final access = data['access_token'] as String? ??
          data['accessToken'] as String?;
      final newRefresh = data['refresh_token'] as String? ??
          data['refreshToken'] as String?;

      if (access == null || access.isEmpty) {
        _logger.w('Refresh response missing access token', tag: 'auth');
        await clearTokens();
        return false;
      }

      await _persistTokens(
        access: access,
        refresh: newRefresh ?? refresh,
      );

      return true;
    } on AppException catch (e) {
      _logger.e('Token refresh failed: ${e.message}', error: e, tag: 'auth');
      await clearTokens();
      return false;
    } catch (e, st) {
      _logger.e('Token refresh failed', error: e, stackTrace: st, tag: 'auth');
      await clearTokens();
      return false;
    }
  }

  /// Checks persisted tokens and hydrates the in-memory auth state.
  ///
  /// Call once at app startup to restore a previous session.
  Future<bool> checkAuthStatus() async {
    final access = await _storage.getAccessToken();
    final refresh = await _storage.getRefreshToken();

    if (access == null || access.isEmpty) {
      isAuthenticated.value = false;
      currentUser.value = null;
      return false;
    }

    _accessToken = access;
    _refreshToken = refresh;
    isAuthenticated.value = true;

    // Optionally fetch the current user profile.
    try {
      final response = await _api.get<Map<String, dynamic>>('/auth/me');
      final body = response.data ?? const <String, dynamic>{};
      final apiResponse = ApiResponse.fromJson(
        body,
        fromJsonT: (raw) =>
            raw is Map<String, dynamic> ? raw : <String, dynamic>{},
      );
      if (apiResponse.data != null) {
        currentUser.value = AuthUser.fromJson(apiResponse.data!);
      }
    } catch (e) {
      // Profile fetch is best-effort; we're still authenticated by token.
      _logger.d('Profile fetch failed (ignored): $e', tag: 'auth');
    }

    return true;
  }

  /// Clears all stored tokens and resets auth state.
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    isAuthenticated.value = false;
    currentUser.value = null;
    try {
      await _storage.clearAll();
    } catch (e) {
      _logger.w('Failed to clear storage: $e', tag: 'auth');
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────

  Future<void> _persistTokens({
    required String access,
    required String refresh,
  }) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _storage.saveAccessToken(access);
    await _storage.saveRefreshToken(refresh);
    isAuthenticated.value = true;
  }
}
