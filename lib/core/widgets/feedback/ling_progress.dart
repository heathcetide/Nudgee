import 'package:flutter/material.dart';

/// A linear progress bar with optional label and percentage.
class LingLinearProgress extends StatelessWidget {
  final double value;
  final double? minHeight;
  final Color? backgroundColor;
  final Color? color;
  final String? label;
  final bool showPercentage;

  const LingLinearProgress({
    super.key,
    required this.value,
    this.minHeight,
    this.backgroundColor,
    this.color,
    this.label,
    this.showPercentage = false,
  }) : assert(value >= 0 && value <= 1, 'value must be between 0 and 1');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bar = LinearProgressIndicator(
      value: value,
      minHeight: minHeight ?? 8,
      backgroundColor: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
      color: color ?? theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(4),
    );

    if (label == null && !showPercentage) return bar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || showPercentage)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(label!, style: theme.textTheme.bodySmall),
                if (showPercentage)
                  Text(
                    '${(value * 100).toInt()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        bar,
      ],
    );
  }
}

/// A circular progress indicator with optional label in the center.
class LingCircularProgress extends StatelessWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final String? centerLabel;

  const LingCircularProgress({
    super.key,
    required this.value,
    this.size = 48,
    this.strokeWidth = 4,
    this.color,
    this.backgroundColor,
    this.centerLabel,
  }) : assert(value >= 0 && value <= 1, 'value must be between 0 and 1');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: strokeWidth,
            color: color ?? theme.colorScheme.primary,
            backgroundColor: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
          ),
          if (centerLabel != null)
            Text(
              centerLabel!,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
