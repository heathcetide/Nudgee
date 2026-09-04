import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/services/chat_service.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';
import 'package:nudgee/core/widgets/feedback/ling_file_viewer.dart';
import 'package:nudgee/core/widgets/feedback/ling_image_viewer.dart';
import 'package:nudgee/core/widgets/feedback/ling_web_view_page.dart';
import 'package:nudgee/core/widgets/feedback/ling_mermaid_viewer.dart';
import 'package:nudgee/core/widgets/im/ling_link_preview.dart';
import 'package:nudgee/core/widgets/im/ling_link_preview_fetcher.dart';
import 'package:nudgee/core/widgets/im/ling_message_reaction.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// A message bubble for IM chat.
///
/// Renders different content based on [LingMessageType]:
/// - text: text content
/// - image: image thumbnail
/// - audio: waveform + play button + duration
/// - video: thumbnail + play icon
/// - file: file icon + name + size
/// - system: centered system message
///
/// Supports:
/// - Incoming/outgoing alignment
/// - Avatar (for incoming group messages)
/// - Author name (for incoming group messages)
/// - Timestamp
/// - Status indicators (sending/sent/delivered/read/failed)
/// - Reactions
/// - Reply quote
/// - Long-press callback
class LingMessageBubble extends StatelessWidget {
  final LingMessage message;
  final bool isOutgoing;
  final bool showAvatar;
  final bool showAuthorName;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? selfAvatarUrl;
  final String currentUserId;
  final bool selected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onContactCardTap;
  final ValueChanged<String>? onReactionTapped;
  final Widget? customContent;

  const LingMessageBubble({
    super.key,
    required this.message,
    required this.isOutgoing,
    required this.currentUserId,
    this.showAvatar = false,
    this.showAuthorName = false,
    this.authorName,
    this.authorAvatarUrl,
    this.selfAvatarUrl,
    this.selected = false,
    this.onLongPress,
    this.onTap,
    this.onAvatarTap,
    this.onContactCardTap,
    this.onReactionTapped,
    this.customContent,
  });

