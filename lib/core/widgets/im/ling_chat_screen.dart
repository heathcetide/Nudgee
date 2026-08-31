import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:nudgee/core/controllers/im/ling_chat_controller.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';
import 'package:nudgee/core/widgets/im/ling_chat_input.dart';
import 'package:nudgee/core/widgets/im/ling_contact_profile.dart';
import 'package:nudgee/core/widgets/im/ling_group_announcement.dart';
import 'package:nudgee/core/widgets/im/ling_group_profile.dart';
import 'package:nudgee/core/widgets/im/ling_message_forward.dart';
import 'package:nudgee/core/widgets/im/ling_message_list.dart';
import 'package:nudgee/core/widgets/im/ling_message_multi_select.dart';
import 'package:nudgee/core/widgets/im/ling_message_search.dart';
import 'package:nudgee/core/widgets/im/ling_message_tooltip.dart';
import 'package:nudgee/core/widgets/im/ling_typing_indicator.dart';

/// A complete chat screen combining message list + input bar.
///
/// Features:
/// - Message list with auto-scroll, avatars on both sides
/// - Input bar with emoji/attachment/send + reply preview
/// - Long-press message for action menu (reply / copy / forward / multi-select / recall / delete)
/// - Multi-select mode with bottom action bar
/// - AppBar with title, subtitle, and overflow menu (profile / search / mute / clear)
class LingChatScreen extends StatefulWidget {
  final LingConversation conversation;
  final LingChatController controller;
  final Map<String, LingChatUser> userMap;
  final String currentUserId;
  final LingMessageSendCallback? onSend;
  final LingAttachmentCallback? onAttachment;
  final VoidCallback? onVoicePressed;
  final VoidCallback? onTypingBegin;
  final VoidCallback? onTypingStop;
  final VoidCallback? onLoadMore;
  final ValueChanged<String>? onReactionTapped;
  final List<Widget>? appBarActions;
  final Widget? appBarLeading;

  /// Conversations available for forwarding.
  final List<LingConversation>? forwardConversations;

  /// Called when a message is forwarded to target conversation ids.
  /// The parent should add the message to the target conversation's controller.
  final void Function(LingMessage message, List<String> targetConvIds)? onForward;

  /// Called when the draft text changes (for saving draft to conversation list).
  final ValueChanged<String?>? onDraftChanged;

  const LingChatScreen({
    super.key,
    required this.conversation,
    required this.controller,
    required this.userMap,
    required this.currentUserId,
    this.onSend,
    this.onAttachment,
    this.onVoicePressed,
    this.onTypingBegin,
    this.onTypingStop,
    this.onLoadMore,
    this.onReactionTapped,
    this.appBarActions,
    this.appBarLeading,
    this.forwardConversations,
    this.onForward,
    this.onDraftChanged,
  });

  @override
  State<LingChatScreen> createState() => _LingChatScreenState();
}

class _LingChatScreenState extends State<LingChatScreen> {
  // Multi-select
  bool _multiSelectMode = false;
  final Set<String> _selectedIds = {};

  // Reply
  LingMessage? _replyingTo;

  String? get _selfAvatarUrl => widget.userMap[widget.currentUserId]?.avatarUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final typingUsers = widget.conversation.members
            .where((u) => u.id != widget.currentUserId)
            .where((u) => widget.controller.isTyping)
            .toList();
        final subtitle = typingUsers.isNotEmpty
            ? '正在输入...'
            : widget.conversation.isGroup
                ? '${widget.conversation.members.length} 人'
                : _getStatusText(widget.conversation.members);

        // Build a typing indicator that shows the other party's avatar + loading bubble.
        final otherUser = widget.conversation.members
            .where((u) => u.id != widget.currentUserId)
            .firstOrNull;

