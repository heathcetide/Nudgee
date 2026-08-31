import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';

/// A candidate panel shown when the user types `@` in a chat.
///
/// Displays the group member list with avatar, name, and signature.
/// Members are filtered by [query] (matched against name or id).
class LingAtMentionPanel extends StatelessWidget {
  final List<LingChatUser> members;
  final ValueChanged<LingChatUser> onMemberSelected;
  final String query;

  const LingAtMentionPanel({
    super.key,
    required this.members,
    required this.onMemberSelected,
    this.query = '',
  });

  List<LingChatUser> get _filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return members;
    return members
        .where((m) =>
            m.name.toLowerCase().contains(q) ||
            m.id.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = _filtered;

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingLg),
                child: Text(
                  '没有匹配的成员',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: list.length,
              separatorBuilder: (_, __) => Divider(
                height: 0.5,
                color: theme.dividerColor,
                indent: 64,
              ),
              itemBuilder: (context, index) {
                final member = list[index];
                return _MentionTile(
                  member: member,
                  onTap: () => onMemberSelected(member),
                  highlight: query.trim().isNotEmpty,
                  query: query.trim(),
                );
              },
            ),
    );
  }
}

class _MentionTile extends StatelessWidget {
  final LingChatUser member;
  final VoidCallback onTap;
  final bool highlight;
  final String query;

  const _MentionTile({
    required this.member,
    required this.onTap,
    required this.highlight,
    required this.query,
  });

  String? get _signature =>
      member.metadata?['signature'] as String? ?? member.metadata?['bio'] as String?;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signature = _signature;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm,
        ),
        child: Row(
          children: [
            LingAvatar(
              imageUrl: member.avatarUrl,
              name: member.name,
              size: LingAvatarSize.sm,
              showOnlineStatus: true,
              isOnline: member.isOnline,
            ),
            const SizedBox(width: AppConstants.spacingSm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (signature != null && signature.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      signature,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.alternate_email,
              size: AppConstants.iconSm,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }
}
