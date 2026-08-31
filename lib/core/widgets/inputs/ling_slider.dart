import 'package:flutter/material.dart';

/// A styled slider with optional label, value display, and range support.
class LingSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final String Function(double)? valueFormatter;
  final Color? activeColor;
  final bool enabled;

  const LingSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.valueFormatter,
    this.activeColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slider = Slider(
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      activeColor: activeColor,
      onChanged: enabled ? onChanged : null,
    );

    if (label == null) return slider;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label!, style: theme.textTheme.bodyMedium),
              Text(
                valueFormatter?.call(value) ?? value.toStringAsFixed(1),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          slider,
        ],
      ),
    );
  }
}

/// A range slider for selecting a min/max range.
class LingRangeSlider extends StatelessWidget {
  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final String Function(double)? valueFormatter;
  final Color? activeColor;
  final bool enabled;

  const LingRangeSlider({
    super.key,
    required this.values,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.valueFormatter,
    this.activeColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slider = RangeSlider(
      values: values,
      min: min,
      max: max,
      divisions: divisions,
      activeColor: activeColor,
      onChanged: enabled ? onChanged : null,
    );

    if (label == null) return slider;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label!, style: theme.textTheme.bodyMedium),
              Text(
                '${valueFormatter?.call(values.start) ?? values.start.toStringAsFixed(1)} - '
                '${valueFormatter?.call(values.end) ?? values.end.toStringAsFixed(1)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          slider,
        ],
      ),
    );
  }
}
