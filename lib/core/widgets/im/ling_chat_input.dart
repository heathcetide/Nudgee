import 'package:flutter/material.dart';

import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/im/ling_at_mention_panel.dart';
import 'package:nudgee/core/widgets/im/ling_emoji_picker.dart';
import 'package:nudgee/core/widgets/im/ling_voice_recorder.dart';

/// Callback when the send button is pressed.
typedef LingMessageSendCallback = void Function(String text);

/// Callback when an attachment is selected.
typedef LingAttachmentCallback = void Function(LingAttachmentType type);

/// Callback when voice recording completes.
typedef LingVoiceCompleteCallback = void Function(Duration duration);

/// Attachment type enum.
enum LingAttachmentType {
  image,
  camera,
  file,
  location,
  contact,
}

/// A chat input bar with text field, send button, emoji toggle, and attachments.
///
/// Features:
/// - Multi-line text input with auto-grow
/// - Send button (appears when text is non-empty)
/// - Emoji picker toggle
/// - Attachment menu (image, camera, file, location, contact)
/// - Voice recording button (when text is empty)
/// - @ mention panel (group chat)
/// - Reply preview bar
/// - Edit mode
class LingChatInput extends StatefulWidget {
  final LingMessageSendCallback? onSend;
  final LingAttachmentCallback? onAttachment;
  final VoidCallback? onVoicePressed;
  final LingVoiceCompleteCallback? onVoiceComplete;
  final ValueChanged<String>? onTextChanged;
  final VoidCallback? onTypingBegin;
  final VoidCallback? onTypingStop;
  final String? replyPreview;
  final VoidCallback? onReplyCancel;
  final bool enabled;
  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Group members for @ mention. When empty, @ panel is disabled.
  final List<LingChatUser> mentionMembers;

  /// Called when a member is selected from the @ panel.
  final ValueChanged<LingChatUser>? onMentionSelected;

  const LingChatInput({
    super.key,
    this.onSend,
    this.onAttachment,
    this.onVoicePressed,
    this.onVoiceComplete,
    this.onTextChanged,
    this.onTypingBegin,
    this.onTypingStop,
    this.replyPreview,
    this.onReplyCancel,
    this.enabled = true,
    this.hintText = '输入消息...',
    this.controller,
    this.focusNode,
    this.mentionMembers = const [],
    this.onMentionSelected,
  });

  @override
  State<LingChatInput> createState() => _LingChatInputState();
}

