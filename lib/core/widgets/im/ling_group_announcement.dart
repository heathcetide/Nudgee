import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';
import 'package:nudgee/core/widgets/feedback/ling_card.dart';

/// A group announcement card.
///
/// Displays a title, the announcement body, and a footer with the
/// publisher's avatar, name, and publish time. When [canEdit] is true,
/// an edit button is shown in the header.
class LingGroupAnnouncement extends StatelessWidget {
  /// Announcement title.
  final String title;

  /// Announcement body text.
  final String content;

  /// Display name of the publisher.
  final String publisherName;

  /// When the announcement was published.
  final DateTime publishedAt;

  /// Avatar URL of the publisher (optional).
  final String? publisherAvatarUrl;

  /// Whether the current user can edit the announcement.
  final bool canEdit;

  /// Called when the edit button is tapped. Required if [canEdit] is true.
  final VoidCallback? onEdit;

  /// Optional tap callback for the whole card.
  final VoidCallback? onTap;

  const LingGroupAnnouncement({
    super.key,
    required this.title,
    required this.content,
    required this.publisherName,
    required this.publishedAt,
    this.publisherAvatarUrl,
    this.canEdit = false,
    this.onEdit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LingCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: title + edit button ──
          Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: onEdit,
                  tooltip: '编辑',
                ),
            ],
          ),

          const SizedBox(height: AppConstants.spacingSm),

          // ── Content ──
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.5,
            ),
          ),

          const SizedBox(height: AppConstants.spacingMd),

          // ── Footer: publisher + time ──
          Row(
            children: [
              LingAvatar(
                imageUrl: publisherAvatarUrl,
                name: publisherName,
                size: LingAvatarSize.xs,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  publisherName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatTime(publishedAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return '今天 ${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    if (dt.year == now.year) {
      return '${dt.month}/${dt.day} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.year}/${dt.month}/${dt.day}';
  }
}
