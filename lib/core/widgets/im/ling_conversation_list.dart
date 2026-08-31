import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/im/ling_conversation_item.dart';

/// A conversation list for IM.
///
/// Features:
/// - Search bar (optional)
/// - Sorted by pin status and last message time
/// - Tap to open conversation
/// - Long-press for context menu (pin, mute, delete)
/// - Empty state
class LingConversationList extends StatefulWidget {
  final List<LingConversation> conversations;
  final String currentUserId;
  final ValueChanged<LingConversation>? onConversationTap;
  final ValueChanged<LingConversation>? onConversationLongPress;
  final ValueChanged<LingConversation>? onPin;
  final ValueChanged<LingConversation>? onMute;
  final ValueChanged<LingConversation>? onDelete;
  final ValueChanged<LingConversation>? onMarkRead;
  final String? searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchTap;
  final Widget? header;
  final bool showSearch;

  const LingConversationList({
    super.key,
    required this.conversations,
    required this.currentUserId,
    this.onConversationTap,
    this.onConversationLongPress,
    this.onPin,
    this.onMute,
    this.onDelete,
    this.onMarkRead,
    this.searchQuery,
    this.onSearchChanged,
    this.onSearchTap,
    this.header,
    this.showSearch = true,
  });

  @override
  State<LingConversationList> createState() => _LingConversationListState();
}

class _LingConversationListState extends State<LingConversationList> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(LingConversationList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      _searchController.text = widget.searchQuery ?? '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Header
        if (widget.header != null) widget.header!,
        // Search bar
        if (widget.showSearch)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingSm,
            ),
            child: widget.onSearchTap != null
                ? _buildSearchEntry(context, theme)
                : TextField(
                    controller: _searchController,
                    onChanged: widget.onSearchChanged,
                    decoration: InputDecoration(
                      hintText: '搜索会话',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: widget.searchQuery != null &&
                              widget.searchQuery!.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                widget.onSearchChanged?.call('');
                              },
                              child: const Icon(Icons.clear, size: 18),
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusFull),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
          ),
        // List
        Expanded(
          child: widget.conversations.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: widget.conversations.length,
                  itemBuilder: (context, index) {
                    final conv = widget.conversations[index];
                    return Slidable(
                      key: ValueKey(conv.id),
                      // 右滑：标记已读 + 删除
                      endActionPane: ActionPane(
                        motion: const BehindMotion(),
                        extentRatio: 0.5,
                        children: [
                          if (conv.hasUnread)
                            SlidableAction(
                              onPressed: (_) =>
                                  widget.onMarkRead?.call(conv),
                              backgroundColor:
                                  theme.colorScheme.primary,
                              foregroundColor:
                                  theme.colorScheme.onPrimary,
                              icon: Icons.mark_chat_read_outlined,
                              label: '已读',
                            ),
                          SlidableAction(
                            onPressed: (_) =>
                                widget.onDelete?.call(conv),
                            backgroundColor:
                                theme.colorScheme.error,
                            foregroundColor:
                                theme.colorScheme.onError,
                            icon: Icons.delete_outline,
                            label: '删除',
                          ),
                        ],
                      ),
                      // 左滑：置顶 + 免打扰
                      startActionPane: ActionPane(
                        motion: const BehindMotion(),
                        extentRatio: 0.5,
                        children: [
                          SlidableAction(
                            onPressed: (_) =>
                                widget.onPin?.call(conv),
                            backgroundColor:
                                theme.colorScheme.primaryContainer,
                            foregroundColor:
                                theme.colorScheme.onPrimaryContainer,
                            icon: conv.isPinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin,
                            label: conv.isPinned ? '取消置顶' : '置顶',
                          ),
                          SlidableAction(
                            onPressed: (_) =>
                                widget.onMute?.call(conv),
                            backgroundColor:
                                theme.colorScheme.secondaryContainer,
                            foregroundColor:
                                theme.colorScheme.onSecondaryContainer,
                            icon: conv.isMuted
                                ? Icons.notifications
                                : Icons.notifications_off,
                            label: conv.isMuted ? '取消免打扰' : '免打扰',
                          ),
                        ],
                      ),
                      child: LingConversationItem(
                        conversation: conv,
                        currentUserId: widget.currentUserId,
                        onTap: () =>
                            widget.onConversationTap?.call(conv),
                        onLongPress: () =>
                            _showContextMenu(context, conv),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            '暂无会话',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 伪搜索框 — 点击后跳转到搜索页面
  Widget _buildSearchEntry(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: widget.onSearchTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              '搜索会话',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, LingConversation conv) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(conv.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(conv.isPinned ? '取消置顶' : '置顶'),
              onTap: () {
                Navigator.pop(context);
                widget.onPin?.call(conv);
              },
            ),
            ListTile(
              leading: Icon(conv.isMuted ? Icons.notifications : Icons.notifications_off),
              title: Text(conv.isMuted ? '取消免打扰' : '免打扰'),
              onTap: () {
                Navigator.pop(context);
                widget.onMute?.call(conv);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: Text('删除会话', style: TextStyle(color: theme.colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete?.call(conv);
              },
            ),
          ],
        ),
      ),
    );
  }
}
