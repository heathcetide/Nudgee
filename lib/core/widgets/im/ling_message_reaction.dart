import 'package:flutter/material.dart';

import 'package:nudgee/core/models/im/im.dart';

/// Displays reaction emojis below a message bubble.
class LingMessageReactions extends StatelessWidget {
  final List<LingMessageReaction> reactions;
  final String currentUserId;
  final ValueChanged<String>? onReactionTapped;

  const LingMessageReactions({
    super.key,
    required this.reactions,
    required this.currentUserId,
    this.onReactionTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: reactions.map((r) {
        final reacted = r.reactedBy(currentUserId);
        return GestureDetector(
          onTap: () => onReactionTapped?.call(r.emoji),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: reacted
                  ? theme.colorScheme.primary.withOpacity(0.12)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: reacted
                  ? Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 1)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.emoji, style: const TextStyle(fontSize: 14)),
                if (r.count > 1) ...[
                  const SizedBox(width: 3),
                  Text(
                    '${r.count}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: reacted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// A quick reaction bar shown on long-press of a message.
class LingQuickReactionBar extends StatelessWidget {
  final ValueChanged<String> onReactionSelected;
  final List<String> emojis;

  const LingQuickReactionBar({
    super.key,
    required this.onReactionSelected,
    this.emojis = const ['👍', '❤️', '😂', '😮', '😢', '🙏'],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: emojis.map((emoji) {
          return GestureDetector(
            onTap: () => onReactionSelected(emoji),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
