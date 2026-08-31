import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:nudgee/core/controllers/im/im.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/services/ai_service.dart';
import 'package:nudgee/core/widgets/im/ling_chat_screen.dart';
import 'package:nudgee/core/widgets/im/ling_message_search.dart';
import 'package:nudgee/core/widgets/im/im.dart';

/// 聊天页面 — 会话列表 + 聊天详情。
///
/// 使用已封装的 IM 组件（LingConversationList / LingChatScreen 等）
/// 配合 mock 数据展示完整的聊天流程。
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final LingConversationController _convController;
  late final Map<String, LingChatUser> _userMap;
  final Map<String, LingChatController> _chatControllers = {};
  final String _currentUserId = 'me';

  @override
  void initState() {
    super.initState();
    final data = _generateMockData();
    _userMap = data.users;
    _convController = LingConversationController(
      initialConversations: data.conversations,
    );
    for (final conv in data.conversations) {
      _chatControllers[conv.id] = LingChatController(
        conversationId: conv.id,
        currentUserId: _currentUserId,
        initialMessages: data.messages[conv.id] ?? [],
      );
    }
  }

  @override
  void dispose() {
    _chatControllers.values.forEach((c) => c.dispose());
    _convController.dispose();
    super.dispose();
  }

  void _onSend(LingConversation conv, String text) {
    // LingChatScreen already adds the user message to the controller internally,
    // so we only update the conversation list here.
    final msg = LingMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conv.id,
      authorId: _currentUserId,
      type: LingMessageType.text,
      text: text,
      createdAt: DateTime.now(),
      status: LingMessageStatus.sent,
    );
    _convController.upsertConversation(conv.copyWith(lastMessage: msg));

    // Route to AI if this is the LingEcho buddy.
    if (conv.id == _aiBuddyId) {
      _streamAiReply(conv, text);
    }
  }

  /// Stream an AI reply from AiService and add it as a message from LingEcho.
  void _streamAiReply(LingConversation conv, String userText) {
    final ai = sl<AiService>();
    if (!ai.isConfigured) {
      SmartDialog.showNotify(
        msg: context.l10n.aiNotConfigured,
        notifyType: NotifyType.error,
      );
      return;
    }

    final controller = _chatControllers[conv.id];
    if (controller == null) return;

    // Show typing indicator (the other party is "typing").
    controller.isTyping = true;

    final buffer = StringBuffer();
    String? aiMsgId;
    StreamSubscription<String>? sub;

    sub = ai.streamChat(userText).listen(
      (delta) {
        buffer.write(delta);
        // Add the AI message bubble only when the first delta arrives,
        // so we don't show an empty bubble before any content.
        if (aiMsgId == null) {
          aiMsgId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
          controller.addMessage(LingMessage(
            id: aiMsgId!,
            conversationId: conv.id,
            authorId: _aiBuddyId,
            type: LingMessageType.text,
            text: buffer.toString(),
            createdAt: DateTime.now(),
            status: LingMessageStatus.sent,
          ));
          controller.isTyping = false;
        } else {
          controller.updateMessage(aiMsgId!, (m) => m.copyWith(
            text: buffer.toString(),
            status: LingMessageStatus.sent,
          ));
        }
        _convController.upsertConversation(conv.copyWith(
          lastMessage: controller.messages.last,
        ));
      },
      onDone: () {
        controller.isTyping = false;
        if (aiMsgId != null) {
          controller.updateMessage(aiMsgId!, (m) => m.copyWith(
            text: buffer.toString().isEmpty ? '...' : buffer.toString(),
            status: LingMessageStatus.read,
          ));
          _convController.upsertConversation(conv.copyWith(
            lastMessage: controller.messages.last,
          ));
        }
        sub?.cancel();
      },
      onError: (e) {
        controller.isTyping = false;
        if (aiMsgId != null) {
          controller.updateMessage(aiMsgId!, (m) => m.copyWith(
            text: context.l10n.aiError(e.toString()),
            status: LingMessageStatus.failed,
          ));
        } else {
          // No content received yet — add an error message.
          controller.addMessage(LingMessage(
            id: 'ai_err_${DateTime.now().millisecondsSinceEpoch}',
            conversationId: conv.id,
            authorId: _aiBuddyId,
            type: LingMessageType.text,
            text: context.l10n.aiError(e.toString()),
            createdAt: DateTime.now(),
            status: LingMessageStatus.failed,
          ));
        }
        _convController.upsertConversation(conv.copyWith(
          lastMessage: controller.messages.last,
        ));
        sub?.cancel();
      },
    );
  }

  void _onPin(LingConversation conv) => _convController.togglePin(conv.id);
  void _onMute(LingConversation conv) => _convController.toggleMute(conv.id);

  void _onDraftChanged(LingConversation conv, String? text) {
    _convController.upsertConversation(conv.copyWith(draft: text));
  }

  void _onDelete(LingConversation conv) {
    _convController.removeConversation(conv.id);
    _chatControllers[conv.id]?.dispose();
    _chatControllers.remove(conv.id);
  }

  void _openChat(BuildContext context, LingConversation conv) {
    final controller = _chatControllers[conv.id];
    if (controller == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LingChatScreen(
          conversation: conv,
          controller: controller,
          userMap: _userMap,
          currentUserId: _currentUserId,
          onSend: (text) => _onSend(conv, text),
          forwardConversations: _convController.conversations,
          onForward: (msg, targetIds) => _onForward(msg, targetIds),
          onDraftChanged: (text) => _onDraftChanged(conv, text),
          appBarLeading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  /// 转发消息到目标会话
  void _onForward(LingMessage msg, List<String> targetConvIds) {
    for (final targetId in targetConvIds) {
      final targetController = _chatControllers[targetId];
      if (targetController == null) continue;
      final forwardedId =
          'forwarded_${DateTime.now().millisecondsSinceEpoch}_$targetId';
      // 创建新消息，保留内容但更新 id/conversationId
      // 文本消息加 [转发] 前缀
      String? text = msg.text;
      if (msg.type == LingMessageType.text && text != null) {
        text = '[转发] $text';
      }
      final forwardedMsg = LingMessage(
        id: forwardedId,
        conversationId: targetId,
        authorId: _currentUserId,
        type: msg.type,
        text: text,
        mediaUrl: msg.mediaUrl,
        mediaName: msg.mediaName,
        mediaSize: msg.mediaSize,
        duration: msg.duration,
        waveform: msg.waveform,
        width: msg.width,
        height: msg.height,
        metadata: msg.metadata,
        createdAt: DateTime.now(),
        status: LingMessageStatus.sent,
      );
      targetController.addMessage(forwardedMsg);
      // 更新会话列表的 lastMessage
      final conv = _convController.conversations
          .where((c) => c.id == targetId)
          .firstOrNull;
      if (conv != null) {
        _convController.upsertConversation(conv.copyWith(
          lastMessage: forwardedMsg,
        ));
      }
    }
  }

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) => LingMessageSearch(
          results: const [],
          onSearch: (query) {},
          onResultTap: (result) {},
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 搜索框从顶部滑入 + 渐显
          final offset = Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          final fade = animation.drive(CurveTween(curve: Curves.easeIn));
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: offset, child: child),
          );
        },
      ),
    );
  }

  Future<void> _onRefresh() async {
    // 模拟下拉刷新
    await Future.delayed(const Duration(seconds: 1));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.chatTitle),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _convController,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: LingConversationList(
              conversations: _convController.visible,
              currentUserId: _currentUserId,
              onConversationTap: (conv) => _openChat(context, conv),
              onSearchTap: () => _openSearch(context),
              onPin: _onPin,
              onMute: _onMute,
              onDelete: _onDelete,
              onMarkRead: (conv) =>
                  _convController.markAsRead(conv.id),
            ),
          );
        },
      ),
    );
  }
}

