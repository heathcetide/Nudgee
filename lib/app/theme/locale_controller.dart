import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/shared_prefs_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locale state notifier.
///
/// Holds the currently selected [Locale]. When the state is `null` the app
/// follows the system default. The preference is persisted to
/// [SharedPreferences] so it survives app restarts.
class LocaleController extends StateNotifier<Locale?> {
  LocaleController() : super(null) {
    _load();
  }

  /// Load the persisted locale preference (if any).
  void _load() {
    try {
      final saved = _readPref(AppConstants.keyLocale);
      state = _parseLocale(saved);
    } catch (_) {
      // Use system default if prefs unavailable.
    }
  }

  /// Switch to an explicit [locale].
  ///
  /// Pass `null` (or call [followSystem]) to revert to the system default.
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    if (locale == null) {
      await _removePref(AppConstants.keyLocale);
    } else {
      await _writePref(AppConstants.keyLocale, locale.toLanguageTag());
    }
  }

  /// Follow the system locale.
  Future<void> followSystem() => setLocale(null);

  // ── Persistence helpers ──────────────────────────────────────────────

  String? _readPref(String key) {
    try {
      return sl<SharedPrefsService>().getString(key);
    } catch (_) {
      try {
        return sl<SharedPreferences>().getString(key);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _writePref(String key, String value) async {
    try {
      await sl<SharedPrefsService>().setString(key, value);
    } catch (_) {
      try {
        await sl<SharedPreferences>().setString(key, value);
      } catch (_) {}
    }
  }

  Future<void> _removePref(String key) async {
    try {
      await sl<SharedPrefsService>().remove(key);
    } catch (_) {
      try {
        await sl<SharedPreferences>().remove(key);
      } catch (_) {}
    }
  }

  Locale? _parseLocale(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return Locale.fromSubtags(
        languageCode: value.split('-').first,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Provider for [LocaleController].
final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale?>((ref) {
  return LocaleController();
});
