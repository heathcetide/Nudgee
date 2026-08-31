import 'package:flutter/material.dart';

import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/im/ling_message_bubble.dart';
import 'package:nudgee/core/widgets/im/ling_message_date_separator.dart';
import 'package:nudgee/core/widgets/im/ling_message_load_more.dart';
import 'package:nudgee/core/widgets/im/ling_message_scroll_to_bottom.dart';
import 'package:nudgee/core/widgets/im/ling_typing_indicator.dart';

/// A scrollable message list for IM chat.
///
/// Features:
/// - Reverse scrolling (newest at bottom)
/// - Date separators
/// - Load more on scroll to top
/// - Typing indicator
/// - Scroll-to-bottom button
/// - Auto-scroll on new message
class LingMessageList extends StatefulWidget {
  final List<LingMessage> messages;
  final String currentUserId;
  final Map<String, LingChatUser> userMap;
  final bool isGroup;
  final bool isTyping;
  final VoidCallback? onLoadMore;
  final bool hasMore;
  final bool isLoadingMore;
  final ValueChanged<LingMessage>? onMessageLongPress;
  final ValueChanged<LingMessage>? onMessageTap;
  final ValueChanged<LingChatUser>? onAvatarTap;
  final ValueChanged<LingChatUser>? onContactCardTap;
  final ValueChanged<String>? onReactionTapped;
  final Widget? typingIndicator;
  final String? selfAvatarUrl;
  final Set<String>? selectedMessageIds;
  final bool multiSelectMode;

  const LingMessageList({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.userMap,
    this.isGroup = false,
    this.isTyping = false,
    this.onLoadMore,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.onMessageLongPress,
    this.onMessageTap,
    this.onAvatarTap,
    this.onContactCardTap,
    this.onReactionTapped,
    this.typingIndicator,
    this.selfAvatarUrl,
    this.selectedMessageIds,
    this.multiSelectMode = false,
  });

  @override
  State<LingMessageList> createState() => _LingMessageListState();
}

class _LingMessageListState extends State<LingMessageList> {
  final ScrollController _controller = ScrollController();
  bool _showScrollToBottom = false;
  int _lastMessageCount = 0;
  int _unreadSinceBottom = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _lastMessageCount = widget.messages.length;
    // 初始滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients && _controller.position.maxScrollExtent > 0) {
        _controller.jumpTo(_controller.position.maxScrollExtent);
      }
    });
  }

  @override
  void didUpdateWidget(LingMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to bottom when new message arrives
    if (widget.messages.length > _lastMessageCount) {
      // 如果不在底部，增加未读计数
      if (_showScrollToBottom) {
        _unreadSinceBottom += widget.messages.length - _lastMessageCount;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_controller.hasClients &&
              _controller.position.maxScrollExtent > 0) {
            _controller.animateTo(
              _controller.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
    _lastMessageCount = widget.messages.length;
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when near top
    if (_controller.position.pixels < 100 && widget.onLoadMore != null && widget.hasMore && !widget.isLoadingMore) {
      widget.onLoadMore!();
    }
    // Show scroll-to-bottom button
    final max = _controller.position.maxScrollExtent;
    final current = _controller.position.pixels;
    final shouldShow = max - current > 200;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  void _scrollToBottom() {
    _controller.animateTo(
      _controller.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    setState(() => _unreadSinceBottom = 0);
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.messages.length + (widget.isTyping ? 1 : 0) + 1;
    return Stack(
      children: [
        ListView.builder(
          controller: _controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            // Index 0: Load more indicator
            if (index == 0 && widget.hasMore) {
              return LingMessageLoadMore(
                isLoading: widget.isLoadingMore,
                onLoadMore: () => widget.onLoadMore?.call(),
              );
            }
            // Adjust index for messages
            final msgIndex = widget.hasMore ? index - 1 : index;
            // Typing indicator at the end
            if (widget.isTyping && msgIndex == widget.messages.length) {
              return RepaintBoundary(
                child: widget.typingIndicator != null
                    ? widget.typingIndicator!
                    : const Padding(
                        padding: EdgeInsets.only(left: 16, top: 4),
                        child: LingTypingIndicator(),
                      ),
              );
            }
            final msg = widget.messages[msgIndex];
            final isOutgoing = msg.isFrom(widget.currentUserId);
            final author = widget.userMap[msg.authorId];
            final showDate = _shouldShowDateSeparator(msgIndex);
            final isSelected =
                widget.selectedMessageIds?.contains(msg.id) ?? false;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showDate) LingMessageDateSeparator(date: msg.createdAt),
                RepaintBoundary(
                  child: LingMessageBubble(
                    message: msg,
                    isOutgoing: isOutgoing,
                    currentUserId: widget.currentUserId,
                    showAvatar: true,
                    showAuthorName: widget.isGroup && !isOutgoing,
                    authorName: author?.name,
                    authorAvatarUrl: author?.avatarUrl,
                    selfAvatarUrl: widget.selfAvatarUrl,
                    selected: isSelected,
                    onLongPress: () =>
                        widget.onMessageLongPress?.call(msg),
                    onTap: () => widget.onMessageTap?.call(msg),
                    onAvatarTap: () {
                      if (author != null) {
                        widget.onAvatarTap?.call(author);
                      }
                    },
                    onContactCardTap: () {
                      final meta = msg.metadata;
                      if (meta != null && meta['contactId'] != null) {
                        final user =
                            widget.userMap[meta['contactId'] as String];
                        if (user != null) {
                          widget.onContactCardTap?.call(user);
                        }
                      }
                    },
                    onReactionTapped: (emoji) =>
                        widget.onReactionTapped?.call(emoji),
                  ),
                ),
              ],
            );
          },
        ),
        // Scroll to bottom button
        if (_showScrollToBottom)
          Positioned(
            right: 16,
            bottom: 16,
            child: LingMessageScrollToBottom(
              unreadCount: _unreadSinceBottom,
              onTap: _scrollToBottom,
            ),
          ),
      ],
    );
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    final current = widget.messages[index].createdAt;
    final previous = widget.messages[index - 1].createdAt;
    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }
}
