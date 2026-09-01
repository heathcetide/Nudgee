import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';
import 'package:nudgee/core/widgets/feedback/ling_file_viewer.dart';
import 'package:nudgee/core/widgets/feedback/ling_image_viewer.dart';
import 'package:nudgee/core/widgets/feedback/ling_location_viewer.dart';
import 'package:nudgee/core/widgets/feedback/ling_web_view_page.dart';
import 'package:nudgee/core/widgets/im/ling_link_preview.dart';
import 'package:nudgee/core/widgets/im/ling_link_preview_fetcher.dart';
import 'package:nudgee/core/widgets/im/ling_message_reaction.dart';

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
                        // Thinking process (for AI reasoning models)
                        if (message.metadata?['thinking'] != null)
                          _buildThinkingBlock(context, textColor),
                        // Content
                        customContent ?? _buildContent(context, textColor),
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

  /// Build a collapsible thinking/reasoning block for AI messages.
  Widget _buildThinkingBlock(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    final thinking = message.metadata!['thinking'] as String;
    if (thinking.isEmpty) return const SizedBox.shrink();

    return _ThinkingBlock(
      thinking: thinking,
      textColor: textColor,
      theme: theme,
    );
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    switch (message.type) {
      case LingMessageType.text:
        return _buildText(context, textColor);
      case LingMessageType.image:
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

  Widget _buildText(BuildContext context, Color textColor) {
    final text = message.text ?? '';
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
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LingLocationViewer(
              latitude: lat,
              longitude: lng,
              locationName: name,
            ),
          ),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Container(
                width: double.infinity,
                height: 100,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.map, size: 40, color: textColor.withOpacity(0.3)),
                    const Icon(Icons.location_on, size: 28, color: Colors.red),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

  const _ThinkingBlock({
    required this.thinking,
    required this.textColor,
    required this.theme,
  });

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isOutgoing = widget.textColor == widget.theme.colorScheme.onPrimary;
    final mutedColor = isOutgoing
        ? widget.theme.colorScheme.onPrimary.withAlpha(140)
        : widget.theme.colorScheme.onSurfaceVariant;
    final bgColor = isOutgoing
        ? widget.theme.colorScheme.primary.withAlpha(40)
        : widget.theme.colorScheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (tap to toggle)
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.psychology, size: 14, color: mutedColor),
                    const SizedBox(width: 6),
                    Text(
                      _expanded ? '思考过程' : '查看思考过程',
                      style: TextStyle(fontSize: 12, color: mutedColor),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: mutedColor,
                    ),
                  ],
                ),
              ),
            ),
            // Thinking content (collapsible)
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  widget.thinking,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: mutedColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
