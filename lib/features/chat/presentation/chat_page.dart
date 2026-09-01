import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:nudgee/core/agent/agent.dart';
import 'package:nudgee/core/controllers/im/im.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/services/agent_service.dart';
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
      // Also listen to auth changes so avatar updates reflect immediately.
      sl<AuthService>().currentUser.addListener(_onAuthChanged);
    }
    // Build initial state from ChatService.
    _rebuildFromService();
  }

  void _onAuthChanged() {
    // User profile (e.g. avatar) changed — rebuild user map.
    if (mounted) _rebuildFromService();
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
      if (_chatControllers[conv.id] == null) {
        // Lazy load: only load the most recent messages (max 30)
        final allMsgs = chatService.getMessages(conv.id);
        final initialMsgs = allMsgs.length > 30
            ? allMsgs.sublist(allMsgs.length - 30)
            : allMsgs;
        final controller = LingChatController(
          conversationId: conv.id,
          currentUserId: _currentUserId,
          initialMessages: initialMsgs,
        );
        // If we truncated, there are more messages to load
        if (allMsgs.length > 30) {
          controller.endLoadMore(hasMore: true);
        } else {
          controller.endLoadMore(hasMore: false);
        }
        _chatControllers[conv.id] = controller;
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
    sl<AuthService>().currentUser.removeListener(_onAuthChanged);
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
      _streamAgentReply(conv, text);
    }
  }

  /// Stream an AI reply from AgentService (full agent stack with tools).
  ///
  /// Uses AgentCore's ReAct loop — the agent can call tools (web.search,
  /// schedule, memory, sandbox, etc.) and the UI visualizes each step:
  /// - Thinking process (streaming)
  /// - Tool calls (name + arguments)
  /// - Tool results (output)
  /// - Final reply (streaming markdown)
  void _streamAgentReply(LingConversation conv, String userText) {
    final agentService = sl<AgentService>();
    if (!agentService.isConfigured) {
      SmartDialog.showNotify(
        msg: context.l10n.aiNotConfigured,
        notifyType: NotifyType.error,
      );
      return;
    }

    final controller = _chatControllers[conv.id];
    if (controller == null) return;

    // Use custom system prompt for template-based conversations,
    // or the default 星语 prompt for the main AI conversation.
    final systemPrompt = _convSystemPrompts[conv.id] ??
        ChatService.aiAssistantSystemPrompt;

    // Only reset if the system prompt changed (e.g. switching conversations).
    // Don't reset on every message — that would wipe multi-turn history.
    if (agentService.currentSystemPrompt != systemPrompt) {
      agentService.reset(systemPrompt: systemPrompt);
    }

    controller.isTyping = true;

    // Ordered segments — each segment is a content/thinking/toolCall block
    // that renders in the order it occurred, interleaved with other segments.
    final segments = <Map<String, dynamic>>[];
    String? aiMsgId;
    StreamSubscription<AgentEvent>? sub;

    /// Gets or creates the last content segment for appending text.
    Map<String, dynamic>? _lastContentSegment() {
      if (segments.isNotEmpty && segments.last['type'] == 'content') {
        return segments.last;
      }
      return null;
    }

    /// Gets or creates the last thinking segment for appending text.
    Map<String, dynamic>? _lastThinkingSegment() {
      if (segments.isNotEmpty && segments.last['type'] == 'thinking') {
        return segments.last;
      }
      return null;
    }

    /// Builds the full content text from all content segments (for persistence).
    String _fullContentText() {
      return segments
          .where((s) => s['type'] == 'content')
          .map((s) => s['text'] as String)
          .join('');
    }

    /// Updates the AI message bubble with the current ordered segments.
    void updateBubble() {
      if (segments.isEmpty) return;

      final metadata = <String, dynamic>{
        'segments': List<Map<String, dynamic>>.from(segments),
      };

      // Also keep legacy fields for backward compatibility
      final fullText = _fullContentText();
      final thinkingText = segments
          .where((s) => s['type'] == 'thinking')
          .map((s) => s['text'] as String)
          .join('');
      if (thinkingText.isNotEmpty) metadata['thinking'] = thinkingText;
      final toolCallsList = segments.where((s) => s['type'] == 'toolCall').toList();
      if (toolCallsList.isNotEmpty) metadata['toolCalls'] = toolCallsList;

      if (aiMsgId == null) {
        aiMsgId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
        controller.addMessage(LingMessage(
          id: aiMsgId!,
          conversationId: conv.id,
          authorId: ChatService.aiAssistantId,
          type: LingMessageType.text,
          text: fullText,
          createdAt: DateTime.now(),
          status: LingMessageStatus.sending,
          metadata: metadata,
        ));
        controller.isTyping = false;
      } else {
        controller.updateMessage(aiMsgId!, (m) => m.copyWith(
          text: fullText,
          status: LingMessageStatus.sent,
          metadata: metadata,
        ));
      }
    }

    sub = agentService.run(userText).listen(
      (event) {
        switch (event) {
          case ThinkingEvent():
            // Append to last thinking segment, or create new one
            final last = _lastThinkingSegment();
            if (last != null) {
              last['text'] = (last['text'] as String) + event.delta;
            } else {
              segments.add({'type': 'thinking', 'text': event.delta});
            }
            updateBubble();

          case ContentEvent():
            // Append to last content segment, or create new one
            final last = _lastContentSegment();
            if (last != null) {
              last['text'] = (last['text'] as String) + event.delta;
            } else {
              segments.add({'type': 'content', 'text': event.delta});
            }
            updateBubble();

          case ToolCallEvent():
            // Mark previous content segment as "intermediate" (small/gray)
            // since it's just the AI narrating before a tool call, not the final answer
            if (segments.isNotEmpty && segments.last['type'] == 'content') {
              segments.last['intermediate'] = true;
            }
            // Always create a new tool call segment (preserves order)
            segments.add({
              'type': 'toolCall',
              'name': event.call.name,
              'arguments': event.call.arguments,
              'status': 'running',
            });
            updateBubble();

          case ToolResultEvent():
            // Update the last matching running toolCall segment
            for (var i = segments.length - 1; i >= 0; i--) {
              if (segments[i]['type'] == 'toolCall' &&
                  segments[i]['name'] == event.toolName &&
                  segments[i]['status'] == 'running') {
                segments[i] = {
                  'type': 'toolCall',
                  'name': event.toolName,
                  'arguments': segments[i]['arguments'],
                  'status': event.result.success ? 'success' : 'error',
                  'result': event.result.success
                      ? event.result.output
                      : event.result.error,
                };
                break;
              }
            }
            updateBubble();

          case DoneEvent():
            controller.isTyping = false;
            final finalText = _fullContentText().isEmpty
                ? '...'
                : _fullContentText();
            final metadata = <String, dynamic>{
              'segments': List<Map<String, dynamic>>.from(segments),
            };
            // Legacy fields
            final thinkingText = segments
                .where((s) => s['type'] == 'thinking')
                .map((s) => s['text'] as String)
                .join('');
            if (thinkingText.isNotEmpty) metadata['thinking'] = thinkingText;
            final toolCallsList = segments.where((s) => s['type'] == 'toolCall').toList();
            if (toolCallsList.isNotEmpty) metadata['toolCalls'] = toolCallsList;
            if (event.stats.steps > 0) {
              metadata['stats'] = {
                'steps': event.stats.steps,
                'toolCalls': event.stats.toolCalls,
                'tokens': event.stats.inputTokens + event.stats.outputTokens,
                'durationMs': event.stats.duration.inMilliseconds,
              };
            }
            if (aiMsgId != null) {
              controller.updateMessage(aiMsgId!, (m) => m.copyWith(
                text: finalText,
                status: LingMessageStatus.read,
                metadata: metadata,
              ));
            } else {
              controller.addMessage(LingMessage(
                id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
                conversationId: conv.id,
                authorId: ChatService.aiAssistantId,
                type: LingMessageType.text,
                text: finalText,
                createdAt: DateTime.now(),
                status: LingMessageStatus.read,
                metadata: metadata,
              ));
            }
            // Persist the AI message to ChatService (SQLite + cloud).
            sl<ChatService>().addAiMessage(
              conversationId: conv.id,
              text: finalText,
            );
            // Add AI reply to agent history for multi-turn context.
            sl<AgentService>().addAssistantHistory(finalText);

          case ErrorEvent():
            debugPrint('[ChatPage] Agent error: ${event.message}');
            controller.isTyping = false;
            final errText = context.l10n.aiError(event.message);
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

          case HumanConfirmationEvent():
            // Auto-approve in bypass mode
            break;

          case LoopWarningEvent():
            debugPrint('[ChatPage] Loop warning at step ${event.stepCount}');
            break;

          case PlanEvent():
            // Could display plan steps in UI
            break;
        }
      },
      onError: (e) {
        debugPrint('[ChatPage] Stream error: $e');
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
      onDone: () {
        controller.isTyping = false;
        sub?.cancel();
      },
      cancelOnError: true,
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

  /// Load more historical messages when user scrolls to top.
  Future<void> _onLoadMore(LingConversation conv) async {
    final controller = _chatControllers[conv.id];
    if (controller == null || !controller.hasMore || controller.isLoadingMore) {
      return;
    }
    controller.beginLoadMore();
    // Simulate async load (ChatService is in-memory)
    final allMsgs = sl<ChatService>().getMessages(conv.id);
    final currentCount = controller.messages.length;
    if (allMsgs.length <= currentCount) {
      controller.endLoadMore(hasMore: false);
      return;
    }
    // Load 20 more older messages
    const pageSize = 20;
    final remaining = allMsgs.length - currentCount;
    final take = remaining < pageSize ? remaining : pageSize;
    final older = allMsgs.sublist(
      allMsgs.length - currentCount - take,
      allMsgs.length - currentCount,
    );
    controller.prependMessages(older);
    controller.endLoadMore(hasMore: allMsgs.length > currentCount + take);
  }

  void _openChat(BuildContext context, LingConversation conv) {
    final controller = _chatControllers[conv.id];
    if (controller == null) return;

    // Determine if this is an AI conversation (default assistant or template-based).
    final isAiConv = conv.id == ChatService.aiAssistantId ||
        _convSystemPrompts.containsKey(conv.id);

    final ai = sl<AgentService>();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LingChatScreen(
          conversation: conv,
          controller: controller,
          userMap: _userMap,
          currentUserId: _currentUserId,
          onSend: (text) => _onSend(conv, text),
          onLoadMore: () => _onLoadMore(conv),
          forwardConversations: _convController.conversations,
          onForward: (msg, targetIds) => _onForward(msg, targetIds),
          onDraftChanged: (text) => _onDraftChanged(conv, text),
          isAiConversation: isAiConv,
          currentAiModel: ai.currentModel,
          availableAiModels: const [],
          onSwitchModel: (model) async {
            ai.switchModel(model);
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
    sl<AgentService>().reset(systemPrompt: filledPrompt);

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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('提示词模板功能即将上线')),
              );
            },
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