        return Scaffold(
          appBar: _buildAppBar(context, theme, subtitle),
          body: Column(
            children: [
              // Message list
              Expanded(
                child: LingMessageList(
                  messages: widget.controller.messages,
                  currentUserId: widget.currentUserId,
                  userMap: widget.userMap,
                  isGroup: widget.conversation.isGroup,
                  isTyping: widget.controller.isTyping,
                  hasMore: widget.controller.hasMore,
                  isLoadingMore: widget.controller.isLoadingMore,
                  onLoadMore: widget.onLoadMore,
                  selfAvatarUrl: _selfAvatarUrl,
                  selectedMessageIds: _selectedIds,
                  multiSelectMode: _multiSelectMode,
                  typingIndicator: otherUser != null
                      ? _AvatarTypingIndicator(
                          avatarUrl: otherUser.avatarUrl,
                          userName: otherUser.name,
                        )
                      : null,
                  onMessageLongPress: (msg) {
                    if (_multiSelectMode) {
                      _toggleSelect(msg.id);
                    } else {
                      _showMessageTooltip(context, msg);
                    }
                  },
                  onMessageTap: (msg) {
                    if (_multiSelectMode) {
                      _toggleSelect(msg.id);
                    }
                  },
                  onAvatarTap: (user) => _openUserProfile(context, user),
                  onContactCardTap: (user) => _openUserProfile(context, user),
                  onReactionTapped: (emoji) {
                    // Reactions handled by controller externally
                  },
                ),
              ),
              // Multi-select bottom bar OR input bar
              if (_multiSelectMode)
                LingMessageMultiSelect(
                  selectedCount: _selectedIds.length,
                  onClose: _exitMultiSelect,
                  actions: [
                    LingMultiSelectAction(
                      label: '转发',
                      icon: Icons.shortcut,
                      onTap: () => _forwardSelected(context),
                    ),
                    const LingMultiSelectAction(label: '收藏', icon: Icons.star_outline),
                    LingMultiSelectAction(
                      label: '删除',
                      icon: Icons.delete_outline,
                      onTap: () => _deleteSelected(),
                    ),
                  ],
                )
              else
                LingChatInput(
                  onSend: (text) {
                    final replyQuote = _replyingTo != null
                        ? LingReplyQuote(
                            messageId: _replyingTo!.id,
                            authorId: _replyingTo!.authorId,
                            authorName: widget.userMap[_replyingTo!.authorId]?.name ??
                                _replyingTo!.authorId,
                            messageType: _replyingTo!.type,
                            preview: _replyingTo!.text ?? '[消息]',
                          )
                        : null;

                    widget.onSend?.call(text);
                    widget.controller.addMessage(LingMessage(
                      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                      conversationId: widget.conversation.id,
                      authorId: widget.currentUserId,
                      type: LingMessageType.text,
                      text: text,
                      createdAt: DateTime.now(),
                      status: LingMessageStatus.sending,
                      replyTo: replyQuote,
                    ));
                    setState(() => _replyingTo = null);
                    widget.onDraftChanged?.call(null);
                  },
                  onTextChanged: (text) {
                    widget.onDraftChanged?.call(text.isEmpty ? null : text);
                  },
                  onAttachment: widget.onAttachment ?? _handleAttachment,
                  onVoicePressed: widget.onVoicePressed,
                  onVoiceComplete: (duration) => _sendVoice(duration),
                  mentionMembers: widget.conversation.isGroup
                      ? widget.conversation.members
                          .where((u) => u.id != widget.currentUserId)
                          .toList()
                      : const [],
                  onTypingBegin: widget.onTypingBegin,
                  onTypingStop: widget.onTypingStop,
                  replyPreview: _replyingTo != null
                      ? '回复 ${widget.userMap[_replyingTo!.authorId]?.name ?? _replyingTo!.authorId}: ${_replyingTo!.text ?? '[消息]'}'
                      : null,
                  onReplyCancel: () => setState(() => _replyingTo = null),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
      BuildContext context, ThemeData theme, String subtitle) {
    if (_multiSelectMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitMultiSelect,
        ),
        title: Text('已选 ${_selectedIds.length} 项'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: _selectAll,
          ),
        ],
      );
    }

    return AppBar(
      leading: widget.appBarLeading,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.conversation.name,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: widget.appBarActions ??
          [
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _showChatMenu(context),
            ),
          ],
    );
  }

  // ── 右上角三个点 → 跳转新页面 ────────────────────────────────────────

  void _showChatMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('查看资料'),
              onTap: () {
                Navigator.pop(ctx);
                _openProfile(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('查找聊天记录'),
              onTap: () {
                Navigator.pop(ctx);
                _openSearch(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.volume_off_outlined),
              title: Text(widget.conversation.isMuted ? '取消免打扰' : '消息免打扰'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.wallpaper_outlined),
              title: const Text('设置聊天背景'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: Icon(Icons.clear_all, color: theme(context).colorScheme.error),
              title: Text('清空聊天记录',
                  style: TextStyle(color: theme(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                widget.controller.clear();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    if (widget.conversation.isGroup) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _GroupSettingsPage(
            conversation: widget.conversation,
            currentUserId: widget.currentUserId,
          ),
        ),
      );
    } else {
      final other = widget.conversation.others(widget.currentUserId).firstOrNull;
      if (other == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(other.name)),
            body: LingContactProfile(user: other, isFriend: true),
          ),
        ),
      );
    }
  }

  /// 点击消息头像查看用户资料
  void _openUserProfile(BuildContext context, LingChatUser user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(user.name)),
          body: LingContactProfile(user: user, isFriend: true),
        ),
      ),
    );
  }

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LingMessageSearch(
          results: [],
          onSearch: (query) {
            // Mock: filter current messages
            final matched = widget.controller.messages
                .where((m) => (m.text ?? '').contains(query))
                .map((m) => LingMessageSearchResult(
                      message: m,
                      conversationName: widget.conversation.name,
                      authorName: widget.userMap[m.authorId]?.name ?? m.authorId,
                    ))
                .toList();
            // LingMessageSearch is stateless for results, so we just print
            // In a real app this would be a stateful search page
          },
          onResultTap: (result) {},
        ),
      ),
    );
  }

  // ── 长按消息操作菜单 ─────────────────────────────────────────────────

  void _showMessageTooltip(BuildContext context, LingMessage msg) {
    final isOutgoing = msg.isFrom(widget.currentUserId);
    LingMessageTooltip.show(
      context,
      canRecall: isOutgoing,
      canDelete: isOutgoing,
      actions: [
        LingMessageTooltipAction.reply(onTap: () => _startReply(msg)),
        LingMessageTooltipAction.copy(onTap: () {
          final text = msg.text ?? '';
          if (text.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
            );
          }
        }),
        LingMessageTooltipAction.forward(onTap: () => _forwardMessage(context, msg)),
        LingMessageTooltipAction.multiSelect(onTap: _enterMultiSelect),
        if (isOutgoing) LingMessageTooltipAction.recall(onTap: () => _recallMessage(msg)),
        if (isOutgoing)
          LingMessageTooltipAction.delete(onTap: () => _deleteMessage(msg)),
        LingMessageTooltipAction.more(),
      ],
    );
  }

  // ── 回复 ─────────────────────────────────────────────────────────────

  void _startReply(LingMessage msg) {
    setState(() => _replyingTo = msg);
  }

  // ── 语音发送 ─────────────────────────────────────────────────────────

  void _sendVoice(Duration duration) {
    widget.controller.addMessage(LingMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversation.id,
      authorId: widget.currentUserId,
      type: LingMessageType.audio,
      duration: duration,
      waveform: List.generate(20, (i) => 0.3 + (i % 3) * 0.2),
      createdAt: DateTime.now(),
      status: LingMessageStatus.sent,
    ));
  }

  // ── 附件发送 ─────────────────────────────────────────────────────────

  void _handleAttachment(LingAttachmentType type) {
    switch (type) {
      case LingAttachmentType.image:
        _sendImage();
      case LingAttachmentType.camera:
        _sendImage(camera: true);
      case LingAttachmentType.file:
        _sendFile();
      case LingAttachmentType.location:
        _sendLocation();
      case LingAttachmentType.contact:
        _sendContact();
    }
  }

  Future<void> _requestPermission(Permission permission, String name) async {
    final status = await permission.request();
    if (status != PermissionStatus.granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name权限被拒绝，请在设置中开启')),
      );
    }
  }

  Future<void> _sendImage({bool camera = false}) async {
    // 请求权限
    if (camera) {
      await _requestPermission(Permission.camera, '相机');
    } else {
      if (Platform.isAndroid) {
        await _requestPermission(Permission.photos, '相册');
      }
    }

    final picker = ImagePicker();
    final XFile? file = camera
        ? await picker.pickImage(source: ImageSource.camera)
        : await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    widget.controller.addMessage(LingMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversation.id,
      authorId: widget.currentUserId,
      type: LingMessageType.image,
      mediaUrl: file.path,
      createdAt: DateTime.now(),
      status: LingMessageStatus.sent,
    ));
  }

  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    widget.controller.addMessage(LingMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversation.id,
      authorId: widget.currentUserId,
      type: LingMessageType.file,
      mediaName: file.name,
      mediaSize: file.size,
      createdAt: DateTime.now(),
      status: LingMessageStatus.sent,
    ));
  }

  Future<void> _sendLocation() async {
    // 请求定位权限
    final status = await Permission.location.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('定位权限被拒绝，请在设置中开启')),
        );
      }
      return;
    }

    if (!mounted) return;
    // 显示加载中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('正在获取位置...'),
          ],
        ),
      ),
    );

    try {
      // 检查定位服务是否开启
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先开启定位服务')),
          );
        }
        return;
      }

      // 获取当前位置
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // 使用高德地图 Web API 逆地理编码（免费）
      // 高德 Web 服务 Key（演示用，生产环境应放在服务端）
      const amapKey = 'your_amap_web_key';
      String locationName = '位置 (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';

      try {
        final dio = Dio();
        // 高德逆地理编码：lng,lat
        final res = await dio.get(
          'https://restapi.amap.com/v3/geocode/regeo',
          queryParameters: {
            'key': amapKey,
            'location': '${position.longitude},${position.latitude}',
            'extensions': 'base',
          },
        ).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200 && res.data['status'] == '1') {
          final regeo = res.data['regeocode'];
          final formatted = regeo['formatted_address'] as String?;
          if (formatted != null && formatted.isNotEmpty) {
            locationName = formatted;
          }
        }
      } catch (_) {
        // 逆地理编码失败，使用坐标作为位置名
      }

      if (mounted) Navigator.pop(context); // 关闭加载框
      if (!mounted) return;

      // 弹出确认对话框
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('发送位置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              Text(locationName, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                '纬度: ${position.latitude.toStringAsFixed(6)}\n经度: ${position.longitude.toStringAsFixed(6)}',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('发送'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      widget.controller.addMessage(LingMessage(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: widget.conversation.id,
        authorId: widget.currentUserId,
        type: LingMessageType.custom,
        metadata: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'locationName': locationName,
        },
        createdAt: DateTime.now(),
        status: LingMessageStatus.sent,
      ));
    } catch (e) {
      if (mounted) Navigator.pop(context); // 关闭加载框
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取位置失败: $e')),
        );
      }
    }
  }

  void _sendContact() {
    // 弹出联系人选择
    final contacts = widget.conversation.members
        .where((u) => u.id != widget.currentUserId)
        .toList();
    if (contacts.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('选择联系人', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...contacts.map((user) => ListTile(
                  leading: LingAvatar(
                    imageUrl: user.avatarUrl,
                    name: user.name,
                    size: LingAvatarSize.sm,
                  ),
                  title: Text(user.name),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.controller.addMessage(LingMessage(
                      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                      conversationId: widget.conversation.id,
                      authorId: widget.currentUserId,
                      type: LingMessageType.custom,
                      metadata: {
                        'contactId': user.id,
                        'contactName': user.name,
                        'contactAvatar': user.avatarUrl,
                      },
                      createdAt: DateTime.now(),
                      status: LingMessageStatus.sent,
                    ));
                  },
                )),
          ],
        ),
      ),
    );
  }

  // ── 转发 ─────────────────────────────────────────────────────────────

  void _forwardMessage(BuildContext context, LingMessage msg) {
    final conversations = widget.forwardConversations ??
        [];
    // 排除当前会话
    final targets = conversations
        .where((c) => c.id != widget.conversation.id)
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LingMessageForward(
          conversations: targets,
          currentUserId: widget.currentUserId,
          multiSelect: true,
          onForward: (ids) {
            Navigator.of(context).pop();
            widget.onForward?.call(msg, ids);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已转发到 ${ids.length} 个会话'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
      ),
    );
  }

  void _forwardSelected(BuildContext context) {
    final selectedMsgs = widget.controller.messages
        .where((m) => _selectedIds.contains(m.id))
        .toList();
    if (selectedMsgs.isEmpty) return;
    _forwardMessage(context, selectedMsgs.first);
    _exitMultiSelect();
  }

  // ── 多选 ─────────────────────────────────────────────────────────────

  void _enterMultiSelect() {
    setState(() {
      _multiSelectMode = true;
      _selectedIds.clear();
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String msgId) {
    setState(() {
      if (_selectedIds.contains(msgId)) {
        _selectedIds.remove(msgId);
      } else {
        _selectedIds.add(msgId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == widget.controller.messages.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(widget.controller.messages.map((m) => m.id));
      }
    });
  }

  // ── 撤回 / 删除 ──────────────────────────────────────────────────────

  void _recallMessage(LingMessage msg) {
    widget.controller.updateMessage(msg.id, (m) => LingMessage(
      id: m.id,
      conversationId: m.conversationId,
      authorId: m.authorId,
      type: LingMessageType.system,
      text: '我撤回了一条消息',
      createdAt: m.createdAt,
    ));
  }

  void _deleteMessage(LingMessage msg) {
    widget.controller.removeMessage(msg.id);
  }

  void _deleteSelected() {
    for (final id in _selectedIds.toList()) {
      widget.controller.removeMessage(id);
    }
    _exitMultiSelect();
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  ThemeData theme(BuildContext context) => Theme.of(context);

  String _getStatusText(List<LingChatUser> members) {
    final others = members.where((u) => u.id != widget.currentUserId).toList();
    if (others.isEmpty) return '';
    final user = others.first;
    switch (user.status) {
      case LingUserStatus.online:
        return '在线';
      case LingUserStatus.offline:
        return '离线';
      case LingUserStatus.away:
        return '离开';
      case LingUserStatus.busy:
        return '忙碌';
      case LingUserStatus.invisible:
        return '隐身';
    }
  }
}

/// 群聊设置页面 — 包含群资料、群公告、群成员、聊天记录等
class _GroupSettingsPage extends StatelessWidget {
  final LingConversation conversation;
  final String currentUserId;

  const _GroupSettingsPage({
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(conversation.name)),
      body: ListView(
        children: [
          // 群资料头部
          LingGroupProfile(
            conversation: conversation,
            currentUserId: currentUserId,
            shrinkWrap: true,
          ),
          const SizedBox(height: 8),

          // 群公告
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LingGroupAnnouncement(
              title: '群公告',
              content: conversation.metadata?['announcement'] as String? ??
                  '暂无群公告',
              publisherName: '群主',
              publishedAt: DateTime.now().subtract(const Duration(days: 1)),
              publisherAvatarUrl: null,
              canEdit: true,
              onEdit: () {},
            ),
          ),
          const SizedBox(height: 8),

          // 设置项
          _SettingsSection(
            title: '聊天',
            items: [
              _SettingsItem(
                icon: Icons.search,
                label: '查找聊天记录',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.chat_bubble_outline,
                label: '清空聊天记录',
                onTap: () {},
                color: theme.colorScheme.error,
              ),
            ],
          ),
          const SizedBox(height: 8),

          _SettingsSection(
            title: '群管理',
            items: [
              _SettingsItem(
                icon: Icons.people_outline,
                label: '群成员 (${conversation.members.length})',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.campaign_outlined,
                label: '群公告',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.volume_off_outlined,
                label: conversation.isMuted ? '取消免打扰' : '消息免打扰',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.wallpaper_outlined,
                label: '设置聊天背景',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 退出群聊
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.logout, color: theme.colorScheme.error),
              label: Text(
                '退出群聊',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: theme.colorScheme.error.withOpacity(0.3)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1)
                  Divider(height: 0.5, indent: 56, color: theme.dividerColor),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: c),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(color: c),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Typing indicator with the other party's avatar + a loading bubble.
///
/// Shows the avatar on the left and a chat bubble with three bouncing dots
/// on the right, matching the incoming message bubble layout exactly.
class _AvatarTypingIndicator extends StatelessWidget {
  final String? avatarUrl;
  final String? userName;

  const _AvatarTypingIndicator({
    this.avatarUrl,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar — same size and spacing as LingMessageBubble
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: LingAvatar(
              imageUrl: avatarUrl,
              name: userName,
              size: LingAvatarSize.sm,
            ),
          ),
          // Loading bubble with bouncing dots
          const LingTypingIndicator(),
        ],
      ),
    );
  }
}
