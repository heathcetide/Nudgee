import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';
import 'package:nudgee/core/widgets/feedback/ling_bottom_sheet.dart';
import 'package:nudgee/core/widgets/inputs/ling_search_field.dart';

/// Role of a member within a group.
enum LingGroupMemberRole {
  /// The group owner.
  owner,

  /// A group administrator.
  admin,

  /// A regular member.
  member,
}

/// A group member list with an optional search bar.
///
/// Each row shows an avatar, name, and a role tag (群主 / 管理员 / 普通成员).
/// Long-pressing a row opens a [BottomSheet] action menu unless
/// [onMemberLongPress] is provided, in which case that callback is
/// invoked instead.
class LingGroupMemberList extends StatefulWidget {
  /// The full list of group members.
  final List<LingChatUser> members;

  /// The id of the group owner, if known.
  final String? ownerId;

  /// The ids of group administrators.
  final List<String> adminIds;

  /// Called when a member row is tapped.
  final ValueChanged<LingChatUser>? onMemberTap;

  /// Called when a member row is long-pressed. If null, a default
  /// [LingBottomSheet] action menu is shown.
  final ValueChanged<LingChatUser>? onMemberLongPress;

  /// Whether to show the search bar at the top. Defaults to true.
  final bool showSearch;

  const LingGroupMemberList({
    super.key,
    required this.members,
    this.ownerId,
    this.adminIds = const [],
    this.onMemberTap,
    this.onMemberLongPress,
    this.showSearch = true,
  });

  @override
  State<LingGroupMemberList> createState() => _LingGroupMemberListState();
}

class _LingGroupMemberListState extends State<LingGroupMemberList> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  LingGroupMemberRole _roleOf(LingChatUser user) {
    if (user.id == widget.ownerId) return LingGroupMemberRole.owner;
    if (widget.adminIds.contains(user.id)) return LingGroupMemberRole.admin;
    return LingGroupMemberRole.member;
  }

  List<LingChatUser> get _filtered {
    if (_query.isEmpty) return widget.members;
    final q = _query.toLowerCase();
    return widget.members
        .where((u) => u.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;

    // Owner first, then admins, then members.
    filtered.sort((a, b) {
      final ra = _roleOf(a);
      final rb = _roleOf(b);
      return ra.index.compareTo(rb.index);
    });

    return Column(
      children: [
        if (widget.showSearch) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingSm,
            ),
            child: LingSearchField(
              controller: _searchCtrl,
              hint: '搜索群成员',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
        ],
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    '未找到成员',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 72,
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    return _MemberRow(
                      user: user,
                      role: _roleOf(user),
                      onTap: widget.onMemberTap != null
                          ? () => widget.onMemberTap!(user)
                          : null,
                      onLongPress: () => _handleLongPress(context, user),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _handleLongPress(BuildContext context, LingChatUser user) {
    if (widget.onMemberLongPress != null) {
      widget.onMemberLongPress!(user);
      return;
    }

    LingBottomSheet.showActions<void>(
      context: context,
      title: user.name,
      actions: [
        const LingSheetAction<void>(
          value: null,
          label: '查看资料',
          icon: Icons.person_outline,
        ),
        const LingSheetAction<void>(
          value: null,
          label: '发消息',
          icon: Icons.chat_bubble_outline,
        ),
        const LingSheetAction<void>(
          value: null,
          label: '设为管理员',
          icon: Icons.manage_accounts_outlined,
        ),
        const LingSheetAction<void>(
          value: null,
          label: '移出群聊',
          icon: Icons.person_remove_outlined,
          isDestructive: true,
        ),
      ],
    );
  }
}

/// A single member row.
class _MemberRow extends StatelessWidget {
  final LingChatUser user;
  final LingGroupMemberRole role;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _MemberRow({
    required this.user,
    required this.role,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
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
              showOnlineStatus: true,
              isOnline: user.isOnline,
            ),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Text(
                user.name,
                style: theme.textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _RoleTag(role: role),
          ],
        ),
      ),
    );
  }
}

/// A small colored tag indicating a member's role.
class _RoleTag extends StatelessWidget {
  final LingGroupMemberRole role;

  const _RoleTag({required this.role});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, fg, bg) = switch (role) {
      LingGroupMemberRole.owner => (
        '群主',
        Colors.white,
        AppColors.warning,
      ),
      LingGroupMemberRole.admin => (
        '管理员',
        Colors.white,
        theme.colorScheme.primary,
      ),
      LingGroupMemberRole.member => (
        '成员',
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.surfaceContainerHighest,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
