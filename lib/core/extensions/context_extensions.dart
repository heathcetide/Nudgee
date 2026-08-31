import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Extensions on [BuildContext] for convenient access to theme and media query.
extension ContextExtensions on BuildContext {
  // ── Theme ────────────────────────────────────────────────────────────

  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  // ── MediaQuery ───────────────────────────────────────────────────────

  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  double get statusBarHeight => MediaQuery.viewPaddingOf(this).top;
  double get bottomPadding => MediaQuery.viewPaddingOf(this).bottom;
  bool get isSmallScreen => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 900;
  bool get isDesktop => screenWidth >= 900;

  // ── Navigation ───────────────────────────────────────────────────────

  void pop<T>([T? result]) => Navigator.of(this).pop(result);
  void popRoot() => Navigator.of(this).popUntil((route) => route.isFirst);

  // ── L10n ─────────────────────────────────────────────────────────────

  AppLocalizations get l10n => AppLocalizations.of(this)!;
  TextDirection get textDirection => Localizations.maybeLocaleOf(this)?.languageCode == 'ar'
      ? TextDirection.rtl
      : TextDirection.ltr;
}
