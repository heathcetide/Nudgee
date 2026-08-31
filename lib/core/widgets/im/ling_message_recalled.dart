import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';

/// A placeholder UI shown for a recalled message.
///
/// Displays a centered gray text such as "消息已撤回". When [isSelf] is true,
/// the text reads "你撤回了一条消息" (or [selfText] if provided).
class LingMessageRecalled extends StatelessWidget {
  /// Whether the recalled message was sent by the current user.
  final bool isSelf;

  /// Custom text shown for other users' recalled messages.
  /// Defaults to "消息已撤回".
  final String? text;

  /// Custom text shown when [isSelf] is true.
  /// Defaults to "你撤回了一条消息".
  final String? selfText;

  /// Optional callback when the row is tapped (e.g. re-edit in some IM SDKs).
  final VoidCallback? onTap;

  const LingMessageRecalled({
    super.key,
    this.isSelf = false,
    this.text,
    this.selfText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = isSelf
        ? (selfText ?? '你撤回了一条消息')
        : (text ?? '消息已撤回');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.spacingSm,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingXs,
            ),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
