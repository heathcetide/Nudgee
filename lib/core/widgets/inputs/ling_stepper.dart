import 'package:flutter/material.dart';

/// A numeric stepper / counter input with +/- buttons.
class LingStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final bool enabled;
  final double iconSize;
  final double buttonSize;
  final String? label;

  const LingStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.step = 1,
    this.enabled = true,
    this.iconSize = 20,
    this.buttonSize = 36,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDecrement = enabled && value > min;
    final canIncrement = enabled && value < max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: theme.textTheme.bodyMedium),
          const SizedBox(width: 12),
        ],
        _button(context, theme, Icons.remove, canDecrement, () => onChanged((value - step).clamp(min, max))),
        Container(
          width: buttonSize * 1.5,
          height: buttonSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: enabled ? null : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _button(context, theme, Icons.add, canIncrement, () => onChanged((value + step).clamp(min, max))),
      ],
    );
  }

  Widget _button(BuildContext context, ThemeData theme, IconData icon, bool canTap, VoidCallback onTap) {
    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: Material(
        color: canTap ? theme.colorScheme.surface : theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            left: icon == Icons.remove ? const Radius.circular(8) : Radius.zero,
            right: icon == Icons.add ? const Radius.circular(8) : Radius.zero,
          ),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: canTap ? onTap : null,
          borderRadius: BorderRadius.horizontal(
            left: icon == Icons.remove ? const Radius.circular(8) : Radius.zero,
            right: icon == Icons.add ? const Radius.circular(8) : Radius.zero,
          ),
          child: Icon(icon, size: iconSize, color: canTap ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
