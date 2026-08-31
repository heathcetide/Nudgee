import 'package:flutter/material.dart';

/// A styled dropdown selector.
///
/// Wraps [DropdownButton] with consistent theming and optional label.
class LingDropdown<T> extends StatelessWidget {
  final T? value;
  final List<LingDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final bool enabled;
  final bool isExpanded;

  const LingDropdown({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.label,
    this.hint,
    this.prefixIcon,
    this.enabled = true,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dropdown = DropdownButton<T>(
      value: value,
      hint: hint != null ? Text(hint!, style: theme.textTheme.bodyMedium) : null,
      isExpanded: isExpanded,
      underline: const SizedBox.shrink(),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item.value,
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
              ],
              Text(item.label, style: theme.textTheme.bodyMedium),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );

    if (label == null && prefixIcon == null) return dropdown;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      child: dropdown,
    );
  }
}

/// A dropdown item configuration.
class LingDropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const LingDropdownItem({required this.value, required this.label, this.icon});
}
