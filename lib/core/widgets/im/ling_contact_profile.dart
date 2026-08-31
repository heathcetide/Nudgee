import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';
import 'package:nudgee/core/widgets/layout/ling_list_item.dart';

/// A contact profile / details page.
///
/// Shows a large avatar, name, signature, and online status at the top,
/// quick action buttons (send message, voice/video call) in the middle,
/// contact info (phone, email, remark) below, and friend-management
/// actions (add / remove / block / report) at the bottom.
class LingContactProfile extends StatelessWidget {
  final LingChatUser user;
  final bool isFriend;

  final VoidCallback? onSendMessage;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onAddFriend;
  final VoidCallback? onRemoveFriend;
  final VoidCallback? onBlock;
  final VoidCallback? onReport;
  final VoidCallback? onEditRemark;

  const LingContactProfile({
    super.key,
    required this.user,
    this.isFriend = false,
    this.onSendMessage,
    this.onVoiceCall,
    this.onVideoCall,
    this.onAddFriend,
    this.onRemoveFriend,
    this.onBlock,
    this.onReport,
    this.onEditRemark,
  });

  String? get _signature => user.metadata?['signature'] as String?;
  String? get _phone => user.metadata?['phone'] as String?;
  String? get _email => user.metadata?['email'] as String?;
  String? get _remark => user.metadata?['remark'] as String?;

  String get _statusLabel {
    switch (user.status) {
      case LingUserStatus.online:
        return '在线';
      case LingUserStatus.away:
        return '离开';
      case LingUserStatus.busy:
        return '忙碌';
      case LingUserStatus.offline:
        return '离线';
      case LingUserStatus.invisible:
        return '隐身';
    }
  }

  Color get _statusColor {
    switch (user.status) {
      case LingUserStatus.online:
        return AppColors.success;
      case LingUserStatus.away:
        return AppColors.warning;
      case LingUserStatus.busy:
        return AppColors.error;
      case LingUserStatus.offline:
        return AppColors.lightTextHint;
      case LingUserStatus.invisible:
        return AppColors.lightTextHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        // ── Header: avatar + name + signature + status ──
        Container(
          width: double.infinity,
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.spacingXl,
            horizontal: AppConstants.spacingMd,
          ),
          child: Column(
            children: [
              LingAvatar(
                imageUrl: user.avatarUrl,
                name: user.name,
                size: LingAvatarSize.xxl,
                showOnlineStatus: true,
                isOnline: user.isOnline,
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                user.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_signature != null && _signature!.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingSm),
                Text(
                  _signature!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppConstants.spacingSm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _statusLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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

        // ── Contact info ──
        LingListSection(
          title: '基本信息',
          children: [
            LingListItem(
              leadingIcon: Icons.phone_outlined,
              title: _phone ?? '未设置',
              subtitle: '手机号',
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {},
            ),
            LingListItem(
              leadingIcon: Icons.email_outlined,
              title: _email ?? '未设置',
              subtitle: '邮箱',
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {},
            ),
            LingListItem(
              leadingIcon: Icons.label_outline,
              title: _remark ?? '未设置',
              subtitle: '备注名',
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEditRemark,
              ),
              onTap: onEditRemark,
            ),
          ],
        ),

        const SizedBox(height: AppConstants.spacingSm),

        // ── Friend management actions ──
        LingListSection(
          children: [
            if (!isFriend)
              LingListItem(
                leadingIcon: Icons.person_add_outlined,
                title: '加为好友',
                onTap: onAddFriend,
              )
            else ...[
              LingListItem(
                leadingIcon: Icons.person_remove_outlined,
                title: '删除好友',
                onTap: onRemoveFriend,
              ),
              LingListItem(
                leadingIcon: Icons.block_outlined,
                title: '加入黑名单',
                onTap: onBlock,
              ),
            ],
            LingListItem(
              leadingIcon: Icons.report_outlined,
              title: '举报',
              onTap: onReport,
            ),
          ],
        ),

        const SizedBox(height: AppConstants.spacingXl),
      ],
    );
  }
}

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
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingSm),
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
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: AppConstants.spacingXs),
            Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