class _LingChatInputState extends State<LingChatInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _showEmoji = false;
  bool _showAttach = false;
  bool _hasText = false;
  bool _isTyping = false;
  bool _showMention = false;
  String _mentionQuery = '';
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  bool _voiceMode = false;
  int _lastTypingNotify = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    widget.onTextChanged?.call(_controller.text);

    // @ mention 检测
    _detectMention();

    // Typing indicator
    final now = DateTime.now().millisecondsSinceEpoch;
    if (hasText && !_isTyping) {
      _isTyping = true;
      widget.onTypingBegin?.call();
    }
    _lastTypingNotify = now;
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_isTyping && DateTime.now().millisecondsSinceEpoch - _lastTypingNotify >= 1400) {
        _isTyping = false;
        widget.onTypingStop?.call();
      }
    });
  }

  /// 检测 @ 符号，触发 mention panel
  void _detectMention() {
    if (widget.mentionMembers.isEmpty) return;
    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.start <= 0) {
      setState(() => _showMention = false);
      return;
    }
    // 从光标往前找最近的 @
    final beforeCursor = text.substring(0, selection.start);
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex < 0) {
      setState(() => _showMention = false);
      return;
    }
    // @ 必须在开头或前面是空格/换行
    if (atIndex > 0) {
      final charBefore = beforeCursor[atIndex - 1];
      if (charBefore != ' ' && charBefore != '\n') {
        setState(() => _showMention = false);
        return;
      }
    }
    final query = beforeCursor.substring(atIndex + 1);
    // 如果 query 包含空格则关闭
    if (query.contains(' ') || query.contains('\n')) {
      setState(() => _showMention = false);
      return;
    }
    setState(() {
      _showMention = true;
      _mentionQuery = query;
    });
  }

  void _onMentionSelected(LingChatUser user) {
    final text = _controller.text;
    final selection = _controller.selection;
    final beforeCursor = text.substring(0, selection.start);
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex < 0) return;
    final afterCursor = text.substring(selection.end);
    final mentionText = '@${user.name} ';
    _controller.text =
        text.substring(0, atIndex) + mentionText + afterCursor;
    _controller.selection = TextSelection.collapsed(
      offset: atIndex + mentionText.length,
    );
    setState(() => _showMention = false);
    widget.onMentionSelected?.call(user);
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text);
    _controller.clear();
    _isTyping = false;
    widget.onTypingStop?.call();
    setState(() => _showMention = false);
  }

  void _toggleEmoji() {
    setState(() {
      _showEmoji = !_showEmoji;
      _showAttach = false;
      if (_showEmoji) {
        _focusNode.unfocus();
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  void _toggleAttach() {
    setState(() {
      _showAttach = !_showAttach;
      _showEmoji = false;
      if (_showAttach) {
        _focusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply preview
        if (widget.replyPreview != null) _buildReplyPreview(context),
        // @ mention panel
        if (_showMention)
          LingAtMentionPanel(
            members: widget.mentionMembers,
            query: _mentionQuery,
            onMemberSelected: _onMentionSelected,
          ),
        // Input row
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: theme.colorScheme.surface,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Emoji toggle
                _IconButton(
                  icon: _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                  onTap: _toggleEmoji,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                // Text field or voice recorder
                Expanded(
                  child: _voiceMode && !_hasText
                      ? LingVoiceRecorder(
                          state: _isRecording
                              ? LingVoiceRecorderState.recording
                              : LingVoiceRecorderState.idle,
                          duration: _recordDuration,
                          onStart: () {
                            setState(() {
                              _isRecording = true;
                              _recordDuration = Duration.zero;
                            });
                            widget.onVoicePressed?.call();
                          },
                          onComplete: (duration) {
                            setState(() {
                              _isRecording = false;
                              _recordDuration = Duration.zero;
                            });
                            widget.onVoiceComplete?.call(duration);
                          },
                          onCancel: () {
                            setState(() {
                              _isRecording = false;
                              _recordDuration = Duration.zero;
                            });
                          },
                        )
                      : Container(
                          constraints: const BoxConstraints(maxHeight: 120),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            enabled: widget.enabled,
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            style: theme.textTheme.bodyMedium,
                            decoration: InputDecoration(
                              hintText: widget.hintText,
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              isDense: true,
                            ),
                          ),
                        ),
                ),
                // Voice/keyboard toggle + attach or send
                if (!_hasText) ...[
                  _IconButton(
                    icon: _voiceMode ? Icons.keyboard : Icons.mic_none,
                    onTap: () => setState(() => _voiceMode = !_voiceMode),
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  _IconButton(
                    icon: Icons.attach_file,
                    onTap: _toggleAttach,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ] else
                  _SendButton(onTap: _send),
              ],
            ),
          ),
        ),
        // Emoji picker
        if (_showEmoji)
          LingEmojiPicker(
            onEmojiSelected: (emoji) {
              final text = _controller.text;
              final selection = _controller.selection;
              _controller.text = text.substring(0, selection.start) + emoji + text.substring(selection.end);
              _controller.selection = TextSelection.collapsed(offset: selection.start + emoji.length);
            },
            onBackspacePressed: () {
              final text = _controller.text;
              if (text.isNotEmpty) {
                _controller.text = text.substring(0, text.length - 1);
              }
            },
          ),
        // Attachment menu
        if (_showAttach) _buildAttachmentMenu(context),
      ],
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.replyPreview!,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: widget.onReplyCancel,
            child: Icon(Icons.close, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentMenu(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      ('图片', Icons.photo, theme.colorScheme.primary),
      ('相机', Icons.camera_alt, theme.colorScheme.secondary),
      ('文件', Icons.insert_drive_file, theme.colorScheme.tertiary),
      ('位置', Icons.location_on, theme.colorScheme.error),
      ('联系人', Icons.person, theme.colorScheme.onSurfaceVariant),
    ];
    return Container(
      height: 120,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          final (label, icon, color) = item;
          final type = LingAttachmentType.values[items.indexOf(item)];
          return GestureDetector(
            onTap: () {
              setState(() => _showAttach = false);
              widget.onAttachment?.call(type);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 4),
                Text(label, style: theme.textTheme.labelSmall),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _IconButton({required this.icon, this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(left: 4, bottom: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.send, color: theme.colorScheme.onPrimary, size: 18),
      ),
    );
  }
}
