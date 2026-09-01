import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:nudgee/core/controllers/im/im.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/services/ai_service.dart';
import 'package:nudgee/core/services/auth_service.dart';
import 'package:nudgee/core/services/chat_service.dart';
import 'package:nudgee/core/widgets/im/ling_chat_screen.dart';
import 'package:nudgee/core/widgets/im/ling_message_search.dart';
import 'package:nudgee/core/widgets/im/im.dart';
import 'package:nudgee/features/chat/presentation/prompt_template_page.dart';
import 'package:nudgee/core/models/prompt_template.dart';

/// 聊天页面 — 会话列表 + 聊天详情。
///
/// 使用 ChatService (SQLite + 七牛云同步) 管理真实聊天数据。
/// 每个用户默认有一个 AI 助手"星语"会话。
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final LingConversationController _convController = LingConversationController();
  final Map<String, LingChatController> _chatControllers = {};
  final Map<String, LingChatUser> _userMap = {};
  /// Per-conversation AI system prompts (for template-based AI sessions).
  final Map<String, String> _convSystemPrompts = {};
  bool _isListening = false;

  String get _currentUserId =>
      sl<AuthService>().currentUser.value?.id ?? 'me';

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  void _initChat() {
    final chatService = sl<ChatService>();
    if (!_isListening) {
      _isListening = true;
      chatService.addListener(_onChatChanged);
    }
    // Build initial state from ChatService.
    _rebuildFromService();
  }

  void _onChatChanged() {
    _rebuildFromService();
  }

  void _rebuildFromService() {
    final chatService = sl<ChatService>();
    final auth = sl<AuthService>();
    final user = auth.currentUser.value;
    final myName = user?.name ?? '我';
    final myAvatar = user?.avatar;

    // Build user map.
    _userMap.clear();
    _userMap[_currentUserId] = LingChatUser(
      id: _currentUserId,
      name: myName,
      avatarUrl: myAvatar,
      status: LingUserStatus.online,
    );

    for (final conv in chatService.conversations) {
      for (final m in conv.members) {
        _userMap.putIfAbsent(m.id, () => m);
      }
      // Ensure AI assistant user is in map.
      if (conv.id == ChatService.aiAssistantId) {
        _userMap[ChatService.aiAssistantId] = LingChatUser(
          id: ChatService.aiAssistantId,
          name: ChatService.aiAssistantName,
          avatarUrl: conv.avatarUrl,
          status: LingUserStatus.online,
        );
      }
    }

    // Build / refresh chat controllers.
    final activeConvIds = <String>{};
    for (final conv in chatService.conversations) {
      activeConvIds.add(conv.id);
      final msgs = chatService.getMessages(conv.id);
      if (_chatControllers[conv.id] == null) {
        _chatControllers[conv.id] = LingChatController(
          conversationId: conv.id,
          currentUserId: _currentUserId,
          initialMessages: msgs,
        );
      }
    }
    // Dispose controllers for deleted conversations.
    _chatControllers.keys
        .where((id) => !activeConvIds.contains(id))
        .toList()
        .forEach((id) {
      _chatControllers[id]?.dispose();
      _chatControllers.remove(id);
    });

    // Update conversation controller.
    if (_convController.isDisposed) return;
    _convController.replaceAll(chatService.conversations);
  }

  @override
  void dispose() {
    sl<ChatService>().removeListener(_onChatChanged);
    _chatControllers.values.forEach((c) => c.dispose());
    _convController.dispose();
    super.dispose();
  }

  // ── 发送消息 ──────────────────────────────────────────────────────────

  void _onSend(LingConversation conv, String text) async {
    // LingChatScreen already adds the user bubble to the controller internally.
    // We only persist to ChatService here (no duplicate addMessage).
    await sl<ChatService>().sendMessage(
      conversationId: conv.id,
      authorId: _currentUserId,
      text: text,
    );

    // Route to AI if this is the AI assistant or a template-based AI conversation.
    final isAiConv = conv.id == ChatService.aiAssistantId ||
        _convSystemPrompts.containsKey(conv.id);
    if (isAiConv) {
      // For the default assistant, ensure default system prompt is set.
      if (conv.id == ChatService.aiAssistantId) {
        _convSystemPrompts.remove(conv.id); // Clear any custom prompt.
        sl<AiService>().reset(systemPrompt: ChatService.aiAssistantSystemPrompt);
      }
      _streamAiReply(conv, text);
    }
  }

  /// Stream an AI reply from AiService and persist it.
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

    // If this conversation has a custom system prompt (from a template),
    // reset the AI context with it before streaming.
    final systemPrompt = _convSystemPrompts[conv.id];
    if (systemPrompt != null) {
      ai.reset(systemPrompt: systemPrompt);
    }

    controller.isTyping = true;

    final contentBuffer = StringBuffer();
    final thinkingBuffer = StringBuffer();
    String? aiMsgId;
    StreamSubscription<AiStreamChunk>? sub;

    sub = ai.streamChatWithThinking(userText).listen(
      (chunk) {
        if (chunk.isThinking) {
          thinkingBuffer.write(chunk.text);
          // While thinking, keep typing indicator on.
          return;
        }

        // Content delta.
        contentBuffer.write(chunk.text);
        if (aiMsgId == null) {
          aiMsgId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
          controller.addMessage(LingMessage(
            id: aiMsgId!,
            conversationId: conv.id,
            authorId: ChatService.aiAssistantId,
            type: LingMessageType.text,
            text: contentBuffer.toString(),
            createdAt: DateTime.now(),
            status: LingMessageStatus.sent,
            metadata: thinkingBuffer.isNotEmpty
                ? {'thinking': thinkingBuffer.toString()}
                : null,
          ));
          controller.isTyping = false;
        } else {
          controller.updateMessage(aiMsgId!, (m) => m.copyWith(
            text: contentBuffer.toString(),
            status: LingMessageStatus.sent,
            metadata: thinkingBuffer.isNotEmpty
                ? {'thinking': thinkingBuffer.toString()}
                : null,
          ));
        }
      },
      onDone: () {
        controller.isTyping = false;
        final finalText = contentBuffer.toString().isEmpty ? '...' : contentBuffer.toString();
        final thinking = thinkingBuffer.toString();
        if (aiMsgId != null) {
          controller.updateMessage(aiMsgId!, (m) => m.copyWith(
            text: finalText,
            status: LingMessageStatus.read,
            metadata: thinking.isNotEmpty ? {'thinking': thinking} : null,
          ));
        }
        // Persist the AI message to ChatService (SQLite + cloud).
        sl<ChatService>().addAiMessage(
          conversationId: conv.id,
          text: finalText,
        );
        sub?.cancel();
      },
      onError: (e) {
        controller.isTyping = false;
        final errText = context.l10n.aiError(e.toString());
        if (aiMsgId != null) {
          controller.updateMessage(aiMsgId!, (m) => m.copyWith(
            text: errText,
            status: LingMessageStatus.failed,
          ));
        } else {
          controller.addMessage(LingMessage(
            id: 'ai_err_${DateTime.now().millisecondsSinceEpoch}',
            conversationId: conv.id,
            authorId: ChatService.aiAssistantId,
            type: LingMessageType.text,
            text: errText,
            createdAt: DateTime.now(),
            status: LingMessageStatus.failed,
          ));
        }
        sub?.cancel();
      },
    );
  }

  // ── 会话操作 ──────────────────────────────────────────────────────────

  void _onPin(LingConversation conv) =>
      sl<ChatService>().togglePin(conv.id);
  void _onMute(LingConversation conv) =>
      sl<ChatService>().toggleMute(conv.id);

  void _onDraftChanged(LingConversation conv, String? text) {
    sl<ChatService>().saveDraft(conv.id, text);
  }

  void _onDelete(LingConversation conv) {
    sl<ChatService>().deleteConversation(conv.id);
    _chatControllers[conv.id]?.dispose();
    _chatControllers.remove(conv.id);
  }

  void _onMarkRead(LingConversation conv) {
    sl<ChatService>().markAsRead(conv.id);
  }

  void _openChat(BuildContext context, LingConversation conv) {
    final controller = _chatControllers[conv.id];
    if (controller == null) return;

    // Determine if this is an AI conversation (default assistant or template-based).
    final isAiConv = conv.id == ChatService.aiAssistantId ||
        _convSystemPrompts.containsKey(conv.id);

    final ai = sl<AiService>();

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
          isAiConversation: isAiConv,
          currentAiModel: ai.currentModel,
          availableAiModels: ai.availableModels,
          onSwitchModel: (model) async {
            await ai.switchModel(model);
            // Reset context with the appropriate system prompt.
            final prompt = _convSystemPrompts[conv.id] ??
                ChatService.aiAssistantSystemPrompt;
            ai.reset(systemPrompt: prompt);
            if (mounted) setState(() {});
          },
          appBarLeading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  /// 转发消息到目标会话
  void _onForward(LingMessage msg, List<String> targetIds) {
    for (final targetId in targetIds) {
      String? text = msg.text;
      if (msg.type == LingMessageType.text && text != null) {
        text = '[转发] $text';
      }
      sl<ChatService>().sendMessage(
        conversationId: targetId,
        authorId: _currentUserId,
        text: text ?? '',
        type: msg.type,
        mediaUrl: msg.mediaUrl,
      );
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
    await sl<ChatService>().syncFromCloud();
    setState(() {});
  }

  /// 打开模板选择页面，选择模板后创建新的 AI 会话。
  Future<void> _openTemplatePage() async {
    final result = await Navigator.of(context).push<(PromptTemplate, String)>(
      MaterialPageRoute(
        builder: (_) => const PromptTemplatePage(),
      ),
    );
    if (result == null) return;

    final (template, filledPrompt) = result;
    await _createAiConversationFromTemplate(template, filledPrompt);
  }

  /// 根据模板创建新的 AI 会话。
  Future<void> _createAiConversationFromTemplate(
    PromptTemplate template,
    String filledPrompt,
  ) async {
    final chatService = sl<ChatService>();
    final convId = 'ai_${template.id}_${DateTime.now().millisecondsSinceEpoch}';

    final me = LingChatUser(
      id: _currentUserId,
      name: sl<AuthService>().currentUser.value?.name ?? '我',
      avatarUrl: sl<AuthService>().currentUser.value?.avatar,
      status: LingUserStatus.online,
    );
    final ai = LingChatUser(
      id: convId,
      name: template.name,
      avatarUrl: '',
      status: LingUserStatus.online,
    );

    // Welcome message from the AI with the template persona.
    final welcomeMsg = LingMessage(
      id: '${convId}_welcome',
      conversationId: convId,
      authorId: convId,
      type: LingMessageType.text,
      text: '你好！我是${template.name} ${template.icon}\n${template.description}\n有什么可以帮你的吗？',
      createdAt: DateTime.now(),
      status: LingMessageStatus.read,
    );

    await chatService.createConversation(
      id: convId,
      name: template.name,
      avatarUrl: '',
      members: [me, ai],
    );

    // Save welcome message.
    await chatService.addAiMessage(conversationId: convId, text: welcomeMsg.text ?? '');

    // Reset AI context with the template's system prompt.
    sl<AiService>().reset(systemPrompt: filledPrompt);

    // Store the system prompt in memory for this conversation.
    _convSystemPrompts[convId] = filledPrompt;

    if (mounted) {
      // Find the newly created conversation and open it.
      final conv = chatService.conversations.where((c) => c.id == convId).firstOrNull;
      if (conv != null) {
        _openChat(context, conv);
      }
    }
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
            onPressed: _openTemplatePage,
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
              onMarkRead: _onMarkRead,
            ),
          );
        },
      ),
    );
  }
}
