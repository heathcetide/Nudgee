import 'package:flutter/material.dart';

/// Banner severity levels.
enum LingBannerVariant {
  info,
  success,
  warning,
  error,
}

/// An inline banner for displaying contextual messages at the top of content.
///
/// Unlike [LingSnackbar], banners persist until dismissed by the user.
class LingBanner extends StatelessWidget {
  final String message;
  final String? title;
  final LingBannerVariant variant;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final bool dismissible;

  const LingBanner({
    super.key,
    required this.message,
    this.title,
    this.variant = LingBannerVariant.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.dismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _colors(variant, theme);

    return Material(
      color: colors.background,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(colors.icon, color: colors.foreground, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(color: colors.foreground),
                    ),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.foreground),
                  ),
                ],
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: colors.foreground),
                child: Text(actionLabel!),
              ),
            ],
            if (dismissible && onDismiss != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onDismiss,
                color: colors.foreground,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }

  _BannerColors _colors(LingBannerVariant v, ThemeData theme) {
    switch (v) {
      case LingBannerVariant.info:
        return _BannerColors(
          background: theme.colorScheme.primaryContainer,
          foreground: theme.colorScheme.onPrimaryContainer,
          icon: icon ?? Icons.info_outline,
        );
      case LingBannerVariant.success:
        return _BannerColors(
          background: const Color(0x2222C55E),
          foreground: const Color(0xFF16A34A),
          icon: icon ?? Icons.check_circle_outline,
        );
      case LingBannerVariant.warning:
        return _BannerColors(
          background: const Color(0x22F59E0B),
          foreground: const Color(0xFFD97706),
          icon: icon ?? Icons.warning_amber_rounded,
        );
      case LingBannerVariant.error:
        return _BannerColors(
          background: theme.colorScheme.errorContainer,
          foreground: theme.colorScheme.onErrorContainer,
          icon: icon ?? Icons.error_outline,
        );
    }
  }
}

class _BannerColors {
  final Color background;
  final Color foreground;
  final IconData icon;

  _BannerColors({required this.background, required this.foreground, required this.icon});
}
