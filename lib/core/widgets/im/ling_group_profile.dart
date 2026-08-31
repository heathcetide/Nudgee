import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/buttons/ling_button.dart';
import 'package:nudgee/core/widgets/im/ling_group_avatar.dart';
import 'package:nudgee/core/widgets/layout/ling_list_item.dart';

/// A group profile / details page.
///
/// Layout (top → bottom):
/// 1. Header — group avatar ([LingGroupAvatar]) + group name + group ID.
/// 2. Quick actions — three circular buttons: send message, voice call,
///    video call.
/// 3. Info section — group type, announcement, member count, created time.
/// 4. Footer — a red "退出群聊" button.
class LingGroupProfile extends StatelessWidget {
  /// The group conversation to display.
  final LingConversation conversation;

  /// The current user's id (used to filter group avatar members).
  final String currentUserId;

  /// Quick-action callbacks.
  final VoidCallback? onSendMessage;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;

  /// Leave-group callback (wired to the red footer button).
  final VoidCallback? onLeaveGroup;

  /// Called when the member-count row is tapped.
  final VoidCallback? onMemberTap;

  /// When true, renders as a shrink-wrap non-scrollable list (for embedding
  /// inside another scrollable). Defaults to false.
  final bool shrinkWrap;

  const LingGroupProfile({
    super.key,
    required this.conversation,
    required this.currentUserId,
    this.onSendMessage,
    this.onVoiceCall,
    this.onVideoCall,
    this.onLeaveGroup,
    this.onMemberTap,
    this.shrinkWrap = false,
  });

  String? get _announcement =>
      conversation.metadata?['announcement'] as String?;
  String? get _groupType => conversation.metadata?['groupType'] as String?;
  DateTime? get _createdAt =>
      conversation.metadata?['createdAt'] as DateTime?;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final others = conversation.others(currentUserId);

    return ListView(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      children: [
        // ── Header ──
        Container(
          width: double.infinity,
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.spacingXl,
            horizontal: AppConstants.spacingMd,
          ),
          child: Column(
            children: [
              LingGroupAvatar(
                avatarUrls: others
                    .map((u) => u.avatarUrl)
                    .whereType<String>()
                    .toList(),
                names: others.map((u) => u.name).toList(),
                size: 80,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                conversation.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingXs),
              Text(
                '群号：${conversation.id}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConstants.spacingSm),

        // ── Quick actions ──
        Container(
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.spacingMd,
            horizontal: AppConstants.spacingMd,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionTile(
                icon: Icons.chat_bubble_outline,
                label: '发消息',
                color: theme.colorScheme.primary,
                onTap: onSendMessage,
              ),
              _ActionTile(
                icon: Icons.phone_outlined,
                label: '语音通话',
                color: AppColors.success,
                onTap: onVoiceCall,
              ),
              _ActionTile(
                icon: Icons.videocam_outlined,
                label: '视频通话',
                color: AppColors.info,
                onTap: onVideoCall,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConstants.spacingSm),

        // ── Group info ──
        LingListSection(
          title: '群信息',
          children: [
            LingListItem(
              leadingIcon: Icons.group_outlined,
              title: _groupType ?? '普通群',
              subtitle: '群类型',
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {},
            ),
            LingListItem(
              leadingIcon: Icons.campaign_outlined,
              title: (_announcement != null && _announcement!.isNotEmpty)
                  ? _announcement!
                  : '暂无公告',
              subtitle: '群公告',
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {},
            ),
            LingListItem(
              leadingIcon: Icons.people_outline,
              title: '${conversation.members.length} 人',
              subtitle: '群成员',
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: onMemberTap,
            ),
            LingListItem(
              leadingIcon: Icons.schedule_outlined,
              title: _createdAt != null ? _formatDate(_createdAt!) : '未知',
              subtitle: '创建时间',
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {},
            ),
          ],
        ),

        const SizedBox(height: AppConstants.spacingXl),

        // ── Leave group ──
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
          ),
          child: LingButton(
            label: '退出群聊',
            variant: LingButtonVariant.outlined,
            size: LingButtonSize.large,
            expanded: true,
            foregroundColor: AppColors.error,
            onPressed: onLeaveGroup,
          ),
        ),

        const SizedBox(height: AppConstants.spacingXxl),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }
}

/// A circular quick-action button with an icon and label.
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingSm,
          vertical: AppConstants.spacingXs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
