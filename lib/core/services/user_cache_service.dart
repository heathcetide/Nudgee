import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/services/local_database_service.dart';

/// Hive-backed cache for user business data.
///
/// Uses [LocalDatabaseService] (Hive) to persist structured user data locally:
/// - User settings (preferences, notification config, etc.)
/// - Draft data (unsaved forms, compose drafts)
/// - Offline cache (recently viewed items, search history)
///
/// Each user gets a separate box namespace: `user_{userId}_*`
/// This ensures multi-user isolation if the device is shared.
///
/// Usage:
///   final cache = sl<UserCacheService>();
///   await cache.setSetting(userId, 'theme', 'dark');
///   final theme = await cache.getSetting(userId, 'theme');
class UserCacheService {
  final LocalDatabaseService _db;

  UserCacheService(this._db);

  static const _boxSettings = 'user_settings';
  static const _boxDrafts = 'user_drafts';
  static const _boxCache = 'user_cache';

  // ── Settings ──────────────────────────────────────────────────────────

  String _settingsKey(String userId, String key) => '${userId}:$key';

  /// Save a user setting.
  Future<void> setSetting(String userId, String key, dynamic value) async {
    await _db.put(_boxSettings, _settingsKey(userId, key), value);
  }

  /// Read a user setting.
  Future<T?> getSetting<T>(String userId, String key, {T? defaultValue}) async {
    return _db.get<T>(_boxSettings, _settingsKey(userId, key),
        defaultValue: defaultValue);
  }

  /// Delete a user setting.
  Future<void> removeSetting(String userId, String key) async {
    await _db.delete(_boxSettings, _settingsKey(userId, key));
  }

  /// Get all settings for a user.
  Future<Map<String, dynamic>> getAllSettings(String userId) async {
    final keys = await _db.getKeys(_boxSettings);
    final result = <String, dynamic>{};
    final prefix = '${userId}:';
    for (final k in keys) {
      if (k.startsWith(prefix)) {
        final settingKey = k.substring(prefix.length);
        result[settingKey] = await _db.get(_boxSettings, k);
      }
    }
    return result;
  }

  /// Clear all settings for a user.
  Future<void> clearSettings(String userId) async {
    final keys = await _db.getKeys(_boxSettings);
    final prefix = '${userId}:';
    for (final k in keys) {
      if (k.startsWith(prefix)) {
        await _db.delete(_boxSettings, k);
      }
    }
  }

  // ── Drafts ────────────────────────────────────────────────────────────

  String _draftKey(String userId, String draftId) => '${userId}:$draftId';

  /// Save a draft (e.g. unsaved form data) as JSON.
  Future<void> saveDraft(String userId, String draftId, Map<String, dynamic> data) async {
    await _db.put(_boxDrafts, _draftKey(userId, draftId), jsonEncode(data));
  }

  /// Load a draft by ID.
  Future<Map<String, dynamic>?> getDraft(String userId, String draftId) async {
    final raw = await _db.get<String>(_boxDrafts, _draftKey(userId, draftId));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[UserCache] getDraft parse error: $e');
      return null;
    }
  }

  /// Delete a draft.
  Future<void> removeDraft(String userId, String draftId) async {
    await _db.delete(_boxDrafts, _draftKey(userId, draftId));
  }

  /// Clear all drafts for a user.
  Future<void> clearDrafts(String userId) async {
    final keys = await _db.getKeys(_boxDrafts);
    final prefix = '${userId}:';
    for (final k in keys) {
      if (k.startsWith(prefix)) {
        await _db.delete(_boxDrafts, k);
      }
    }
  }

  // ── Generic cache ─────────────────────────────────────────────────────

  String _cacheKey(String userId, String cacheId) => '${userId}:$cacheId';

  /// Cache arbitrary data (JSON string) for offline access.
  Future<void> setCache(String userId, String cacheId, String data) async {
    await _db.put(_boxCache, _cacheKey(userId, cacheId), data);
  }

  /// Read cached data.
  Future<String?> getCache(String userId, String cacheId) async {
    return _db.get<String>(_boxCache, _cacheKey(userId, cacheId));
  }

  /// Remove a cached item.
  Future<void> removeCache(String userId, String cacheId) async {
    await _db.delete(_boxCache, _cacheKey(userId, cacheId));
  }

  /// Clear all cache for a user.
  Future<void> clearCache(String userId) async {
    final keys = await _db.getKeys(_boxCache);
    final prefix = '${userId}:';
    for (final k in keys) {
      if (k.startsWith(prefix)) {
        await _db.delete(_boxCache, k);
      }
    }
  }

  // ── Bulk ──────────────────────────────────────────────────────────────

  /// Clear ALL data for a user (settings + drafts + cache).
  /// Called on logout to wipe user-specific local data.
  Future<void> clearAllForUser(String userId) async {
    await clearSettings(userId);
    await clearDrafts(userId);
    await clearCache(userId);
    debugPrint('[UserCache] cleared all data for user $userId');
  }
}
