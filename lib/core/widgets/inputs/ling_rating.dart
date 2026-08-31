import 'package:flutter/material.dart';

/// A star rating component with interactive or read-only mode.
class LingRating extends StatelessWidget {
  final double value;
  final int maxRating;
  final ValueChanged<double>? onRatingChanged;
  final double iconSize;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool allowHalfRating;
  final bool readOnly;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const LingRating({
    super.key,
    required this.value,
    this.maxRating = 5,
    this.onRatingChanged,
    this.iconSize = 24,
    this.activeColor,
    this.inactiveColor,
    this.allowHalfRating = false,
    this.readOnly = false,
    this.activeIcon = Icons.star,
    this.inactiveIcon = Icons.star_border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activeColor ?? const Color(0xFFF59E0B);
    final inactive = inactiveColor ?? theme.colorScheme.outlineVariant;

    if (readOnly) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(maxRating, (index) {
          final position = index + 1;
          if (position <= value.floor()) {
            return Icon(activeIcon, size: iconSize, color: active);
          }
          if (allowHalfRating && position - 0.5 <= value) {
            return Icon(Icons.star_half, size: iconSize, color: active);
          }
          return Icon(inactiveIcon, size: iconSize, color: inactive);
        }),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        final position = index + 1;
        return GestureDetector(
          onTap: () => onRatingChanged?.call(position.toDouble()),
          onHorizontalDragUpdate: allowHalfRating
              ? (details) {
                  final box = context.findRenderObject() as RenderBox;
                  final localPos = box.globalToLocal(details.globalPosition);
                  final starWidth = box.size.width / maxRating;
                  final rating = (localPos.dx / starWidth).clamp(0.0, maxRating.toDouble());
                  onRatingChanged?.call(allowHalfRating ? (rating * 2).round() / 2 : rating.ceilToDouble());
                }
              : null,
          child: Padding(
            padding: EdgeInsets.only(right: index < maxRating - 1 ? 2 : 0),
            child: Icon(
              position <= value ? activeIcon : inactiveIcon,
              size: iconSize,
              color: position <= value ? active : inactive,
            ),
          ),
        );
      }),
    );
  }
}