// ─── Mock 数据 ─────────────────────────────────────────────────────────

/// LingEcho is the AI buddy — messages to this conversation are routed to AiService.
const String _aiBuddyId = 'u3';
const String _aiBuddyName = 'LingEcho';

class _MockData {
  final List<LingConversation> conversations;
  final Map<String, LingChatUser> users;
  final Map<String, List<LingMessage>> messages;
  _MockData(this.conversations, this.users, this.messages);
}

_MockData _generateMockData() {
  final avatar = "https://cdn.lingecho.com/avatars/1_1787150270.jpg";
  final rng = Random(42);

  final me = LingChatUser(
    id: 'me',
    name: '我',
    avatarUrl: avatar,
    status: LingUserStatus.online,
  );

  final users = <String, LingChatUser>{'me': me};
  final conversations = <LingConversation>[];
  final messages = <String, List<LingMessage>>{};

  // ── LingEcho (AI buddy) ──────────────────────────────────────────────
  final lingEcho = LingChatUser(
    id: _aiBuddyId,
    name: _aiBuddyName,
    avatarUrl: avatar,
    status: LingUserStatus.online,
  );
  users[_aiBuddyId] = lingEcho;

  final aiMessages = <LingMessage>[
    LingMessage(
      id: '${_aiBuddyId}_msg_welcome',
      conversationId: _aiBuddyId,
      authorId: _aiBuddyId,
      type: LingMessageType.text,
      text: '你好！我是 LingEcho，你的 AI 助手。有什么可以帮你的吗？',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      status: LingMessageStatus.read,
    ),
  ];
  messages[_aiBuddyId] = aiMessages;

  conversations.add(LingConversation(
    id: _aiBuddyId,
    name: _aiBuddyName,
    type: LingConversationType.single,
    avatarUrl: avatar,
    members: [me, lingEcho],
    lastMessage: aiMessages.last,
    unreadCount: 0,
  ));

  // ── 校园交流群 (group chat) ──────────────────────────────────────────
  final groupMembers = [
    me,
    LingChatUser(id: 'g1', name: '同学A', avatarUrl: avatar, status: LingUserStatus.online),
    LingChatUser(id: 'g2', name: '同学B', avatarUrl: avatar, status: LingUserStatus.offline),
    LingChatUser(id: 'g3', name: '同学C', avatarUrl: avatar, status: LingUserStatus.away),
  ];
  for (final m in groupMembers) {
    users.putIfAbsent(m.id, () => m);
  }

  final groupTexts = [
    '有人去过新开的咖啡馆吗？',
    '明天的活动大家记得报名',
    '推荐一本好书呗',
    '收到！',
  ];

  final groupMessages = <LingMessage>[];
  for (int j = 0; j < 6; j++) {
    final senderId = groupMembers[(j % 3) + 1].id; // skip 'me', use g1/g2/g3
    groupMessages.add(LingMessage(
      id: 'group_msg_$j',
      conversationId: 'group1',
      authorId: senderId,
      type: LingMessageType.text,
      text: groupTexts[rng.nextInt(groupTexts.length)],
      createdAt: DateTime.now().subtract(Duration(minutes: (6 - j) * 20)),
      status: LingMessageStatus.read,
    ));
  }
  messages['group1'] = groupMessages;

  conversations.add(LingConversation(
    id: 'group1',
    name: '校园交流群',
    type: LingConversationType.group,
    avatarUrl: null,
    members: groupMembers,
    lastMessage: groupMessages.last,
    unreadCount: 5,
  ));

  return _MockData(conversations, users, messages);
}
