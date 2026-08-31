import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';

/// A user entry in the read / unread list.
class LingReadUser {
  /// The user who has read or not read the message.
  final LingChatUser user;

  /// When the user read the message. `null` for unread users.
  final DateTime? readAt;

  const LingReadUser({
    required this.user,
    this.readAt,
  });
}

/// A message read / unread detail panel.
///
/// Uses a [DefaultTabController] with a [TabBar] to switch between the
/// "已读(N)" and "未读(N)" tabs. Each tab lists users with their avatar,
/// name, and (for read users) the time they read the message.
class LingMessageReadReceipt extends StatelessWidget {
  /// Users who have read the message.
  final List<LingReadUser> readUsers;

  /// Users who have not yet read the message.
  final List<LingReadUser> unreadUsers;

  /// Title shown in the app bar. Defaults to "消息详情".
  final String title;

  /// Label for the read tab. Defaults to "已读".
  final String readLabel;

  /// Label for the unread tab. Defaults to "未读".
  final String unreadLabel;

  const LingMessageReadReceipt({
    super.key,
    required this.readUsers,
    required this.unreadUsers,
    this.title = '消息详情',
    this.readLabel = '已读',
    this.unreadLabel = '未读',
  });

  /// Convenience method to show this panel as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<LingReadUser> readUsers,
    required List<LingReadUser> unreadUsers,
    String title = '消息详情',
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
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => LingMessageReadReceipt(
          readUsers: readUsers,
          unreadUsers: unreadUsers,
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Column(
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
          // Title
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
          // Tab bar
          TabBar(
            tabAlignment: TabAlignment.start,
            isScrollable: true,
            dividerHeight: 0.5,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            tabs: [
              Tab(text: '$readLabel(${readUsers.length})'),
              Tab(text: '$unreadLabel(${unreadUsers.length})'),
            ],
          ),
          // Tab views
          Expanded(
            child: TabBarView(
              children: [
                _UserList(users: readUsers, showReadAt: true),
                _UserList(users: unreadUsers, showReadAt: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final List<LingReadUser> users;
  final bool showReadAt;

  const _UserList({required this.users, required this.showReadAt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Text(
            '暂无',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: AppConstants.spacingMd + 40,
        color: theme.dividerColor,
      ),
      itemBuilder: (context, index) {
        final u = users[index];
        return _UserTile(user: u, showReadAt: showReadAt);
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  final LingReadUser user;
  final bool showReadAt;

  const _UserTile({required this.user, required this.showReadAt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm + 2,
      ),
      child: Row(
        children: [
          LingAvatar(
            imageUrl: user.user.avatarUrl,
            name: user.user.name,
            size: LingAvatarSize.md,
            showRing: false,
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Text(
              user.user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (showReadAt && user.readAt != null)
            Text(
              _formatTime(user.readAt!),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }
}
