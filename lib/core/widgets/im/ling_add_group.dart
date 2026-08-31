import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_empty_state.dart';
import 'package:nudgee/core/widgets/inputs/ling_search_field.dart';
import 'package:nudgee/core/widgets/buttons/ling_button.dart';
import 'package:nudgee/core/widgets/im/ling_group_avatar.dart';

/// Add group page.
///
/// Shows a search field at the top and a list of group search results. Each
/// result row displays the group avatar ([LingGroupAvatar]), group name,
/// member count, and a "加入" (Join) button. An empty state is shown when
/// there are no results.
class LingAddGroup extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<String> onSearch;
  final List<LingConversation> searchResults;
  final ValueChanged<LingConversation> onJoinGroup;

  const LingAddGroup({
    super.key,
    required this.searchQuery,
    required this.onSearch,
    required this.searchResults,
    required this.onJoinGroup,
  });

  @override
  State<LingAddGroup> createState() => _LingAddGroupState();
}

class _LingAddGroupState extends State<LingAddGroup> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant LingAddGroup oldWidget) {
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
            hint: '搜索群组',
            onChanged: widget.onSearch,
          ),
          const SizedBox(height: AppConstants.spacingMd),
          // ── Results ──
          if (widget.searchResults.isEmpty)
            Expanded(
              child: LingEmptyState(
                icon: hasQuery ? Icons.group_off_outlined : Icons.group_add_outlined,
                title: hasQuery ? '未找到相关群组' : '搜索加入群组',
                message: hasQuery
                    ? '请检查群名称后重试'
                    : '输入群名称来搜索并加入群组',
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
                  final group = widget.searchResults[index];
                  return _AddGroupItem(
                    group: group,
                    onJoin: () => widget.onJoinGroup(group),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// A single search result row for [LingAddGroup].
class _AddGroupItem extends StatelessWidget {
  final LingConversation group;
  final VoidCallback onJoin;

  const _AddGroupItem({required this.group, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memberCount = group.members.length;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        children: [
          LingGroupAvatar(
            avatarUrls: group.members
                .map((m) => m.avatarUrl ?? '')
                .where((u) => u.isNotEmpty)
                .toList(),
            names: group.members.map((m) => m.name).toList(),
            size: 48,
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.group_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$memberCount 人',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          LingButton(
            label: '加入',
            icon: Icons.group_add_outlined,
            size: LingButtonSize.small,
            onPressed: onJoin,
          ),
        ],
      ),
    );
  }
}
