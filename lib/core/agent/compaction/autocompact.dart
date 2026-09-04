import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/providers/llm_client.dart';

/// Autocompact — Level 2 LLM-based context summarization.
///
/// When microcompact (Level 1) is insufficient to keep the context within
/// the model's window, autocompact uses an LLM call to summarize older
/// conversation messages into a compact summary. The summary replaces
/// the original messages, drastically reducing token count while preserving
/// key information (decisions made, facts learned, tool results).
///
/// Two-tier compaction strategy:
/// - Level 1: Microcompact — local, fast, zero cost (elides old tool results)
/// - Level 2: Autocompact (this) — LLM-based summarization (costs one LLM call)
///
/// Usage:
/// ```dart
/// final autocompact = Autocompact(llmClient: client, model: 'deepseek-chat');
/// final compacted = await autocompact.compact(messages, targetTokens: 20000);
/// ```
class Autocompact {
  /// LLM client for making summarization requests.
  final LLMClient llmClient;

  /// Model to use for summarization.
  final String model;

  /// Maximum tokens for the summary output.
  final int maxSummaryTokens;

  /// Token threshold above which autocompact is triggered.
  final int triggerTokenThreshold;

  /// Number of recent messages to always keep verbatim (not summarized).
  final int keepRecentMessages;

  /// Minimum messages needed before summarization is worthwhile.
  final int minMessagesToCompact;

  /// Creates an [Autocompact].
  Autocompact({
    required this.llmClient,
    this.model = 'deepseek-chat',
    this.maxSummaryTokens = 2000,
    this.triggerTokenThreshold = 50000,
    this.keepRecentMessages = 6,
    this.minMessagesToCompact = 10,
  });

  /// Runs autocompact on [messages].
  ///
  /// If the estimated token count is below [triggerTokenThreshold], or there
  /// are too few messages, returns the input unchanged.
  ///
  /// Otherwise:
  /// 1. Splits messages into [oldMessages] (to summarize) and [recentMessages]
  ///    (to keep verbatim).
  /// 2. Calls the LLM to generate a summary of [oldMessages].
  /// 3. Returns `[summaryMessage, ...recentMessages]`.
  Future<List<LlmMessage>> compact(
    List<LlmMessage> messages, {
    int? targetTokens,
  }) async {
    if (messages.length < minMessagesToCompact) {
      return messages;
    }

    final estimatedTokens = _estimateTotalTokens(messages);
    if (estimatedTokens < triggerTokenThreshold) {
      return messages;
    }

    final splitIndex = messages.length - keepRecentMessages;
    if (splitIndex <= 0) {
      return messages;
    }

    final oldMessages = messages.sublist(0, splitIndex);
    final recentMessages = messages.sublist(splitIndex);

    debugPrint('[Autocompact] compacting ${oldMessages.length} messages '
        '(~${_estimateTotalTokens(oldMessages)} tokens) into summary');

    try {
      final summary = await _generateSummary(oldMessages);
      final summaryMessage = LlmMessage.system(
        '--- Conversation Summary (auto-compacted) ---\n$summary\n'
        '--- End of Summary ---',
      );

      final result = [summaryMessage, ...recentMessages];
      final newTokens = _estimateTotalTokens(result);
      debugPrint('[Autocompact] compacted: $estimatedTokens -> $newTokens tokens '
          '(${(100 * newTokens / estimatedTokens).round()}% of original)');

      return result;
    } catch (e) {
      debugPrint('[Autocompact] summarization failed: $e, falling back to truncation');
      // Fallback: keep only recent messages
      return recentMessages;
    }
  }

  /// Generates a summary of [messages] using the LLM.
  Future<String> _generateSummary(List<LlmMessage> messages) async {
    final conversationText = _formatMessagesForSummary(messages);

    final summaryPrompt = 'You are a conversation summarizer. '
        'Summarize the following conversation between a user and an AI assistant. '
        'Preserve all important information:\n'
        '- Key decisions and conclusions\n'
        '- Facts learned from tool calls (data, search results, etc.)\n'
        '- User preferences and requests\n'
        '- Any pending tasks or unresolved questions\n\n'
        'Be concise but complete. Use bullet points for clarity.\n\n'
        'Conversation to summarize:\n$conversationText';

    final response = await llmClient.chat(
      messages: [LlmMessage.user(summaryPrompt)],
      model: model,
      temperature: 0.0,
      maxTokens: maxSummaryTokens,
    );

    return response.content;
  }

  /// Formats messages into a readable text for the summarization prompt.
  String _formatMessagesForSummary(List<LlmMessage> messages) {
    final buffer = StringBuffer();

    for (final msg in messages) {
      switch (msg.role) {
        case 'user':
          buffer.writeln('User: ${msg.content ?? ""}');
        case 'assistant':
          if (msg.content != null && msg.content!.isNotEmpty) {
            buffer.writeln('Assistant: ${msg.content}');
          }
          if (msg.toolCalls != null) {
            for (final tc in msg.toolCalls!) {
              buffer.writeln('Assistant called tool: ${tc.name}(${tc.arguments})');
            }
          }
        case 'tool':
          final content = msg.content ?? '';
          final truncated = content.length > 500
              ? '${content.substring(0, 500)}...[truncated]'
              : content;
          buffer.writeln('Tool result (${msg.name}): $truncated');
        case 'system':
          // Skip system messages in summary (they'll be re-injected)
          break;
      }
    }

    return buffer.toString();
  }

  /// Estimates total tokens in a message list (rough: 4 chars/token).
  int _estimateTotalTokens(List<LlmMessage> messages) {
    var total = 0;
    for (final msg in messages) {
      total += _estimateTokens(msg.content ?? '');
      if (msg.toolCalls != null) {
        for (final tc in msg.toolCalls!) {
          total += _estimateTokens(tc.name) + 10;
          total += _estimateTokens(tc.arguments.toString());
        }
      }
    }
    return total;
  }

  int _estimateTokens(String text) {
    if (text.isEmpty) return 0;
    return (text.length + 3) ~/ 4;
  }
}
