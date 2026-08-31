import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';
import 'package:nudgee/core/widgets/im/ling_conversation_draft.dart';
import 'package:nudgee/core/widgets/im/ling_group_avatar.dart';

/// A single conversation list item.
///
/// Shows avatar (single or group), name, last message preview,
/// time, unread badge, mute icon, pin indicator.
class LingConversationItem extends StatelessWidget {
  final LingConversation conversation;
  final String currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  const LingConversationItem({
    super.key,
    required this.conversation,
    required this.currentUserId,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastMsg = conversation.lastMessage;
    final timeStr = lastMsg != null ? _formatTime(lastMsg.createdAt) : '';

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected ? theme.colorScheme.primaryContainer.withOpacity(0.3) : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm + 2,
        ),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(),
            const SizedBox(width: AppConstants.spacingMd),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + time row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: conversation.hasUnread ? FontWeight.w600 : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Last message + badges row
                  Row(
                    children: [
                      // Mute icon
                      if (conversation.isMuted)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.notifications_off,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                        ),
                      // Last message preview (or draft)
                      Expanded(
                        child: conversation.hasDraft
                            ? LingConversationDraft(
                                draftText: conversation.draft!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: conversation.hasUnread
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            : Text(
                                conversation.subtitle(currentUserId),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: conversation.hasUnread
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      // Unread badge
                      if (conversation.hasUnread) ...[
                        const SizedBox(width: 8),
                        _buildUnreadBadge(context),
                      ],
                      // Pin indicator
                      if (conversation.isPinned) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.push_pin,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (conversation.isGroup) {
      final others = conversation.others(currentUserId);
      return LingGroupAvatar(
        avatarUrls: others.map((u) => u.avatarUrl ?? '').where((u) => u.isNotEmpty).toList(),
        names: others.map((u) => u.name).toList(),
        size: 48,
      );
    }
    return LingAvatar(
      imageUrl: conversation.avatarUrl,
      name: conversation.name,
      size: LingAvatarSize.lg,
      showRing: false,
    );
  }

  Widget _buildUnreadBadge(BuildContext context) {
    final theme = Theme.of(context);
    final count = conversation.unreadCount;
    final isMuted = conversation.isMuted;
    final bgColor = isMuted ? theme.colorScheme.outline : theme.colorScheme.error;

    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onError,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.year == now.year && time.month == now.month && time.day == now.day) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    if (time.year == now.year && time.month == now.month && time.day == now.day - 1) {
      return '昨天';
    }
    if (time.year == now.year) {
      return '${time.month}/${time.day}';
    }
    return '${time.year}/${time.month}/${time.day}';
  }
}