  @override
  Widget build(BuildContext context) {
    // System messages are centered, no bubble
    if (message.type == LingMessageType.system) {
      return _buildSystemMessage(context);
    }

    final theme = Theme.of(context);
    final bubbleColor = isOutgoing
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isOutgoing ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 3,
        bottom: 3,
      ),
      child: Column(
        crossAxisAlignment: isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Author name (incoming group)
          if (showAuthorName && !isOutgoing && authorName != null)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 2),
              child: Text(
                authorName!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // Bubble row
          GestureDetector(
            onLongPress: onLongPress,
            onTap: onTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              textDirection: isOutgoing ? TextDirection.rtl : TextDirection.ltr,
              children: [
                // Avatar (both sides)
                if (showAvatar)
                  GestureDetector(
                    onTap: onAvatarTap,
                    child: Padding(
                      padding: EdgeInsets.only(right: isOutgoing ? 0 : 8, left: isOutgoing ? 8 : 0),
                      child: LingAvatar(
                        imageUrl: isOutgoing ? selfAvatarUrl : authorAvatarUrl,
                        name: isOutgoing ? '我' : authorName,
                        size: LingAvatarSize.sm,
                      ),
                    ),
                  ),
                // Bubble
                Flexible(
                  child: Container(
                    padding: _bubblePadding(),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: _bubbleBorderRadius(),
                      border: selected
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Reply quote
                        if (message.replyTo != null) _buildReplyQuote(context, textColor),
                        // Ordered segments (new) or legacy layout (backward compat)
                        if (message.metadata?['segments'] != null)
                          ..._buildOrderedSegments(context, textColor)
                        else ...[
                          // Legacy: thinking → tool calls → content
                          if (message.metadata?['thinking'] != null)
                            _buildThinkingBlock(context, textColor),
                          if (message.metadata?['toolCalls'] != null)
                            _buildToolCallsBlock(context, textColor),
                          customContent ?? _buildContent(context, textColor),
                        ],
                        // Time + status
                        const SizedBox(height: 2),
                        _buildTimeAndStatus(context, textColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Reactions
          if (message.hasReactions)
            Padding(
              padding: EdgeInsets.only(
                left: isOutgoing ? 0 : (showAvatar ? 40 : 4),
                top: 2,
              ),
              child: LingMessageReactions(
                reactions: message.reactions,
                currentUserId: currentUserId,
                onReactionTapped: onReactionTapped,
              ),
            ),
        ],
      ),
    );
  }

  EdgeInsets _bubblePadding() {
    switch (message.type) {
      case LingMessageType.image:
      case LingMessageType.video:
        return const EdgeInsets.all(2);
      case LingMessageType.audio:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      default:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    }
  }

  BorderRadius _bubbleBorderRadius() {
    const radius = 16.0;
    if (isOutgoing) {
      return BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(radius),
        bottomRight: Radius.circular(4),
      );
    }
    return BorderRadius.only(
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
      bottomLeft: Radius.circular(4),
      bottomRight: Radius.circular(radius),
    );
  }

  /// Build ordered segments — renders thinking, tool calls, and content
  /// in the order they actually occurred during the agent run.
  ///
  /// This replaces the legacy layout (thinking → all tools → all content)
  /// with an interleaved view:
  /// ```
  /// [thinking] Let me search...
  /// [tool call] web.search "flutter"
  /// [content] Based on the results...
  /// [tool call] workspace.fs write
  /// [content] Done!
  /// ```
  List<Widget> _buildOrderedSegments(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    final segmentsRaw = message.metadata?['segments'];
    if (segmentsRaw is! List || segmentsRaw.isEmpty) return [];

    // Safely cast — segments from JSON may have dynamic element types.
    final segments = <Map<String, dynamic>>[];
    for (final s in segmentsRaw) {
      if (s is Map<String, dynamic>) {
        segments.add(s);
      } else if (s is Map) {
        segments.add(Map<String, dynamic>.from(s));
      }
    }
    if (segments.isEmpty) return [];
    final widgets = <Widget>[];

    for (final seg in segments) {
      final type = seg['type'] as String?;
      switch (type) {
        case 'thinking':
          final text = seg['text'] as String? ?? '';
          if (text.isNotEmpty) {
            widgets.add(_ThinkingBlock(
              thinking: text,
              textColor: textColor,
              theme: theme,
              isStreaming: false,
            ));
          }
          break;

        case 'content':
          final text = seg['text'] as String? ?? '';
          final isIntermediate = seg['intermediate'] == true;
          final isStreaming = message.metadata?['streaming'] == true;
          if (text.isNotEmpty) {
            if (isIntermediate) {
              // Intermediate content (AI narrating before tool call) — small, muted
              widgets.add(Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: SelectableText(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColor.withAlpha(140),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ));
            } else {
              // Final content — collapsible if long.
              // During streaming, force plain Text (no Markdown) for performance.
              widgets.add(_CollapsibleContent(
                text: text,
                textColor: textColor,
                isAiMessage: !isStreaming &&
                    message.authorId == ChatService.aiAssistantId,
              ));
            }
          }
          break;

        case 'toolCall':
          widgets.add(_buildSegmentToolCallCard(context, seg));
          break;
      }
    }

    return widgets;
  }

  /// Build a single tool call card from a segment.
  Widget _buildSegmentToolCallCard(BuildContext context, Map<String, dynamic> seg) {
    final theme = Theme.of(context);
    final name = seg['name'] as String? ?? 'unknown';
    final status = seg['status'] as String? ?? 'running';
    // Safely handle arguments — may be Map<String,dynamic> or Map from JSON.
    final argsRaw = seg['arguments'];
    final args = argsRaw is Map<String, dynamic>
        ? argsRaw
        : argsRaw is Map
            ? Map<String, dynamic>.from(argsRaw)
            : <String, dynamic>{};
    final result = seg['result'] as String?;
    final isError = status == 'error';
    final isRunning = status == 'running';

    // Status icon & color
    final color = isError
        ? theme.colorScheme.error
        : isRunning
            ? theme.colorScheme.primary
            : Colors.green;
    final statusIcon = isError
        ? Icons.close
        : isRunning
            ? Icons.autorenew
            : Icons.check;

    // Build summary
    String summary = _buildToolSummary(name, args);

    return _DevinToolCallCard(
      name: name,
      summary: summary,
      status: status,
      color: color,
      statusIcon: statusIcon,
      isRunning: isRunning,
      isError: isError,
      args: args,
      result: result,
    );
  }

  String _buildToolSummary(String name, Map<String, dynamic> args) {
    switch (name) {
      case 'workspace.fs':
        final action = args['action'] as String? ?? '';
        final path = args['path'] as String? ?? '';
        if (action == 'write' || action == 'read') {
          final content = args['content'] as String? ?? '';
          final lines = content.split('\n').length;
          return '$action → $path ($lines 行)';
        }
        return '$action → $path';
      case 'workspace.js.exec':
        final code = args['code'] as String? ?? '';
        return '执行 ${code.split('\n').length} 行 JS';
      case 'cloud.exec':
        final lang = args['language'] as String? ?? '';
        final code = args['code'] as String? ?? '';
        return '$lang · ${code.split('\n').length} 行';
      case 'web.search':
        final query = args['query'] as String? ?? '';
        return query.length > 40 ? '${query.substring(0, 40)}…' : query;
      case 'github.search':
        final query = args['query'] as String? ?? '';
        final type = args['type'] as String? ?? 'repositories';
        return '$type: $query';
      default:
        for (final entry in args.entries) {
          if (entry.value is String && entry.value.toString().isNotEmpty) {
            final val = entry.value.toString();
            return val.length > 50 ? '${val.substring(0, 50)}…' : val;
          }
        }
        return '';
    }
  }

  /// Build a collapsible thinking/reasoning block for AI messages.
  Widget _buildThinkingBlock(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    final thinking = message.metadata?['thinking'] as String? ?? '';
    if (thinking.isEmpty) return const SizedBox.shrink();
    final isStreaming = message.metadata?['thinkingStreaming'] == true;

    return _ThinkingBlock(
      thinking: thinking,
      textColor: textColor,
      theme: theme,
      isStreaming: isStreaming,
    );
  }

  /// Build a tool calls display block for agent-based AI messages.
  ///
  /// Shows each tool call with its name, status (running/success/error),
  /// and expandable arguments + results.
  Widget _buildToolCallsBlock(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    final toolCallsRaw = message.metadata?['toolCalls'];
    if (toolCallsRaw is! List || toolCallsRaw.isEmpty) {
      return const SizedBox.shrink();
    }

    // Safely cast — toolCalls from JSON may have dynamic element types.
    final toolCalls = <Map<String, dynamic>>[];
    for (final t in toolCallsRaw) {
      if (t is Map<String, dynamic>) {
        toolCalls.add(t);
      } else if (t is Map) {
        toolCalls.add(Map<String, dynamic>.from(t));
      }
    }
    if (toolCalls.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(60),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.build_circle, size: 14,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '工具调用 (${toolCalls.length})',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Tool call items
          for (final tc in toolCalls) _buildToolCallItem(context, tc),
        ],
      ),
    );
  }

  /// Build a single tool call item.
  Widget _buildToolCallItem(BuildContext context, Map<String, dynamic> tc) {
    final theme = Theme.of(context);
    final name = tc['name'] as String? ?? 'unknown';
    final status = tc['status'] as String? ?? 'running';
    final args = tc['arguments'];
    final result = tc['result'] as String?;

    final (icon, color, label) = switch (status) {
      'running' => (Icons.hourglass_top, theme.colorScheme.primary, '执行中...'),
      'success' => (Icons.check_circle, Colors.green, '完成'),
      'error' => (Icons.error, theme.colorScheme.error, '失败'),
      _ => (Icons.help, theme.colorScheme.onSurfaceVariant, status),
    };

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 10),
      dense: true,
      leading: Icon(icon, size: 16, color: color),
      title: Text(
        name,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
      children: [
        // Arguments
        if (args != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('参数',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 2),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withAlpha(100),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    _formatArgs(args),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Result
        if (result != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('结果',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: status == 'error'
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 2),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: status == 'error'
                        ? theme.colorScheme.errorContainer.withAlpha(40)
                        : theme.colorScheme.surfaceContainerHighest
                            .withAlpha(100),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      result.length > 500
                          ? '${result.substring(0, 500)}...'
                          : result,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Format tool arguments for display.
  String _formatArgs(dynamic args) {
    if (args is Map) {
      try {
        return const JsonEncoder.withIndent('  ').convert(args);
      } catch (_) {
        return args.toString();
      }
    }
    return args?.toString() ?? '(none)';
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    switch (message.type) {
      case LingMessageType.text:
        return _buildText(context, textColor);
      case LingMessageType.image:
        // Image + text combined (like QQ)
        if (message.text != null && message.text!.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildImage(context),
              const SizedBox(height: 6),
              _buildText(context, textColor, suppressLinkPreview: true),
            ],
          );
        }
        return _buildImage(context);
      case LingMessageType.audio:
        return _buildAudio(context, textColor);
      case LingMessageType.video:
        return _buildVideo(context);
      case LingMessageType.file:
        return _buildFile(context, textColor);
      case LingMessageType.system:
        return Text(
          message.text ?? '',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
        );
      case LingMessageType.custom:
        return _buildCustom(context, textColor);
    }
  }

  /// URL 正则
  static final _urlRegex = RegExp(
    r'https?://[^\s<>\u4e00-\u9fff]+',
    caseSensitive: false,
  );

  Widget _buildText(BuildContext context, Color textColor,
      {bool suppressLinkPreview = false}) {
    final text = message.text ?? '';

    // AI assistant messages are rendered as Markdown.
    final isAiMessage = message.authorId == ChatService.aiAssistantId;
    final isStreaming = message.metadata?['streaming'] == true;
    // During streaming, use plain Text for performance (no Markdown parsing).
    final renderAsMarkdown = isAiMessage && !isStreaming;
    // Long messages (both AI and plain) use collapsible widget
    if (text.length > 500) {
      return _CollapsibleContent(
        text: text,
        textColor: textColor,
        isAiMessage: renderAsMarkdown,
      );
    }
    if (renderAsMarkdown) {
      return _buildMarkdownText(context, textColor, text);
    }

    if (suppressLinkPreview) {
      return Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
      );
    }

    final urlMatch = _urlRegex.firstMatch(text);
    if (urlMatch == null) {
      return Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
      );
    }

    final url = urlMatch.group(0)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
        ),
        const SizedBox(height: 6),
        _LinkPreviewCard(url: url),
      ],
    );
  }

  /// Split markdown text into segments of text and mermaid code blocks.
  ///
  /// Mermaid blocks are fenced code blocks with `mermaid` as the language:
  /// ```mermaid
  /// graph TD; A-->B;
  /// ```
  List<_MdSegment> _splitMermaidBlocks(String text) {
    final segments = <_MdSegment>[];
    final mermaidRegex = RegExp(r'```mermaid\n([\s\S]*?)```');
    int lastEnd = 0;

    for (final match in mermaidRegex.allMatches(text)) {
      // Text before the mermaid block
      if (match.start > lastEnd) {
        segments.add(_MdSegment(_SegmentType.text, text.substring(lastEnd, match.start).trim()));
      }
      // The mermaid code itself
      segments.add(_MdSegment(_SegmentType.mermaid, match.group(1)!.trim()));
      lastEnd = match.end;
    }

    // Remaining text after the last mermaid block
    if (lastEnd < text.length) {
      segments.add(_MdSegment(_SegmentType.text, text.substring(lastEnd).trim()));
    }

    // If nothing was found, return the whole text as a single segment
    if (segments.isEmpty) {
      segments.add(_MdSegment(_SegmentType.text, text));
    }

    return segments;
  }

  /// Build Markdown-formatted text for AI messages.
  ///
  /// Extracts mermaid code blocks and renders them as interactive
  /// [LingMermaidPreview] widgets, with the remaining markdown rendered
  /// via [MarkdownBody].
  Widget _buildMarkdownText(BuildContext context, Color textColor, String text) {
    final theme = Theme.of(context);

    final segments = _splitMermaidBlocks(text);

    // No mermaid blocks — render as single MarkdownBody
    if (segments.length == 1 && segments.first.type == _SegmentType.text) {
      return MarkdownBody(
        data: segments.first.content,
        selectable: true,
        styleSheet: _markdownStyle(theme, textColor),
        onTapLink: (url, _, __) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LingWebViewPage(url: url, title: url),
            ),
          );
        },
      );
    }

    // Has mermaid blocks — render as column of mixed widgets
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final seg in segments) ...[
          if (seg.type == _SegmentType.text && seg.content.isNotEmpty)
            MarkdownBody(
              data: seg.content,
              selectable: true,
              styleSheet: _markdownStyle(theme, textColor),
              onTapLink: (url, _, __) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LingWebViewPage(url: url, title: url),
                  ),
                );
              },
            )
          else if (seg.type == _SegmentType.mermaid)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: LingMermaidPreview(mermaidCode: seg.content),
            ),
        ],
      ],
    );
  }

  /// Build the markdown style sheet shared by all MarkdownBody instances.
  MarkdownStyleSheet _markdownStyle(ThemeData theme, Color textColor) {
    final isDark = theme.brightness == Brightness.dark;
    return MarkdownStyleSheet(
      p: theme.textTheme.bodyMedium?.copyWith(color: textColor),
      h1: theme.textTheme.headlineSmall?.copyWith(
          color: textColor, fontWeight: FontWeight.bold),
      h2: theme.textTheme.titleLarge?.copyWith(
          color: textColor, fontWeight: FontWeight.bold),
      h3: theme.textTheme.titleMedium?.copyWith(
          color: textColor, fontWeight: FontWeight.bold),
      h4: theme.textTheme.titleSmall?.copyWith(
          color: textColor, fontWeight: FontWeight.bold),
      h5: theme.textTheme.labelLarge?.copyWith(
          color: textColor, fontWeight: FontWeight.bold),
      h6: theme.textTheme.labelMedium?.copyWith(
          color: textColor, fontWeight: FontWeight.bold),
      listBullet: theme.textTheme.bodyMedium?.copyWith(color: textColor),
      strong: theme.textTheme.bodyMedium
          ?.copyWith(color: textColor, fontWeight: FontWeight.bold),
      em: theme.textTheme.bodyMedium
          ?.copyWith(color: textColor, fontStyle: FontStyle.italic),
      blockquote: theme.textTheme.bodyMedium?.copyWith(
          color: textColor.withOpacity(0.8),
          fontStyle: FontStyle.italic),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: textColor.withOpacity(0.3),
            width: 3,
          ),
        ),
      ),
      code: theme.textTheme.bodySmall?.copyWith(
        color: textColor,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Courier', 'Menlo', 'Monaco'],
        backgroundColor: textColor.withOpacity(0.1),
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark
            ? textColor.withOpacity(0.08)
            : textColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      tableHead: theme.textTheme.bodyMedium
          ?.copyWith(color: textColor, fontWeight: FontWeight.bold),
      tableBody: theme.textTheme.bodyMedium?.copyWith(color: textColor),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 6),
      tableHeadAlign: TextAlign.center,
      a: theme.textTheme.bodyMedium?.copyWith(
        color: isOutgoing
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      listBulletPadding: const EdgeInsets.symmetric(horizontal: 4),
      listIndent: 24,
    );
  }

  Widget _buildCustom(BuildContext context, Color textColor) {
    final meta = message.metadata;
    if (meta != null) {
      // 联系人卡片
      if (meta['contactId'] != null) {
        return _buildContactCard(context, textColor);
      }
      // 位置卡片
      if (meta['latitude'] != null) {
        return _buildLocationCard(context, textColor);
      }
    }
    return Text(
      message.text ?? '[自定义消息]',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
    );
  }

  Widget _buildContactCard(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    final meta = message.metadata!;
    final name = meta['contactName'] as String? ?? '联系人';
    final avatar = meta['contactAvatar'] as String?;
    return GestureDetector(
      onTap: onContactCardTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LingAvatar(
              imageUrl: avatar,
              name: name,
              size: LingAvatarSize.sm,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '个人名片',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.contact_page, size: 16, color: textColor.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    final meta = message.metadata!;
    final name = meta['locationName'] as String? ?? '位置';
    final lat = (meta['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (meta['longitude'] as num?)?.toDouble() ?? 0.0;

    // AMap web URL — opens interactive map, no API key needed.
    final amapUrl =
        'https://uri.amap.com/marker?position=$lng,$lat&name=${Uri.encodeComponent(name)}&coordinate=wgs84&callnative=0';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LingWebViewPage(
              url: amapUrl,
              title: name,
            ),
          ),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Map placeholder area with gradient + pin
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.primaryContainer.withOpacity(0.3),
                      theme.colorScheme.surfaceContainerHighest,
                    ],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Grid pattern background
                    CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter: _MapGridPainter(
                        color: theme.colorScheme.outline.withOpacity(0.15),
                      ),
                    ),
                    // Pin
                    const Icon(Icons.location_on, color: Colors.red, size: 36),
                    // "点击查看地图" hint
                    Positioned(
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '点击查看地图',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Location name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: textColor.withOpacity(0.6)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.bodySmall?.copyWith(color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: textColor.withOpacity(0.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (message.mediaUrl == null) {
      return Container(
        width: 120,
        height: 120,
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image),
      );
    }
    final w = message.width?.toDouble() ?? 200.0;
    final h = message.height?.toDouble() ?? 150.0;
    // Clamp to reasonable bounds
    final displayW = w.clamp(80.0, 200.0);
    final displayH = h.clamp(80.0, 240.0);
    final url = message.mediaUrl!;
    final isLocalFile = url.startsWith('/') || url.startsWith('file://');

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LingImageViewer(
              images: [url],
              initialIndex: 0,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: displayW,
          height: displayH,
          child: isLocalFile
              ? Image.file(
                  File(url.replaceFirst('file://', '')),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  memCacheWidth: 400,
                  memCacheHeight: 400,
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image),
                  ),
                  progressIndicatorBuilder: (context, url, progress) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAudio(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    final duration = message.duration ?? Duration.zero;
    final mins = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_circle, color: textColor, size: 28),
        const SizedBox(width: 8),
        // Simple waveform bars
        Flexible(
          child: Container(
            height: 24,
            constraints: const BoxConstraints(maxWidth: 120),
            child: CustomPaint(
              painter: _SimpleWaveformPainter(
                color: textColor.withOpacity(0.6),
                bars: message.waveform ?? List.generate(20, (i) => 0.3 + (i % 3) * 0.2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$mins:$secs', style: theme.textTheme.labelSmall?.copyWith(color: textColor)),
      ],
    );
  }

  Widget _buildVideo(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 200,
            height: 120,
            color: Colors.black54,
            child: message.mediaUrl != null
                ? CachedNetworkImage(
                    imageUrl: message.mediaUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    memCacheHeight: 400,
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.video_library, color: Colors.white54, size: 32),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.video_library, color: Colors.white54, size: 32),
                  ),
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildFile(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    final sizeStr = message.mediaSize != null
        ? '${(message.mediaSize! / 1024).toStringAsFixed(1)} KB'
        : '';
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LingFileViewer(
              filePath: message.mediaUrl,
              fileName: message.mediaName,
              fileSize: message.mediaSize,
              fileUrl: message.mediaUrl,
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, color: textColor, size: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.mediaName ?? '文件',
                  style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sizeStr.isNotEmpty)
                  Text(sizeStr, style: theme.textTheme.labelSmall?.copyWith(color: textColor.withOpacity(0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyQuote(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    final reply = message.replyTo!;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: textColor.withOpacity(0.4), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            reply.authorName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            reply.preview,
            style: theme.textTheme.bodySmall?.copyWith(color: textColor.withOpacity(0.8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAndStatus(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    final time = '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: theme.textTheme.labelSmall?.copyWith(
            color: textColor.withOpacity(0.6),
            fontSize: 10,
          ),
        ),
        if (isOutgoing) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(context, textColor),
        ],
      ],
    );
  }

  Widget _buildStatusIcon(BuildContext context, Color textColor) {
    switch (message.status) {
      case LingMessageStatus.sending:
        return Icon(Icons.access_time, size: 12, color: textColor.withOpacity(0.5));
      case LingMessageStatus.sent:
        return Icon(Icons.check, size: 14, color: textColor.withOpacity(0.5));
      case LingMessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: textColor.withOpacity(0.5));
      case LingMessageStatus.read:
        return Icon(Icons.done_all, size: 14, color: textColor);
      case LingMessageStatus.failed:
        return Icon(Icons.error_outline, size: 14, color: Theme.of(context).colorScheme.error);
    }
  }

  Widget _buildSystemMessage(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message.text ?? '',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SimpleWaveformPainter extends CustomPainter {
  final Color color;
  final List<double> bars;

  _SimpleWaveformPainter({required this.color, required this.bars});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final barWidth = size.width / (bars.length * 1.5);
    final center = size.height / 2;
    for (int i = 0; i < bars.length; i++) {
      final x = i * barWidth * 1.5;
      final h = bars[i].clamp(0.1, 1.0) * size.height;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x + barWidth / 2, center), width: barWidth, height: h),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleWaveformPainter old) => old.color != color;
}

/// 异步抓取链接 metadata 并展示 LingLinkPreview 卡片
class _LinkPreviewCard extends StatefulWidget {
  final String url;
  const _LinkPreviewCard({required this.url});

  @override
  State<_LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<_LinkPreviewCard> {
  LingLinkMetadata? _meta;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMeta();
  }

  Future<void> _fetchMeta() async {
    final meta = await LingLinkPreviewFetcher.fetch(widget.url);
    if (mounted) {
      setState(() {
        _meta = meta;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return LingLinkPreview(
        url: widget.url,
        title: '加载中...',
        onTap: () => _openWebPage(context),
      );
    }

    return LingLinkPreview(
      url: widget.url,
      title: _meta?.title,
      description: _meta?.description,
      imageUrl: _meta?.imageUrl,
      onTap: () => _openWebPage(context),
    );
  }

  void _openWebPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LingWebViewPage(url: widget.url),
      ),
    );
  }
}

/// A collapsible thinking/reasoning block shown above AI message content.
class _ThinkingBlock extends StatefulWidget {
  final String thinking;
  final Color textColor;
  final ThemeData theme;
  final bool isStreaming;

  const _ThinkingBlock({
    required this.thinking,
    required this.textColor,
    required this.theme,
    this.isStreaming = false,
  });

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Auto-expand while streaming.
    _expanded = widget.isStreaming;
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoing = widget.textColor == widget.theme.colorScheme.onPrimary;
    final mutedColor = isOutgoing
        ? widget.theme.colorScheme.onPrimary.withAlpha(140)
        : widget.theme.colorScheme.onSurfaceVariant;
    final bgColor = isOutgoing
        ? widget.theme.colorScheme.primary.withAlpha(30)
        : widget.theme.colorScheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          // Left accent bar — quote/blockquote style.
          border: Border(
            left: BorderSide(
              color: mutedColor.withAlpha(80),
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (tap to toggle)
            InkWell(
              onTap: widget.isStreaming ? null : () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      widget.isStreaming ? EvaIcons.flash : EvaIcons.bulb,
                      size: 14,
                      color: mutedColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isStreaming
                          ? '思考中…'
                          : (_expanded ? '思考过程' : '查看思考过程'),
                      style: TextStyle(fontSize: 12, color: mutedColor),
                    ),
                    const Spacer(),
                    if (!widget.isStreaming)
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: mutedColor,
                      ),
                  ],
                ),
              ),
            ),
            // Thinking content (collapsible, auto-expanded while streaming)
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: mutedColor,
                      fontStyle: FontStyle.italic,
                    ),
                    children: [
                      TextSpan(text: widget.thinking),
                      if (widget.isStreaming)
                        const TextSpan(text: '▎'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A text widget that can be expanded to show full content.
/// Used in tool call segments for large arguments/results.
class _SegmentTruncatedText extends StatefulWidget {
  final String text;
  final int maxLines;

  const _SegmentTruncatedText({required this.text, required this.maxLines});

  @override
  State<_SegmentTruncatedText> createState() => _SegmentTruncatedTextState();
}

class _SegmentTruncatedTextState extends State<_SegmentTruncatedText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          widget.text,
          maxLines: _expanded ? null : widget.maxLines,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 2),
              Text(
                _expanded
                    ? '收起'
                    : '展开全部 (${widget.text.length} 字符)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Devin-style compact tool call card.
/// Single line when collapsed: [icon] tool_name  summary  [status]
/// Click to expand args + result.
class _DevinToolCallCard extends StatefulWidget {
  final String name;
  final String summary;
  final String status;
  final Color color;
  final IconData statusIcon;
  final bool isRunning;
  final bool isError;
  final Map<String, dynamic> args;
  final String? result;

  const _DevinToolCallCard({
    required this.name,
    required this.summary,
    required this.status,
    required this.color,
    required this.statusIcon,
    required this.isRunning,
    required this.isError,
    required this.args,
    this.result,
  });

  @override
  State<_DevinToolCallCard> createState() => _DevinToolCallCardState();
}

class _DevinToolCallCardState extends State<_DevinToolCallCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: widget.color.withAlpha(isDark ? 25 : 15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: widget.color.withAlpha(50), width: 0.5),
      ),
      child: Column(
        children: [
          // Header row — always visible, compact
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  // Status icon (with spin if running)
                  if (widget.isRunning)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(widget.color),
                      ),
                    )
                  else
                    Icon(widget.statusIcon, size: 14, color: widget.color),
                  const SizedBox(width: 8),
                  // Tool name — monospace, bold
                  Text(
                    widget.name,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withAlpha(200),
                    ),
                  ),
                  // Summary
                  if (widget.summary.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.summary,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(140),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Expand/collapse chevron
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (_expanded) ...[
            Divider(
              height: 1,
              color: widget.color.withAlpha(30),
            ),
            if (widget.args.isNotEmpty)
              _buildArgsView(theme),
            if (widget.result != null)
              _buildResultView(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildArgsView(ThemeData theme) {
    final hasLargeContent = widget.args.values.any(
      (v) => v is String && v.length > 200,
    );

    if (!hasLargeContent) {
      try {
        final formatted = const JsonEncoder.withIndent('  ').convert(widget.args);
        return _buildSection(theme, '参数', formatted);
      } catch (_) {
        return const SizedBox.shrink();
      }
    }

    // Large args — show per field
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('参数',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(120),
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 4),
          for (final entry in widget.args.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.key}:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: entry.value is String && (entry.value as String).length > 200
                        ? _SegmentTruncatedText(text: entry.value.toString(), maxLines: 5)
                        : SelectableText(
                            entry.value?.toString() ?? 'null',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace', fontSize: 11),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultView(ThemeData theme) {
    return _buildSection(
      theme,
      widget.isError ? '错误' : '结果',
      widget.result!,
      isError: widget.isError,
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content,
      {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(120),
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isError
                  ? theme.colorScheme.errorContainer.withAlpha(40)
                  : theme.colorScheme.surfaceContainerHighest.withAlpha(60),
              borderRadius: BorderRadius.circular(4),
            ),
            child: content.length > 500
                ? _SegmentTruncatedText(text: content, maxLines: 10)
                : SelectableText(content,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace', fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

/// Collapsible content widget for long messages.
/// - Short content (< 500 chars): always fully visible
/// - Long content: collapsed by default, shows first ~8 lines + "展开" button
/// - Expanded: shows full content + "收起" button
class _CollapsibleContent extends StatefulWidget {
  final String text;
  final Color textColor;
  final bool isAiMessage;

  const _CollapsibleContent({
    required this.text,
    required this.textColor,
    required this.isAiMessage,
  });

  @override
  State<_CollapsibleContent> createState() => _CollapsibleContentState();
}

class _CollapsibleContentState extends State<_CollapsibleContent> {
  bool _expanded = false;

  static const _collapseThreshold = 500; // chars
  static const _collapsedMaxLines = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLong = widget.text.length > _collapseThreshold;

    if (!isLong) {
      // Short content — no collapse needed
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _renderFull(theme),
      );
    }

    // Long content — collapsible.
    // Key optimization: when collapsed, render a lightweight Text (not MarkdownBody).
    // MarkdownBody is expensive for long text and doesn't support maxLines.
    // Only render MarkdownBody when explicitly expanded.
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Content — only one branch is built (no AnimatedCrossFade)
          if (_expanded)
            _renderFull(theme)
          else
            _renderCollapsed(theme),
          // Toggle button
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  _expanded
                      ? '收起'
                      : '展开全部 (${widget.text.length} 字符)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Collapsed view — lightweight Text with maxLines, no Markdown parsing.
  Widget _renderCollapsed(ThemeData theme) {
    return Text(
      widget.text,
      maxLines: _collapsedMaxLines,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(color: widget.textColor),
    );
  }

  /// Full view — Markdown for AI messages, SelectableText for plain text.
  Widget _renderFull(ThemeData theme) {
    if (widget.isAiMessage) {
      // Check for mermaid blocks
      final mermaidRegex = RegExp(r'```mermaid\n([\s\S]*?)```');
      final hasMermaid = mermaidRegex.hasMatch(widget.text);

      if (!hasMermaid) {
        // No mermaid — render as single MarkdownBody
        return MarkdownBody(
          data: widget.text,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: theme.textTheme.bodyMedium?.copyWith(color: widget.textColor),
            h1: theme.textTheme.headlineSmall?.copyWith(
                color: widget.textColor, fontWeight: FontWeight.bold),
            h2: theme.textTheme.titleLarge?.copyWith(
                color: widget.textColor, fontWeight: FontWeight.bold),
            h3: theme.textTheme.titleMedium?.copyWith(
                color: widget.textColor, fontWeight: FontWeight.bold),
            code: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: widget.textColor,
                backgroundColor: theme.colorScheme.surfaceContainerHighest
                    .withAlpha(60)),
            codeblockDecoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              borderRadius: BorderRadius.circular(6),
            ),
            a: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      }

      // Has mermaid blocks — split and render mixed widgets
      final segments = <_MdSegment>[];
      int lastEnd = 0;
      for (final match in mermaidRegex.allMatches(widget.text)) {
        if (match.start > lastEnd) {
          segments.add(_MdSegment(_SegmentType.text,
              widget.text.substring(lastEnd, match.start).trim()));
        }
        segments.add(_MdSegment(_SegmentType.mermaid, match.group(1)!.trim()));
        lastEnd = match.end;
      }
      if (lastEnd < widget.text.length) {
        segments.add(_MdSegment(
            _SegmentType.text, widget.text.substring(lastEnd).trim()));
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final seg in segments) ...[
            if (seg.type == _SegmentType.text && seg.content.isNotEmpty)
              MarkdownBody(
                data: seg.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: theme.textTheme.bodyMedium
                      ?.copyWith(color: widget.textColor),
                  h1: theme.textTheme.headlineSmall?.copyWith(
                      color: widget.textColor,
                      fontWeight: FontWeight.bold),
                  h2: theme.textTheme.titleLarge?.copyWith(
                      color: widget.textColor,
                      fontWeight: FontWeight.bold),
                  h3: theme.textTheme.titleMedium?.copyWith(
                      color: widget.textColor,
                      fontWeight: FontWeight.bold),
                  code: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: widget.textColor,
                      backgroundColor: theme
                          .colorScheme.surfaceContainerHighest
                          .withAlpha(60)),
                  codeblockDecoration: BoxDecoration(
                    color:
                        theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  a: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              )
            else if (seg.type == _SegmentType.mermaid)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: LingMermaidPreview(mermaidCode: seg.content),
              ),
          ],
        ],
      );
    }
    return SelectableText(
      widget.text,
      style: theme.textTheme.bodyMedium?.copyWith(color: widget.textColor),
    );
  }
}

/// Segment type for markdown text splitting.
enum _SegmentType { text, mermaid }

/// A segment of markdown content — either plain text or mermaid code.
class _MdSegment {
  final _SegmentType type;
  final String content;

  const _MdSegment(this.type, this.content);
}

/// A simple grid pattern painter for the map placeholder background.
class _MapGridPainter extends CustomPainter {
  final Color color;

  const _MapGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) =>
      color != oldDelegate.color;
}
