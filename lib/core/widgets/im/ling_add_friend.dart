import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';
import 'package:nudgee/core/widgets/feedback/ling_empty_state.dart';
import 'package:nudgee/core/widgets/inputs/ling_search_field.dart';
import 'package:nudgee/core/widgets/buttons/ling_button.dart';

/// Add friend page.
///
/// Shows a search field at the top (search by ID or username) and a list of
/// search results. Each result row displays the user's avatar, name, ID, and
/// an "添加" (Add) button. An empty state is shown when there are no results.
class LingAddFriend extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<String> onSearch;
  final List<LingChatUser> searchResults;
  final ValueChanged<LingChatUser> onAddFriend;

  const LingAddFriend({
    super.key,
    required this.searchQuery,
    required this.onSearch,
    required this.searchResults,
    required this.onAddFriend,
  });

  @override
  State<LingAddFriend> createState() => _LingAddFriendState();
}

class _LingAddFriendState extends State<LingAddFriend> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant LingAddFriend oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _controller.text) {
      _controller.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = widget.searchQuery.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Search field ──
          LingSearchField(
            controller: _controller,
            hint: '按 ID 或用户名搜索',
            onChanged: widget.onSearch,
          ),
          const SizedBox(height: AppConstants.spacingMd),
          // ── Results ──
          if (widget.searchResults.isEmpty)
            Expanded(
              child: LingEmptyState(
                icon: hasQuery ? Icons.person_search_outlined : Icons.person_add_outlined,
                title: hasQuery ? '未找到相关用户' : '搜索添加好友',
                message: hasQuery
                    ? '请检查 ID 或用户名后重试'
                    : '输入对方的 ID 或用户名来添加好友',
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: AppConstants.spacingLg),
                itemCount: widget.searchResults.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: AppConstants.spacingMd,
                  color: theme.colorScheme.outlineVariant,
                ),
                itemBuilder: (context, index) {
                  final user = widget.searchResults[index];
                  return _AddFriendItem(
                    user: user,
                    onAdd: () => widget.onAddFriend(user),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// A single search result row for [LingAddFriend].
class _AddFriendItem extends StatelessWidget {
  final LingChatUser user;
  final VoidCallback onAdd;

  const _AddFriendItem({required this.user, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.spacingSm,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${user.id}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          LingButton(
            label: '添加',
            icon: Icons.person_add_outlined,
            size: LingButtonSize.small,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
