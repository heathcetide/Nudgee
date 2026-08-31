import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/errors/app_exception.dart';

/// Secure storage for sensitive data (tokens, user ID, etc.).
///
/// Uses platform keychain (iOS/macOS), keystore (Android),
/// DPAPI (Windows), libsecret (Linux), and localStorage (Web).
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // ── Access Token ─────────────────────────────────────────────────────

  Future<void> saveAccessToken(String token) =>
      _safeWrite(AppConstants.keyAccessToken, token);

  Future<String?> getAccessToken() =>
      _safeRead(AppConstants.keyAccessToken);

  // ── Refresh Token ────────────────────────────────────────────────────

  Future<void> saveRefreshToken(String token) =>
      _safeWrite(AppConstants.keyRefreshToken, token);

  Future<String?> getRefreshToken() =>
      _safeRead(AppConstants.keyRefreshToken);

  // ── User ID ──────────────────────────────────────────────────────────

  Future<void> saveUserId(String userId) =>
      _safeWrite(AppConstants.keyUserId, userId);

  Future<String?> getUserId() =>
      _safeRead(AppConstants.keyUserId);

  // ── Generic key-value ────────────────────────────────────────────────

  Future<void> write({required String key, required String value}) =>
      _safeWrite(key, value);

  Future<String?> read({required String key}) => _safeRead(key);

  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } catch (e, st) {
      throw StorageException('Failed to delete $key', originalError: e, stackTrace: st);
    }
  }

  // ── Bulk operations ──────────────────────────────────────────────────

  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e, st) {
      throw StorageException('Failed to clear storage', originalError: e, stackTrace: st);
    }
  }

  Future<Map<String, String>> readAll() async {
    try {
      return await _storage.readAll();
    } catch (e, st) {
      throw StorageException('Failed to read storage', originalError: e, stackTrace: st);
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e, st) {
      throw StorageException('Failed to write $key', originalError: e, stackTrace: st);
    }
  }

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e, st) {
      throw StorageException('Failed to read $key', originalError: e, stackTrace: st);
    }
  }
}
