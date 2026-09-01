import 'package:nudgee/core/agent/providers/llm_client.dart';

/// Microcompact — local, no-LLM context compression.
///
/// When tool results dominate the context, old tool results are elided
/// (replaced with a placeholder) to save tokens. Only the most recent
/// [keepLastNResults] tool results are kept in full.
///
/// This is the first level of LingAgent's two-tier compaction strategy:
/// - Level 1 (this): Microcompact — local, fast, zero cost
/// - Level 2: Autocompact — LLM-based summarization (Phase 3)
class Microcompact {
  /// Number of recent tool results to keep in full.
  static const int keepLastNResults = 3;

  /// Token threshold above which old tool results get elided.
  static const int toolResultTokenThreshold = 40000;

  /// Minimum tokens that must be saved to bother eliding.
  static const int minTokensToSave = 20000;

  /// Placeholder text for elided tool results.
  static const String elidedPlaceholder =
      '[Old tool result elided to save context]';

  /// Estimated tokens per character (rough: 4 chars/token).
  static const int charsPerToken = 4;

  /// Runs microcompact on [messages].
  ///
  /// Returns the input unchanged if no compression is needed.
  /// Otherwise returns a new list with old tool results elided.
  List<LlmMessage> compact(List<LlmMessage> messages) {
    // Collect tool result messages
    final toolResultIndices = <int>[];
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].role == 'tool') {
        toolResultIndices.add(i);
      }
    }

    if (toolResultIndices.length <= keepLastNResults) {
      return messages;  // Not enough to elide
    }

    // Estimate total tokens in tool results
    final totalToolTokens = toolResultIndices
        .map((i) => _estimateTokens(messages[i].content ?? ''))
        .fold(0, (a, b) => a + b);

    if (totalToolTokens < toolResultTokenThreshold) {
      return messages;  // Not worth eliding
    }

    // Indices to elide (all except the last keepLastNResults)
    final toElide = toolResultIndices
        .take(toolResultIndices.length - keepLastNResults)
        .toSet();

    final tokensSaved = toElide
        .map((i) => _estimateTokens(messages[i].content ?? ''))
        .fold(0, (a, b) => a + b);

    if (tokensSaved < minTokensToSave) {
      return messages;  // Not enough savings
    }

    // Elide old tool results
    return messages.asMap().entries.map((entry) {
      if (toElide.contains(entry.key)) {
        final msg = entry.value;
        return LlmMessage.tool(
          toolCallId: msg.toolCallId ?? '',
          name: msg.name ?? 'unknown',
          content: elidedPlaceholder,
          isError: msg.isError ?? false,
        );
      }
      return entry.value;
    }).toList();
  }

  /// Estimates token count for a string (rough: 4 chars/token).
  int _estimateTokens(String text) {
    if (text.isEmpty) return 0;
    return (text.length + charsPerToken - 1) ~/ charsPerToken;
  }

  /// Estimates total tokens in a message list.
  int estimateTotalTokens(List<LlmMessage> messages) {
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
}
