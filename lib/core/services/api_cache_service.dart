import 'dart:async';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/local_database_service.dart';

/// A TTL-based API response cache backed by [LocalDatabaseService] (Hive).
///
/// Each entry is stored as a Hive map `{'v': <value>, 'e': <expiry epoch ms>}`
/// in a dedicated box. An in-memory index of expiry timestamps backs the
/// synchronous [isValid] check.
///
/// Values passed to [set] must be Hive-encodable (`Map`, `List`, `String`,
/// `num`, `bool`, or `null`). Use [fromJson] on [get] / [getOrFetch] to
/// reconstruct typed model objects from the decoded `dynamic` payload.
class ApiCacheService {
  ApiCacheService({this.defaultTtl = const Duration(minutes: 5)});

  /// Default time-to-live applied when no explicit `ttl` is given.
  final Duration defaultTtl;

  /// Hive box name used for all cache entries.
  static const String _boxName = 'api_cache';

  /// In-memory expiry index (key → epoch ms) for synchronous [isValid].
  final Map<String, int> _expiryIndex = {};

  /// Whether the backing Hive database is available in the service locator.
  bool _dbAvailable() {
    try {
      sl<LocalDatabaseService>();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────

  /// Retrieve a cached value for [key].
  ///
  /// Returns `null` when the entry is missing or expired. When [fromJson] is
  /// supplied it is applied to the decoded payload to produce a typed result.
  Future<T?> get<T>(String key, {T Function(dynamic)? fromJson}) async {
    if (!_dbAvailable()) return null;
    try {
      final entry = await sl<LocalDatabaseService>()
          .get<Map<String, dynamic>>(_boxName, key);
      if (entry == null) return null;
      final expiry = entry['e'] as int? ?? 0;
      _expiryIndex[key] = expiry;
      if (DateTime.now().millisecondsSinceEpoch > expiry) {
        return null;
      }
      final value = entry['v'];
      if (fromJson != null) return fromJson(value);
      return value as T?;
    } catch (_) {
      return null;
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────

  /// Store [value] under [key] with an optional [ttl].
  ///
  /// [value] must be Hive-encodable.
  Future<void> set<T>(String key, T value, {Duration? ttl}) async {
    final effectiveTtl = ttl ?? defaultTtl;
    final expiry = DateTime.now().add(effectiveTtl).millisecondsSinceEpoch;
    _expiryIndex[key] = expiry;
    if (!_dbAvailable()) return;
    try {
      await sl<LocalDatabaseService>().put(
        _boxName,
        key,
        <String, dynamic>{'v': value, 'e': expiry},
      );
    } catch (_) {
      // Persistence failed — the in-memory expiry index is still updated.
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────

  /// Remove the cached entry for [key].
  Future<void> remove(String key) async {
    _expiryIndex.remove(key);
    if (!_dbAvailable()) return;
    try {
      await sl<LocalDatabaseService>().delete(_boxName, key);
    } catch (_) {}
  }

  /// Remove **all** cached entries.
  Future<void> clear() async {
    _expiryIndex.clear();
    if (!_dbAvailable()) return;
    try {
      await sl<LocalDatabaseService>().clear(_boxName);
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Whether the entry for [key] exists and has not expired.
  ///
  /// This is a synchronous check against the in-memory expiry index. The index
  /// is populated on [set] and refreshed on [get]. For keys that have never
  /// been accessed in this session this may return `false` even if a valid
  /// entry exists on disk — call [get] for the authoritative answer.
  bool isValid(String key) {
    final expiry = _expiryIndex[key];
    if (expiry == null) return false;
    return DateTime.now().millisecondsSinceEpoch <= expiry;
  }

  /// Return a cached value or fetch it on miss.
  ///
  /// On a cache hit (valid, non-expired entry) the cached value is returned
  /// immediately. On a miss [fetch] is awaited, the result is stored with the
  /// given [ttl], and then returned.
  Future<T?> getOrFetch<T>(
    String key,
    Future<T> Function() fetch, {
    Duration? ttl,
    T Function(dynamic)? fromJson,
  }) async {
    final cached = await get<T>(key, fromJson: fromJson);
    if (cached != null) return cached;

    final fresh = await fetch();
    if (fresh != null) {
      await set<T>(key, fresh, ttl: ttl);
    }
    return fresh;
  }
}
