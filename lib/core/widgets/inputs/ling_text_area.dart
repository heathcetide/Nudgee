import 'package:flutter/material.dart';

/// A multi-line text input field with consistent styling.
///
/// Wraps [TextField] with `maxLines` support, character counter,
/// and optional auto-grow behavior.
class LingTextArea extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final int minLines;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final bool autoFocus;
  final bool showCounter;
  final bool autoGrow;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final InputDecoration? decoration;

  const LingTextArea({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.minLines = 3,
    this.maxLines,
    this.maxLength,
    this.enabled = true,
    this.autoFocus = false,
    this.showCounter = false,
    this.autoGrow = false,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.decoration,
  }) : assert(maxLines == null || maxLines >= minLines,
            'maxLines must be >= minLines');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: autoFocus,
      minLines: autoGrow ? 1 : minLines,
      maxLines: autoGrow ? (maxLines ?? 8) : (maxLines ?? minLines),
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: theme.textTheme.bodyLarge,
      decoration: decoration ??
          InputDecoration(
            labelText: label,
            hintText: hint,
            errorText: errorText,
            alignLabelWithHint: true,
            counterText: showCounter ? null : '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
            ),
            filled: true,
            fillColor: enabled ? theme.colorScheme.surface : theme.colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
    );
  }
}
