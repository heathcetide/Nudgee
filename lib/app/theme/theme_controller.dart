import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/shared_prefs_service.dart';

/// Theme mode state notifier.
///
/// Persists the user's theme preference in SharedPreferences.
class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system) {
    _load();
  }

  void _load() {
    try {
      final saved = _readPref(AppConstants.keyThemeMode);
      state = _parseThemeMode(saved);
    } catch (_) {
      // Use system default if prefs unavailable
    }
  }

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

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _writePref(AppConstants.keyThemeMode, mode.name);
  }

  Future<void> toggle() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setMode(newMode);
  }

  ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

/// Provider for [ThemeController].
final themeControllerProvider = StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  return ThemeController();
});
