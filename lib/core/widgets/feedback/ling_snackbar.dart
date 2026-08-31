import 'package:flutter/material.dart';

/// Snackbar severity levels.
enum LingSnackbarSeverity {
  info,
  success,
  warning,
  error,
}

/// A styled snackbar with severity-based colors.
class LingSnackbar {
  LingSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    LingSnackbarSeverity severity = LingSnackbarSeverity.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    final colors = _colorsFor(severity, theme);

    final snackbar = SnackBar(
      content: Row(
        children: [
          Icon(colors.icon, color: colors.foreground, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.foreground),
            ),
          ),
        ],
      ),
      backgroundColor: colors.background,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: colors.foreground,
              onPressed: onAction,
            )
          : null,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackbar);
  }

  static void info(BuildContext context, String message) =>
      show(context, message, severity: LingSnackbarSeverity.info);

  static void success(BuildContext context, String message) =>
      show(context, message, severity: LingSnackbarSeverity.success);

  static void warning(BuildContext context, String message) =>
      show(context, message, severity: LingSnackbarSeverity.warning);

  static void error(BuildContext context, String message) =>
      show(context, message, severity: LingSnackbarSeverity.error);

  static _SnackbarColors _colorsFor(LingSnackbarSeverity severity, ThemeData theme) {
    switch (severity) {
      case LingSnackbarSeverity.info:
        return _SnackbarColors(
          background: theme.colorScheme.primaryContainer,
          foreground: theme.colorScheme.onPrimaryContainer,
          icon: Icons.info_outline,
        );
      case LingSnackbarSeverity.success:
        return _SnackbarColors(
          background: const Color(0xFF22C55E),
          foreground: Colors.white,
          icon: Icons.check_circle_outline,
        );
      case LingSnackbarSeverity.warning:
        return _SnackbarColors(
          background: const Color(0xFFF59E0B),
          foreground: Colors.white,
          icon: Icons.warning_amber_rounded,
        );
      case LingSnackbarSeverity.error:
        return _SnackbarColors(
          background: theme.colorScheme.errorContainer,
          foreground: theme.colorScheme.onErrorContainer,
          icon: Icons.error_outline,
        );
    }
  }
}

class _SnackbarColors {
  final Color background;
  final Color foreground;
  final IconData icon;

  _SnackbarColors({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}
