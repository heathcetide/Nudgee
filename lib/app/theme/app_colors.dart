import 'package:flutter/material.dart';

/// Semantic color tokens for the Nudgee design system.
///
/// These are the raw color values. The [AppTheme] class maps them into
/// [ColorScheme] and [ThemeData] for both light and dark modes.
class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────

  /// Primary brand color — deep indigo-blue.
  static const Color primary = Color(0xFF4F6BED);

  /// Primary variant (lighter).
  static const Color primaryLight = Color(0xFF7B93F5);

  /// Primary variant (darker).
  static const Color primaryDark = Color(0xFF2A48C7);

  /// Secondary accent — teal.
  static const Color secondary = Color(0xFF14B8A6);

  /// Tertiary accent — amber.
  static const Color tertiary = Color(0xFFF59E0B);

  // ── Semantic ─────────────────────────────────────────────────────────

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Light mode surfaces ──────────────────────────────────────────────

  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextHint = Color(0xFF94A3B8);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFF1F5F9);

  // ── Dark mode surfaces ───────────────────────────────────────────────

  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextHint = Color(0xFF64748B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkDivider = Color(0xFF1E293B);

  // ── Call-specific ────────────────────────────────────────────────────

  /// Mute indicator (microphone off).
  static const Color muteRed = Color(0xFFEF4444);

  /// Unmute indicator (microphone on).
  static const Color unmuteGreen = Color(0xFF22C55E);

  /// Video off indicator.
  static const Color videoOffGray = Color(0xFF64748B);

  /// Active speaker border glow.
  static const Color activeSpeakerGlow = Color(0xFF4F6BED);

  /// Recording indicator.
  static const Color recordingRed = Color(0xFFDC2626);
}
