import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';
import 'package:nudgee/core/widgets/im/ling_group_avatar.dart';
import 'package:nudgee/core/widgets/inputs/ling_search_field.dart';

/// A forward-message selection page.
///
/// Shows a search field on top, a selectable conversation list in the middle,
/// and a "create new conversation" button at the bottom. Supports multi-select
/// and reports the selected conversation ids via [onForward].
class LingMessageForward extends StatefulWidget {
  /// Conversations available for forwarding.
  final List<LingConversation> conversations;

  /// Current user id (used to render group avatars).
  final String currentUserId;

  /// Called with the selected conversation ids when the user confirms.
  final ValueChanged<List<String>>? onForward;

  /// Callback for the "create new conversation" button.
  final VoidCallback? onCreateNew;

  /// Whether multi-select is enabled. Defaults to true.
  final bool multiSelect;

  /// Title shown in the app bar.
  final String title;

  const LingMessageForward({
    super.key,
    required this.conversations,
    required this.currentUserId,
    this.onForward,
    this.onCreateNew,
    this.multiSelect = true,
    this.title = '转发到',
  });

  @override
  State<LingMessageForward> createState() => _LingMessageForwardState();
}

class _LingMessageForwardState extends State<LingMessageForward> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selected = {};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LingConversation> get _filtered {
    if (_query.isEmpty) return widget.conversations;
    final q = _query.toLowerCase();
    return widget.conversations
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
  }

  void _toggle(String id) {
    setState(() {
      if (!widget.multiSelect) {
        _selected.clear();
        _selected.add(id);
      } else if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _confirm() {
    if (_selected.isEmpty) return;
    widget.onForward?.call(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.multiSelect && _selected.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: Text(
                '发送(${_selected.length})',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingMd,
              AppConstants.spacingSm,
              AppConstants.spacingMd,
              AppConstants.spacingSm,
            ),
            child: LingSearchField(
              controller: _searchController,
              hint: '搜索会话',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          // List
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final conv = _filtered[index];
                final selected = _selected.contains(conv.id);
                return _ForwardItem(
                  conversation: conv,
                  currentUserId: widget.currentUserId,
                  selected: selected,
                  showCheck: widget.multiSelect,
                  onTap: () {
                    if (widget.multiSelect) {
                      _toggle(conv.id);
                    } else {
                      widget.onForward?.call([conv.id]);
                    }
                  },
                );
              },
            ),
          ),
          // Create new
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: OutlinedButton.icon(
                onPressed: widget.onCreateNew,
                icon: const Icon(Icons.add),
                label: const Text('创建新会话'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusLg),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForwardItem extends StatelessWidget {
  final LingConversation conversation;
  final String currentUserId;
  final bool selected;
  final bool showCheck;
  final VoidCallback onTap;

  const _ForwardItem({
    required this.conversation,
    required this.currentUserId,
    required this.selected,
    required this.showCheck,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected
            ? theme.colorScheme.primaryContainer.withOpacity(0.25)
            : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm + 2,
        ),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Text(
                conversation.name,
                style: theme.textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showCheck)
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                size: 22,
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
        avatarUrls:
            others.map((u) => u.avatarUrl ?? '').where((u) => u.isNotEmpty).toList(),
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
}
