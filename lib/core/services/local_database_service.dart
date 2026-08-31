import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:nudgee/core/errors/app_exception.dart';

/// Local database service backed by [Hive].
///
/// Provides a simple key/value API over named boxes. Hive is a lightweight,
/// NoSQL key-value store written in pure Dart — perfect for offline-first
/// caching and structured persistence without native dependencies.
///
/// All methods are async (Hive performs disk I/O). Failures are wrapped in
/// [StorageException] so callers can handle them uniformly.
class LocalDatabaseService {
  final Map<String, Box> _boxes = {};

  /// Initialize Hive and open the default set of boxes.
  ///
  /// Call once during app startup (before any read/write).
  Future<void> init({List<String> preopenBoxes = const []}) async {
    try {
      await Hive.initFlutter();
      for (final name in preopenBoxes) {
        await _openBox(name);
      }
    } catch (e, st) {
      throw StorageException('Failed to init Hive', originalError: e, stackTrace: st);
    }
  }

  // ── Box management ────────────────────────────────────────────────────

  Future<Box> _openBox(String boxName) async {
    final existing = _boxes[boxName];
    if (existing != null && existing.isOpen) return existing;
    final box = await Hive.openBox(boxName);
    _boxes[boxName] = box;
    return box;
  }

  Future<Box> _getBox(String boxName) async {
    final box = _boxes[boxName];
    if (box == null || !box.isOpen) {
      return _openBox(boxName);
    }
    return box;
  }

  // ── CRUD ──────────────────────────────────────────────────────────────

  /// Write [value] to [key] in [boxName].
  Future<void> put<T>(String boxName, String key, T value) async {
    try {
      final box = await _getBox(boxName);
      await box.put(key, value);
    } catch (e, st) {
      throw StorageException('Failed to put $key in $boxName',
          originalError: e, stackTrace: st);
    }
  }

  /// Read [key] from [boxName], returning [defaultValue] when absent.
  Future<T?> get<T>(String boxName, String key, {T? defaultValue}) async {
    try {
      final box = await _getBox(boxName);
      return box.get(key, defaultValue: defaultValue) as T?;
    } catch (e, st) {
      throw StorageException('Failed to get $key from $boxName',
          originalError: e, stackTrace: st);
    }
  }

  /// Delete [key] from [boxName]. No-op if the key doesn't exist.
  Future<void> delete(String boxName, String key) async {
    try {
      final box = await _getBox(boxName);
      await box.delete(key);
    } catch (e, st) {
      throw StorageException('Failed to delete $key from $boxName',
          originalError: e, stackTrace: st);
    }
  }

  /// Remove all entries from [boxName].
  Future<void> clear(String boxName) async {
    try {
      final box = await _getBox(boxName);
      await box.clear();
    } catch (e, st) {
      throw StorageException('Failed to clear $boxName',
          originalError: e, stackTrace: st);
    }
  }

  // ── Query helpers ─────────────────────────────────────────────────────

  /// Return all keys currently stored in [boxName].
  Future<List<String>> getKeys(String boxName) async {
    try {
      final box = await _getBox(boxName);
      return box.keys.cast<String>().toList();
    } catch (e, st) {
      throw StorageException('Failed to get keys from $boxName',
          originalError: e, stackTrace: st);
    }
  }

  /// Whether [key] exists in [boxName].
  Future<bool> hasKey(String boxName, String key) async {
    try {
      final box = await _getBox(boxName);
      return box.containsKey(key);
    } catch (e, st) {
      throw StorageException('Failed to check key $key in $boxName',
          originalError: e, stackTrace: st);
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────

  /// Close all opened boxes. Safe to call on app shutdown.
  Future<void> closeAll() async {
    final futures = <Future<void>>[];
    for (final box in _boxes.values) {
      if (box.isOpen) futures.add(box.close());
    }
    try {
      await Future.wait(futures);
    } catch (e) {
      debugPrint('LocalDatabaseService.closeAll error: $e');
    }
    _boxes.clear();
  }
}
