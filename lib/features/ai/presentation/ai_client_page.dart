import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/extensions/context_extensions.dart';
import 'package:nudgee/core/services/ai_service.dart';

/// AI chat client page — streaming chat with AI via [AiService].
class AiClientPage extends StatefulWidget {
  const AiClientPage({super.key});

  @override
  State<AiClientPage> createState() => _AiClientPageState();
}

class _AiClientPageState extends State<AiClientPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isStreaming = false;
  StreamSubscription<String>? _streamSub;

  @override
  void initState() {
    super.initState();
    final l10n = context.l10n;
    _messages.add(_ChatMessage(role: _Role.assistant, text: l10n.aiWelcome));
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isStreaming) return;

    final l10n = context.l10n;
    final ai = sl<AiService>();
    if (!ai.isConfigured) {
      SmartDialog.showNotify(msg: l10n.aiNotConfigured, notifyType: NotifyType.error);
      return;
    }

    _inputController.clear();

    setState(() {
      _messages.add(_ChatMessage(role: _Role.user, text: text));
      _messages.add(_ChatMessage(role: _Role.assistant, text: '', streaming: true));
      _isStreaming = true;
    });
    _scrollToBottom();

    final assistantIndex = _messages.length - 1;
    final buffer = StringBuffer();

    try {
      _streamSub = ai.streamChat(text).listen(
        (delta) {
          buffer.write(delta);
          setState(() {
            _messages[assistantIndex] = _ChatMessage(
              role: _Role.assistant,
              text: buffer.toString(),
              streaming: true,
            );
          });
          _scrollToBottom();
        },
        onDone: () {
          setState(() {
            _messages[assistantIndex] = _ChatMessage(
              role: _Role.assistant,
              text: buffer.toString(),
              streaming: false,
            );
            _isStreaming = false;
          });
          _scrollToBottom();
        },
        onError: (e) {
          setState(() {
            _messages[assistantIndex] = _ChatMessage(
              role: _Role.assistant,
              text: l10n.aiError(e.toString()),
              streaming: false,
              isError: true,
            );
            _isStreaming = false;
          });
          _scrollToBottom();
        },
      );
    } catch (e) {
      setState(() {
        _messages[assistantIndex] = _ChatMessage(
          role: _Role.assistant,
          text: l10n.aiError(e.toString()),
          streaming: false,
          isError: true,
        );
        _isStreaming = false;
      });
    }
  }

  void _stopStreaming() {
    _streamSub?.cancel();
    setState(() {
      _isStreaming = false;
      // Mark last assistant message as done
      for (int i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].role == _Role.assistant && _messages[i].streaming) {
          _messages[i] = _ChatMessage(
            role: _Role.assistant,
            text: _messages[i].text,
            streaming: false,
          );
          break;
        }
      }
    });
  }

  void _clearChat() {
    final l10n = context.l10n;
    sl<AiService>().clearContext();
    setState(() {
      _messages.clear();
      _messages.add(_ChatMessage(role: _Role.assistant, text: l10n.aiWelcome));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.aiTitle),
        backgroundColor: theme.colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: l10n.aiClearChat,
            onPressed: _isStreaming ? null : _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Messages ───────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _MessageBubble(message: msg);
              },
            ),
          ),
          // ── Input ──────────────────────────────────────────────────────
          _InputBar(
            controller: _inputController,
            isStreaming: _isStreaming,
            onSend: _sendMessage,
            onStop: _stopStreaming,
            hint: l10n.aiHint,
            sendLabel: l10n.aiSend,
          ),
        ],
      ),
    );
  }
}

/// A single chat message bubble.
class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == _Role.user;

    final bg = isUser
        ? theme.colorScheme.primary
        : message.isError
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest;
    final fg = isUser
        ? theme.colorScheme.onPrimary
        : message.isError
            ? theme.colorScheme.onErrorContainer
            : theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.streaming && message.text.isEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg.withAlpha(150),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.aiThinking,
                    style: theme.textTheme.bodySmall?.copyWith(color: fg.withAlpha(180)),
                  ),
                ],
              )
            else if (isUser)
                SelectableText(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                )
              else
                MarkdownBody(
                  data: message.text,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyMedium?.copyWith(color: fg),
                    code: theme.textTheme.bodySmall?.copyWith(
                      color: fg,
                      backgroundColor: fg.withAlpha(20),
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: fg.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            if (message.streaming && message.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('▌', style: TextStyle(color: fg.withAlpha(100))),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom input bar with send/stop button.
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isStreaming;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final String hint;
  final String sendLabel;

  const _InputBar({
    required this.controller,
    required this.isStreaming,
    required this.onSend,
    required this.onStop,
    required this.hint,
    required this.sendLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.dividerColor.withAlpha(60), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => isStreaming ? null : onSend(),
                decoration: InputDecoration(
                  hintText: hint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: isStreaming ? onStop : onSend,
              icon: Icon(isStreaming ? Icons.stop : Icons.send),
              tooltip: isStreaming ? 'Stop' : sendLabel,
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal chat message model.
class _ChatMessage {
  final _Role role;
  final String text;
  final bool streaming;
  final bool isError;

  const _ChatMessage({
    required this.role,
    required this.text,
    this.streaming = false,
    this.isError = false,
  });
}

enum _Role { user, assistant }
