import 'package:flutter/material.dart';

/// A styled switch with optional label and description.
class LingSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;
  final String? description;
  final bool enabled;
  final Color? activeColor;

  const LingSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.description,
    this.enabled = true,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final switchWidget = Switch(
      value: value,
      onChanged: enabled ? onChanged : null,
      activeColor: activeColor,
    );

    if (label == null && description == null) return switchWidget;

    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Text(
                      label!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: enabled ? null : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (description != null)
                    Text(
                      description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            switchWidget,
          ],
        ),
      ),
    );
  }
}
