import 'package:flutter/material.dart';

/// Badge variant.
enum LingBadgeVariant {
  filled,
  outlined,
  dot,
}

/// Badge size.
enum LingBadgeSize {
  small,
  medium,
  large,
}

/// A small status indicator badge.
///
/// Can display a count, a short text label, or just a dot.
/// Common use cases: unread message count, status indicator, notification badge.
class LingBadge extends StatelessWidget {
  final String? label;
  final int? count;
  final LingBadgeVariant variant;
  final LingBadgeSize size;
  final Color? color;
  final Color? textColor;
  final Widget? child;
  final bool showBadge;

  const LingBadge({
    super.key,
    this.label,
    this.count,
    this.variant = LingBadgeVariant.filled,
    this.size = LingBadgeSize.small,
    this.color,
    this.textColor,
    this.child,
    this.showBadge = true,
  }) : assert(label != null || count != null || variant == LingBadgeVariant.dot,
            'Provide label, count, or use dot variant');

  /// A dot badge — useful for status indicators.
  const LingBadge.dot({
    super.key,
    this.color,
    this.child,
    this.showBadge = true,
  })  : label = null,
        count = null,
        variant = LingBadgeVariant.dot,
        size = LingBadgeSize.small,
        textColor = null;

  /// A count badge — clips to 99+ if count exceeds 99.
  const LingBadge.count({
    super.key,
    required this.count,
    this.color,
    this.textColor,
    this.child,
    this.showBadge = true,
  })  : label = null,
        variant = LingBadgeVariant.filled,
        size = LingBadgeSize.small;

  @override
  Widget build(BuildContext context) {
    if (!showBadge) return child ?? const SizedBox.shrink();

    final badge = _buildBadge(context);

    if (child != null) {
      return Badge(
        label: badge,
        offset: _offset,
        child: child,
      );
    }
    return badge;
  }

  Widget _buildBadge(context) {
    final theme = Theme.of(context);
    final bgColor = color ?? theme.colorScheme.error;
    final fgColor = textColor ?? (variant == LingBadgeVariant.outlined ? bgColor : theme.colorScheme.onError);

    if (variant == LingBadgeVariant.dot) {
      return Container(
        width: _dotSize,
        height: _dotSize,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      );
    }

    final text = label ?? _formatCount(count);

    if (variant == LingBadgeVariant.outlined) {
      return Container(
        padding: _padding,
        decoration: BoxDecoration(
          border: Border.all(color: bgColor, width: 1.2),
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: Text(text, style: _textStyle(fgColor)),
      );
    }

    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Text(text, style: _textStyle(fgColor)),
    );
  }

  String _formatCount(int? c) {
    if (c == null) return '';
    if (c > 99) return '99+';
    return c.toString();
  }

  double get _dotSize {
    switch (size) {
      case LingBadgeSize.small:
        return 8;
      case LingBadgeSize.medium:
        return 10;
      case LingBadgeSize.large:
        return 12;
    }
  }

  EdgeInsetsGeometry get _padding {
    switch (size) {
      case LingBadgeSize.small:
        return const EdgeInsets.symmetric(horizontal: 6, vertical: 2);
      case LingBadgeSize.medium:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
      case LingBadgeSize.large:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    }
  }

  double get _radius {
    switch (size) {
      case LingBadgeSize.small:
        return 10;
      case LingBadgeSize.medium:
        return 12;
      case LingBadgeSize.large:
        return 14;
    }
  }

  Offset get _offset {
    switch (size) {
      case LingBadgeSize.small:
        return const Offset(-3, -3);
      case LingBadgeSize.medium:
        return const Offset(-4, -4);
      case LingBadgeSize.large:
        return const Offset(-5, -5);
    }
  }

  TextStyle _textStyle(Color color) {
    const base = TextStyle(fontWeight: FontWeight.w600, height: 1.2);
    switch (size) {
      case LingBadgeSize.small:
        return base.copyWith(fontSize: 10, color: color);
      case LingBadgeSize.medium:
        return base.copyWith(fontSize: 12, color: color);
      case LingBadgeSize.large:
        return base.copyWith(fontSize: 13, color: color);
    }
  }
}
