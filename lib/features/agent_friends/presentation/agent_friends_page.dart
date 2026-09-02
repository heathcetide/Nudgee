import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';

import 'package:nudgee/app/router/app_router.dart';
import 'package:nudgee/core/agent/agent.dart';
import 'package:nudgee/core/controllers/im/im.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/models/agent_friend.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/services/agent_friend_service.dart';
import 'package:nudgee/core/services/agent_service.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/services/chat_service.dart';
import 'package:nudgee/core/widgets/im/ling_chat_screen.dart';
import 'package:nudgee/features/common/widgets/page_scaffold.dart';

/// Agent 好友列表页面。
///
/// 显示所有 Agent 好友，可以添加新的、删除自定义的、
/// 点击进入对话。
class AgentFriendsPage extends StatefulWidget {
  const AgentFriendsPage({super.key});

  @override
  State<AgentFriendsPage> createState() => _AgentFriendsPageState();
}

class _AgentFriendsPageState extends State<AgentFriendsPage> {
  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    final service = sl<AgentFriendService>();
    await service.init();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = sl<AgentFriendService>();
    final friends = service.friends;

    return PageScaffold(
      title: const Text('Agent 好友'),
      leading: getPopLeading(context),
      customActions: [
        IconButton(
          icon: const Icon(Icons.person_add_outlined),
          onPressed: () async {
            final result = await GoRouter.of(context).push<bool>(
              AppRouter.addAgentFriend,
            );
            if (result == true && mounted) setState(() {});
          },
        ),
      ],
      child: friends.isEmpty
          ? _buildEmpty(theme)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return _buildFriendTile(friend, theme);
              },
            ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_toy_outlined, size: 64, color: theme.hintColor),
          const SizedBox(height: 16),
          Text(
            '还没有 Agent 好友',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角添加一个专属 Agent',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final result = await GoRouter.of(context).push<bool>(
                AppRouter.addAgentFriend,
              );
              if (result == true && mounted) setState(() {});
            },
            icon: const Icon(Icons.person_add),
            label: const Text('添加 Agent 好友'),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(AgentFriend friend, ThemeData theme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withAlpha(100),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(friend.icon, style: const TextStyle(fontSize: 26)),
        ),
      ),
      title: Row(
        children: [
          Text(
            friend.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (friend.isBuiltin) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '内置',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        friend.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.hintColor,
        ),
      ),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, size: 20, color: theme.hintColor),
        onSelected: (value) async {
          if (value == 'chat') {
            _openChat(friend);
          } else if (value == 'delete') {
            _confirmDelete(friend);
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'chat', child: Text('开始对话')),
          if (!friend.isBuiltin)
            const PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
      onTap: () => _openChat(friend),
    );
  }

  void _openChat(AgentFriend friend) {
    final chatService = sl<ChatService>();
    final conv = chatService.conversations
        .where((c) => c.id == friend.id)
        .firstOrNull;

    if (conv == null) {
      SmartDialog.showNotify(
        msg: '对话未就绪，请稍后再试',
        notifyType: NotifyType.warning,
      );
      return;
    }

    final currentUserId = sl<AuthService>().currentUser.value?.id ?? 'me';

    // Create a chat controller and load messages for this conversation.
    final messages = chatService.getMessages(conv.id);
    final controller = LingChatController(
      conversationId: conv.id,
      currentUserId: currentUserId,
      initialMessages: messages,
    );

    // Build user map for rendering.
    final userMap = <String, LingChatUser>{};
    for (final m in conv.members) {
      userMap[m.id] = m;
    }
    // Ensure current user is in the map.
    final currentUser = sl<AuthService>().currentUser.value;
    if (currentUser != null && !userMap.containsKey(currentUser.id)) {
      userMap[currentUser.id] = LingChatUser(
        id: currentUser.id,
        name: currentUser.name,
        avatarUrl: currentUser.avatar,
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LingChatScreen(
          conversation: conv,
          controller: controller,
          userMap: userMap,
          currentUserId: currentUserId,
          onSend: (text) async {
            await chatService.sendMessage(
              conversationId: conv.id,
              authorId: currentUserId,
              text: text,
            );
            // Route to the agent friend's AI.
            _streamAgentReply(conv, friend, text, controller);
          },
          onAiMessage: (c, aiText, {images}) =>
              _streamAgentReply(c, friend, aiText, controller, images: images),
        ),
      ),
    );
  }

  void _streamAgentReply(
    LingConversation conv,
    AgentFriend friend,
    String userText,
    LingChatController controller, {
    List<String>? images,
  }) {
    final agentService = sl<AgentService>();
    agentService.ensureInitialized();
    if (!agentService.isConfigured) {
      SmartDialog.showNotify(
        msg: context.l10n.aiNotConfigured,
        notifyType: NotifyType.error,
      );
      return;
    }

    // Use the friend's system prompt.
    if (agentService.currentSystemPrompt != friend.systemPrompt) {
      agentService.reset(systemPrompt: friend.systemPrompt);
    }

    controller.isTyping = true;

    // Create AI message bubble (same pattern as chat_page.dart).
    String aiMsgId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
    String contentText = '';
    controller.addMessage(LingMessage(
      id: aiMsgId,
      conversationId: conv.id,
      authorId: friend.id,
      type: LingMessageType.text,
      text: '',
      createdAt: DateTime.now(),
      status: LingMessageStatus.sending,
    ));

    final sub = agentService.run(userText, images: images).listen(
      (event) {
        if (event is ContentEvent) {
          contentText += event.delta;
          controller.updateMessage(aiMsgId, (m) => m.copyWith(
            text: contentText,
            status: LingMessageStatus.sent,
          ));
        } else if (event is DoneEvent) {
          final finalText = event.finalReply.isNotEmpty
              ? event.finalReply
              : contentText;
          controller.updateMessage(aiMsgId, (m) => m.copyWith(
            text: finalText,
            status: LingMessageStatus.read,
          ));
          controller.isTyping = false;
          // Persist AI message to ChatService.
          sl<ChatService>().addAiMessage(
            conversationId: conv.id,
            text: finalText,
          );
        } else if (event is ErrorEvent) {
          controller.isTyping = false;
          controller.updateMessage(aiMsgId, (m) => m.copyWith(
            text: '⚠️ ${event.message}',
            status: LingMessageStatus.failed,
          ));
        }
      },
      onError: (e) {
        controller.isTyping = false;
        controller.updateMessage(aiMsgId, (m) => m.copyWith(
          text: '⚠️ AI 回复出错: $e',
          status: LingMessageStatus.failed,
        ));
      },
    );

    _subscriptions.add(sub);
  }

  final List<StreamSubscription> _subscriptions = [];

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _confirmDelete(AgentFriend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除 Agent 好友'),
        content: Text('确定要删除「${friend.name}」吗？对话记录也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await sl<AgentFriendService>().deleteFriend(friend.id);
      if (mounted) {
        SmartDialog.showNotify(msg: '已删除', notifyType: NotifyType.success);
        setState(() {});
      }
    }
  }
}
