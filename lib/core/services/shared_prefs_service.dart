import 'package:shared_preferences/shared_preferences.dart';

import 'package:nudgee/core/errors/app_exception.dart';

/// Type-safe wrapper around `SharedPreferences` for non-sensitive preferences.
///
/// Stores theme mode, locale, and other user preferences.
class SharedPrefsService {
  late SharedPreferences _prefs;

  /// Must be called before any getter/setter.
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e, st) {
      throw StorageException('Failed to init SharedPreferences', originalError: e, stackTrace: st);
    }
  }

  // ── String ───────────────────────────────────────────────────────────

  Future<bool> setString(String key, String value) => _prefs.setString(key, value);
  String? getString(String key) => _prefs.getString(key);

  // ── Bool ─────────────────────────────────────────────────────────────

  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);
  bool? getBool(String key) => _prefs.getBool(key);

  // ── Int ──────────────────────────────────────────────────────────────

  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);
  int? getInt(String key) => _prefs.getInt(key);

  // ── Double ───────────────────────────────────────────────────────────

  Future<bool> setDouble(String key, double value) => _prefs.setDouble(key, value);
  double? getDouble(String key) => _prefs.getDouble(key);

  // ── StringList ───────────────────────────────────────────────────────

  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);
  List<String>? getStringList(String key) => _prefs.getStringList(key);

  // ── Bulk ─────────────────────────────────────────────────────────────

  Future<bool> remove(String key) => _prefs.remove(key);
  Future<bool> clear() => _prefs.clear();
  bool containsKey(String key) => _prefs.containsKey(key);
  Set<String> getKeys() => _prefs.getKeys();
}
