import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';
import 'package:nudgee/core/widgets/feedback/ling_empty_state.dart';
import 'package:nudgee/core/widgets/buttons/ling_button.dart';

/// Black list (blocked users) page.
///
/// Shows a list of blocked users. Each row displays the user's avatar, name,
/// and a "移除" (Remove) button to unblock them. An empty state with the
/// message "暂无黑名单" is shown when there are no blocked users.
class LingBlackList extends StatelessWidget {
  final List<LingChatUser> blockedUsers;
  final ValueChanged<LingChatUser> onRemove;

  const LingBlackList({
    super.key,
    required this.blockedUsers,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (blockedUsers.isEmpty) {
      return const LingEmptyState(
        icon: Icons.block_outlined,
        title: '暂无黑名单',
        message: '被拉黑的用户会显示在这里',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.spacingSm,
      ),
      itemCount: blockedUsers.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: AppConstants.spacingMd + LingAvatarSize.lg.value,
        color: theme.colorScheme.outlineVariant,
      ),
      itemBuilder: (context, index) {
        final user = blockedUsers[index];
        return _BlackListItem(
          user: user,
          onRemove: () => onRemove(user),
        );
      },
    );
  }
}

/// A single blocked user row for [LingBlackList].
class _BlackListItem extends StatelessWidget {
  final LingChatUser user;
  final VoidCallback onRemove;

  const _BlackListItem({required this.user, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm + 2,
      ),
      child: Row(
        children: [
          LingAvatar(
            imageUrl: user.avatarUrl,
            name: user.name,
            size: LingAvatarSize.lg,
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Text(
              user.name,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          LingButton(
            label: '移除',
            icon: Icons.remove_circle_outline,
            variant: LingButtonVariant.outlined,
            size: LingButtonSize.small,
            foregroundColor: theme.colorScheme.error,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
