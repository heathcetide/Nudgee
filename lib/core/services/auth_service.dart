import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:nudgee/core/services/secure_storage_service.dart';

/// Lightweight representation of the authenticated user.
class AuthUser {
  final String id;
  final String name;
  final String? avatar;
  final String? email;

  const AuthUser({
    required this.id,
    required this.name,
    this.avatar,
    this.email,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'email': email,
      };

  @override
  String toString() => 'AuthUser(id: $id, name: $name, email: $email)';
}

/// Local-only authentication service.
///
/// No backend required — credentials are stored encrypted in
/// [SecureStorageService]. Registration creates a local account, login
/// verifies against stored credentials. User data can later be synced to
/// object storage (Qiniu/S3) for cross-device access.
///
/// Security note: this is client-side only. It prevents casual access but
/// is NOT as secure as server-side auth. For sensitive data, add a backend
/// or use Supabase Auth later.
class AuthService {
  final SecureStorageService _storage;

  static const _keyUserList = 'local_auth_users';
  static const _keyCurrentUser = 'local_auth_current_user';
  static const _keySession = 'local_auth_session';

  /// Whether the user is currently authenticated.
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);

  /// The currently logged-in user, or `null` when logged out / unknown.
  final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);

  AuthService({required SecureStorageService storage}) : _storage = storage;

  // ── Public getters ───────────────────────────────────────────────────

  /// The current session token (a local hash), or `null` when not authenticated.
  String? get accessToken => _accessToken;
  String? _accessToken;

  // ── Helpers ──────────────────────────────────────────────────────────

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  String _userId(String username) {
    return sha256.convert(utf8.encode(username.toLowerCase())).toString().substring(0, 16);
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final raw = await _storage.read(key: _keyUserList);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveUsers(List<Map<String, dynamic>> users) async {
    await _storage.write(key: _keyUserList, value: jsonEncode(users));
  }

  // ── Auth actions ─────────────────────────────────────────────────────

  /// Registers a new local account with [username], [password], and [email].
  ///
  /// Returns `true` on success. Credentials are stored encrypted locally.
  Future<bool> register({
    required String username,
    required String password,
    String? email,
  }) async {
    try {
      final users = await _loadUsers();
      // Check if username already exists
      final exists = users.any((u) =>
          (u['name'] as String?)?.toLowerCase() == username.toLowerCase());
      if (exists) {
        return false;
      }

      final id = _userId(username);
      final user = {
        'id': id,
        'name': username,
        'email': email,
        'passwordHash': _hashPassword(password),
        'createdAt': DateTime.now().toIso8601String(),
      };
      users.add(user);
      await _saveUsers(users);

      // Auto-login after register
      return _doLogin(username, password);
    } catch (e) {
      debugPrint('Register error: $e');
      return false;
    }
  }

  /// Logs in with [username] and [password].
  ///
  /// Returns `true` on success. Verifies against locally stored credentials.
  Future<bool> login(String username, String password) async {
    return _doLogin(username, password);
  }

  Future<bool> _doLogin(String username, String password) async {
    try {
      final users = await _loadUsers();
      final user = users.firstWhere(
        (u) => (u['name'] as String?)?.toLowerCase() == username.toLowerCase(),
        orElse: () => {},
      );
      if (user.isEmpty) return false;

      final storedHash = user['passwordHash'] as String?;
      if (storedHash == null || storedHash != _hashPassword(password)) {
        return false;
      }

      // Create session
      final sessionToken = _hashPassword('$username:${DateTime.now().millisecondsSinceEpoch}');
      _accessToken = sessionToken;
      await _storage.write(key: _keySession, value: sessionToken);

      final authUser = AuthUser(
        id: user['id'] as String? ?? '',
        name: user['name'] as String? ?? username,
        email: user['email'] as String?,
      );
      await _storage.write(key: _keyCurrentUser, value: jsonEncode(authUser.toJson()));

      currentUser.value = authUser;
      isAuthenticated.value = true;
      return true;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  /// Sends a verification code to [email].
  ///
  /// Local-only mode: always returns `true` (no actual email sent).
  /// In a future version, this could use a serverless email function.
  Future<bool> sendEmailCode(String email) async {
    // No backend — simulate success. Log the "code" for dev testing.
    debugPrint('[LocalAuth] Email code requested for $email (no backend — auto-success)');
    return true;
  }

  /// Logs in with [email] and email verification [code].
  ///
  /// Local-only mode: looks up user by email, accepts any 6-digit code.
  Future<bool> loginWithEmailCode(String email, String code) async {
    try {
      final users = await _loadUsers();
      final user = users.firstWhere(
        (u) => (u['email'] as String?)?.toLowerCase() == email.toLowerCase(),
        orElse: () => {},
      );
      if (user.isEmpty) return false;

      // Local mode: accept any 6-digit code
      if (code.length != 6) return false;

      final sessionToken = _hashPassword('$email:${DateTime.now().millisecondsSinceEpoch}');
      _accessToken = sessionToken;
      await _storage.write(key: _keySession, value: sessionToken);

      final authUser = AuthUser(
        id: user['id'] as String? ?? '',
        name: user['name'] as String? ?? email,
        email: user['email'] as String?,
      );
      await _storage.write(key: _keyCurrentUser, value: jsonEncode(authUser.toJson()));

      currentUser.value = authUser;
      isAuthenticated.value = true;
      return true;
    } catch (e) {
      debugPrint('Email login error: $e');
      return false;
    }
  }

  /// Sends a password-reset verification code to [email].
  ///
  /// Local-only mode: always returns `true`.
  Future<bool> sendForgotPasswordCode(String email) async {
    debugPrint('[LocalAuth] Forgot password code for $email (no backend — auto-success)');
    return true;
  }

  /// Resets the password for [email] using the verification [code] and a
  /// new [password].
  Future<bool> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    try {
      // Local mode: accept any 6-digit code
      if (code.length != 6) return false;

      final users = await _loadUsers();
      final idx = users.indexWhere(
        (u) => (u['email'] as String?)?.toLowerCase() == email.toLowerCase(),
      );
      if (idx < 0) return false;

      users[idx]['passwordHash'] = _hashPassword(password);
      await _saveUsers(users);
      return true;
    } catch (e) {
      debugPrint('Password reset error: $e');
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
  ///
  /// Call once at app startup to restore a previous session.
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
      currentUser.value = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      isAuthenticated.value = true;
      return true;
    } catch (e) {
      debugPrint('Check auth status error: $e');
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
