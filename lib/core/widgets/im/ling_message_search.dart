import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/services/chat_service.dart';
import 'package:nudgee/core/widgets/inputs/ling_search_field.dart';

/// A single search result pairing a [LingMessage] with its context.
class LingMessageSearchResult {
  /// The matched message.
  final LingMessage message;

  /// Name of the conversation this message belongs to.
  final String conversationName;

  /// Display name of the message author.
  final String authorName;

  const LingMessageSearchResult({
    required this.message,
    required this.conversationName,
    required this.authorName,
  });
}

/// A chat-history search page.
///
/// Shows an auto-focused search field at the top and a list of matching
/// messages below. Each result displays the message content, the conversation
/// name, the author name, and the timestamp. Matched keywords are highlighted
/// in yellow via [RichText].
class LingMessageSearch extends StatefulWidget {
  /// Initial search results to render (optional).
  final List<LingMessageSearchResult> results;

  /// Called whenever the search query changes.
  /// Should return updated results that will be displayed.
  /// If null, the page manages its own search via ChatService.
  final Future<List<LingMessageSearchResult>> Function(String query)? onSearch;

  /// Called when a result row is tapped.
  final ValueChanged<LingMessageSearchResult> onResultTap;

  /// Hint text for the search field.
  final String searchHint;

  /// Title shown in the app bar.
  final String title;

  /// Conversation ID to scope the search to (null = search all).
  final String? conversationId;

  /// User map for resolving author names.
  final Map<String, LingChatUser> userMap;

  /// Conversation list for resolving conversation names.
  final List<LingConversation> conversations;

  const LingMessageSearch({
    super.key,
    this.results = const [],
    this.onSearch,
    required this.onResultTap,
    this.searchHint = '搜索聊天记录',
    this.title = '搜索',
    this.conversationId,
    this.userMap = const {},
    this.conversations = const [],
  });

  @override
  State<LingMessageSearch> createState() => _LingMessageSearchState();
}

class _LingMessageSearchState extends State<LingMessageSearch> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  List<LingMessageSearchResult> _results = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _results = widget.results;
    // Auto-focus the search field after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _doSearch(v);
    });
  }

  Future<void> _doSearch(String query) async {
    setState(() => _isSearching = true);

    try {
      List<LingMessageSearchResult> results;

      if (widget.onSearch != null) {
        results = await widget.onSearch!(query);
      } else {
        // Use ChatService directly.
        final chatService = sl<ChatService>();
        final messages = widget.conversationId != null
            ? await chatService.searchMessagesInConversation(widget.conversationId!, query)
            : await chatService.searchMessages(query);

        results = messages.map((m) {
          final conv = widget.conversations.where((c) => c.id == m.conversationId).firstOrNull;
          final authorName = widget.userMap[m.authorId]?.name ?? m.authorId;
          return LingMessageSearchResult(
            message: m,
            conversationName: conv?.name ?? m.conversationId,
            authorName: authorName,
          );
        }).toList();
      }

      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 搜索框 + 取消按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                AppConstants.spacingSm + 4,
                AppConstants.spacingSm,
                AppConstants.spacingSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: LingSearchField(
                      controller: _controller,
                      hint: widget.searchHint,
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      '取消',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _results.isEmpty
                    ? _buildEmpty(theme)
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: AppConstants.spacingMd,
                          color: theme.dividerColor,
                        ),
                        itemBuilder: (context, index) {
                          final r = _results[index];
                          return _ResultTile(
                            result: r,
                            query: _query,
                            onTap: () => widget.onResultTap(r),
                          );
                        },
                      ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    final text = _query.isEmpty ? '输入关键词搜索聊天记录' : '没有找到相关消息';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final LingMessageSearchResult result;
  final String query;
  final VoidCallback onTap;

  const _ResultTile({
    required this.result,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = result.message;
    final content = msg.text ?? _fallbackContent(msg);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Conversation name + time
            Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    result.conversationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  _formatTime(msg.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingXs),
            // Author name
            Text(
              result.authorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            // Message content with highlight
            _HighlightedText(
              text: content,
              query: query,
              normalStyle: theme.textTheme.bodyMedium ?? const TextStyle(),
            ),
          ],
        ),
      ),
    );
  }

  String _fallbackContent(LingMessage msg) {
    switch (msg.type) {
      case LingMessageType.image:
        return '[图片]';
      case LingMessageType.audio:
        return '[语音]';
      case LingMessageType.video:
        return '[视频]';
      case LingMessageType.file:
        return '[文件] ${msg.mediaName ?? ''}';
      case LingMessageType.system:
        return '[系统消息]';
      case LingMessageType.custom:
        return '[自定义消息]';
      case LingMessageType.text:
        return msg.text ?? '';
    }
  }

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}

/// Renders [text] with all case-insensitive occurrences of [query]
/// highlighted in yellow.
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle normalStyle;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.normalStyle,
  });

  @override
  Widget build(BuildContext context) {
    final spans = _buildSpans();
    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: normalStyle,
        children: spans,
      ),
    );
  }

  List<InlineSpan> _buildSpans() {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final highlightStyle = normalStyle.copyWith(
      backgroundColor: const Color(0xFFFFEB3B),
      color: const Color(0xFF1A1A1A),
    );

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <InlineSpan>[];
    var start = 0;

    while (start < text.length) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: highlightStyle,
        ),
      );
      start = index + query.length;
    }

    return spans;
  }
}
