import 'package:flutter/material.dart';

/// A conversation draft text widget.
///
/// Displays a red "[草稿]" prefix followed by the draft content.
/// The prefix is rendered in red while the rest uses the default
/// text color (or a custom [style]).
class LingConversationDraft extends StatelessWidget {
  /// The draft text content (without the prefix).
  final String draftText;

  /// Maximum number of lines. Defaults to 1.
  final int maxLines;

  /// Base text style applied to the draft content and (minus color)
  /// to the prefix. If null, the theme's [bodySmall] is used.
  final TextStyle? style;

  /// The prefix label shown in red. Defaults to "[草稿]".
  final String prefixLabel;

  const LingConversationDraft({
    super.key,
    required this.draftText,
    this.maxLines = 1,
    this.style,
    this.prefixLabel = '[草稿]',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodySmall ?? const TextStyle();
    final prefixStyle = baseStyle.copyWith(color: theme.colorScheme.error);

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(text: prefixLabel, style: prefixStyle),
          TextSpan(text: draftText, style: baseStyle),
        ],
      ),
    );
  }
}
