import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nudgee/core/controllers/im/im.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/models/im/im.dart';
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

  final mockContacts = [
    {'id': 'u1', 'name': '小明同学', 'status': LingUserStatus.online},
    {'id': 'u2', 'name': '阿强', 'status': LingUserStatus.offline},
    {'id': 'u3', 'name': 'LingEcho', 'status': LingUserStatus.online},
    {'id': 'u4', 'name': '校园达人', 'status': LingUserStatus.away},
    {'id': 'u5', 'name': '课表君', 'status': LingUserStatus.busy},
  ];

  final mockTexts = [
    '你好呀，最近怎么样？',
    '今天的课表看了吗？',
    '食堂二楼新出的麻辣香锅真的绝了',
    '周末有空一起打球吗？',
    '这个组件库封装得真不错',
    '收到，我稍后看看',
    '哈哈哈哈太搞笑了',
    '好的没问题',
  ];

  for (int i = 0; i < mockContacts.length; i++) {
    final c = mockContacts[i];
    final userId = c['id'] as String;
    final userName = c['name'] as String;
    final status = c['status'] as LingUserStatus;

    final user = LingChatUser(
      id: userId,
      name: userName,
      avatarUrl: avatar,
      status: status,
    );
    users[userId] = user;

    final convMessages = <LingMessage>[];
    final msgCount = 4 + rng.nextInt(4);
    for (int j = 0; j < msgCount; j++) {
      final isMe = j % 2 == 0;
      convMessages.add(LingMessage(
        id: '${userId}_msg_$j',
        conversationId: userId,
        authorId: isMe ? 'me' : userId,
        type: LingMessageType.text,
        text: mockTexts[rng.nextInt(mockTexts.length)],
        createdAt: DateTime.now()
            .subtract(Duration(minutes: (msgCount - j) * 15 + i * 30)),
        status: LingMessageStatus.read,
      ));
    }

    final lastMsg = convMessages.last;
    final unread = i < 2 ? 1 + rng.nextInt(3) : 0;

    conversations.add(LingConversation(
      id: userId,
      name: userName,
      type: LingConversationType.single,
      avatarUrl: avatar,
      members: [me, user],
      lastMessage: lastMsg,
      unreadCount: unread,
    ));
    messages[userId] = convMessages;
  }

  // 群聊
  final groupMembers = [
    me,
    ...mockContacts.map((c) => LingChatUser(
          id: c['id'] as String,
          name: c['name'] as String,
          avatarUrl: avatar,
          status: c['status'] as LingUserStatus,
        )),
  ];

  final groupMessages = <LingMessage>[];
  for (int j = 0; j < 6; j++) {
    final senderId = mockContacts[j % mockContacts.length]['id'] as String;
    groupMessages.add(LingMessage(
      id: 'group_msg_$j',
      conversationId: 'group1',
      authorId: senderId,
      type: LingMessageType.text,
      text: mockTexts[rng.nextInt(mockTexts.length)],
      createdAt: DateTime.now().subtract(Duration(minutes: (6 - j) * 20)),
      status: LingMessageStatus.read,
    ));
  }

  conversations.add(LingConversation(
    id: 'group1',
    name: '校园交流群',
    type: LingConversationType.group,
    avatarUrl: null,
    members: groupMembers,
    lastMessage: groupMessages.last,
    unreadCount: 5,
  ));
  messages['group1'] = groupMessages;

  for (final m in groupMembers) {
    users.putIfAbsent(m.id, () => m);
  }

  return _MockData(conversations, users, messages);
}
