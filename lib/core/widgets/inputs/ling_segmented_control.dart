import 'package:flutter/material.dart';

/// A segmented control for selecting between mutually exclusive options.
///
/// Material 3 [SegmentedButton] wrapper with a simpler API.
class LingSegmentedControl<T> extends StatelessWidget {
  final List<LingSegment<T>> segments;
  final T? selectedValue;
  final ValueChanged<T> onSelectionChanged;
  final bool enabled;
  final LingSegmentedVariant variant;

  const LingSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedValue,
    required this.onSelectionChanged,
    this.enabled = true,
    this.variant = LingSegmentedVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SegmentedButton<T>(
      segments: segments.map((s) {
        return ButtonSegment<T>(
          value: s.value,
          icon: s.icon != null ? Icon(s.icon, size: 18) : null,
          label: Text(s.label, style: theme.textTheme.labelMedium),
        );
      }).toList(),
      selected: {if (selectedValue != null) selectedValue!},
      onSelectionChanged: enabled
          ? (selection) => onSelectionChanged(selection.first)
          : null,
      style: variant == LingSegmentedVariant.compact
          ? SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            )
          : null,
    );
  }
}

/// A segment configuration for [LingSegmentedControl].
class LingSegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const LingSegment({required this.value, required this.label, this.icon});
}

enum LingSegmentedVariant { standard, compact }
