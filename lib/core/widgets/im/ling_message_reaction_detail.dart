import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';

/// A message reaction detail panel.
///
/// Groups reactions by emoji. For each emoji group, displays the emoji, the
/// list of users who tapped it (avatar + name), and the count. Users are
/// resolved via [userMap]; unknown user ids fall back to the id as the name.
class LingMessageReactionDetail extends StatelessWidget {
  /// Reactions to display, grouped by emoji.
  final List<LingMessageReaction> reactions;

  /// Map of user id → [LingChatUser] for resolving reactors.
  final Map<String, LingChatUser> userMap;

  /// Title shown in the header. Defaults to "反应详情".
  final String title;

  const LingMessageReactionDetail({
    super.key,
    required this.reactions,
    required this.userMap,
    this.title = '反应详情',
  });

  /// Convenience method to show this panel as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<LingMessageReaction> reactions,
    required Map<String, LingChatUser> userMap,
    String title = '反应详情',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => LingMessageReactionDetail(
          reactions: reactions,
          userMap: userMap,
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(
              top: AppConstants.spacingSm,
              bottom: AppConstants.spacingSm,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingXs,
          ),
          child: Row(
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
                iconSize: 20,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        // Body
        Expanded(
          child: reactions.isEmpty
              ? _buildEmpty(theme)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.spacingSm,
                  ),
                  itemCount: reactions.length,
                  itemBuilder: (context, index) {
                    final r = reactions[index];
                    return _ReactionGroup(
                      reaction: r,
                      userMap: userMap,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        child: Text(
          '暂无反应',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ReactionGroup extends StatelessWidget {
  final LingMessageReaction reaction;
  final Map<String, LingChatUser> userMap;

  const _ReactionGroup({required this.reaction, required this.userMap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji + count header
          Row(
            children: [
              Text(
                reaction.emoji,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingSm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
                child: Text(
                  '${reaction.count}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          // Reactor avatars + names
          Wrap(
            spacing: AppConstants.spacingMd,
            runSpacing: AppConstants.spacingSm,
            children: reaction.userIds.map((id) {
              final user = userMap[id];
              return _ReactorChip(
                name: user?.name ?? id,
                avatarUrl: user?.avatarUrl,
              );
            }).toList(),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Divider(height: 1, color: theme.dividerColor),
        ],
      ),
    );
  }
}

class _ReactorChip extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _ReactorChip({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LingAvatar(
          imageUrl: avatarUrl,
          name: name,
          size: LingAvatarSize.sm,
          showRing: false,
        ),
        const SizedBox(width: AppConstants.spacingXs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
