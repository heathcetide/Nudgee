import 'package:flutter/material.dart';

/// Position of the unread badge when used as a stack overlay.
enum LingBadgePosition {
  /// Pinned to the top-right corner of the parent.
  topRight,

  /// No automatic positioning — place it yourself via a Stack.
  custom,
}

/// A global unread-message count badge.
///
/// Shows a red circular badge with white text when [count] > 0.
/// When [count] exceeds [maxCount], it displays "99+".
/// When [count] <= 0, nothing is rendered.
///
/// Use [LingBadgePosition.topRight] inside a [Stack] to overlay it
/// on an icon/tab, or [LingBadgePosition.custom] to position manually.
class LingTotalUnreadBadge extends StatelessWidget {
  /// The unread count to display.
  final int count;

  /// Maximum count before switching to "99+". Defaults to 99.
  final int maxCount;

  /// Badge background color. Defaults to the theme's [error] color.
  final Color? color;

  /// How to position the badge. See [LingBadgePosition].
  final LingBadgePosition position;

  /// Optional custom offset when [position] is [LingBadgePosition.custom].
  final Offset offset;

  const LingTotalUnreadBadge({
    super.key,
    required this.count,
    this.maxCount = 99,
    this.color,
    this.position = LingBadgePosition.topRight,
    this.offset = Offset.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final badge = _buildBadge(context, theme);

    switch (position) {
      case LingBadgePosition.topRight:
        return Positioned(top: 0, right: 0, child: badge);
      case LingBadgePosition.custom:
        return Transform.translate(offset: offset, child: badge);
    }
  }

  Widget _buildBadge(BuildContext context, ThemeData theme) {
    final displayText = count > maxCount ? '$maxCount+' : '$count';
    final isSingleDigit = displayText.length <= 1;
    final bgColor = color ?? theme.colorScheme.error;

    return Container(
      constraints: BoxConstraints(
        minWidth: isSingleDigit ? 18 : 22,
        minHeight: isSingleDigit ? 18 : 18,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSingleDigit ? 5 : 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        shape: isSingleDigit ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isSingleDigit ? null : BorderRadius.circular(9),
        border: Border.all(color: theme.colorScheme.surface, width: 1.5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          displayText,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onError,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
