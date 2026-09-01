import 'package:nudgee/core/agent/providers/llm_client.dart';

/// Sanitizes conversation history to satisfy LLM API structural requirements.
///
/// Repairs three classes of corruption typically inherited from crashed or
/// interrupted sessions:
///
/// 1. **Empty content**: nil or empty content gets a placeholder text block
///    (the API rejects with "messages.<i>.content: Field required" otherwise).
/// 2. **Orphan tool_use**: every tool call must be answered by a tool result
///    in the immediately following message. Missing pairings get a synthetic
///    tool result with `isError=true`.
/// 3. **Consecutive same-role messages**: the API requires user/assistant
///    alternation, so runs of the same role are merged into one message.
///
/// Clean conversations return the input unchanged. Repaired ones get an
/// independent list; original messages are never mutated.
class MessageSanitizer {
  /// Placeholders inserted when a transcript is structurally broken.
  static const emptyContentPlaceholder =
      '[Empty assistant turn — content was not recorded]';
  static const abandonedToolPlaceholder =
      '[Tool call abandoned — no result was recorded; treat the call as unanswered]';

  /// Sanitizes [messages] in place (returns a new list, never mutates input).
  List<LlmMessage> sanitize(List<LlmMessage> messages) {
    if (!needsSanitize(messages)) return messages;

    var out = [...messages];

    // (1) Fill empty content
    out = _fillEmptyContent(out);

    // (2) Pair orphan tool calls with synthetic tool results
    out = _pairOrphanToolCalls(out);

    // (3) Merge consecutive same-role messages
    out = _mergeConsecutiveSameRole(out);

    return out;
  }

  /// Quick check — whether [messages] needs sanitizing.
  bool needsSanitize(List<LlmMessage> messages) {
    // Check for empty content
    for (final m in messages) {
      if (m.role == 'assistant' || m.role == 'user') {
        if ((m.content == null || m.content!.isEmpty) &&
            (m.toolCalls == null || m.toolCalls!.isEmpty)) {
          return true;
        }
      }
    }

    // Check for orphan tool calls
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].role != 'assistant') continue;
      if (messages[i].toolCalls == null) continue;
      for (final tc in messages[i].toolCalls!) {
        if (!_hasToolResultAnywhere(messages, i + 1, tc.id)) {
          return true;
        }
      }
    }

    // Check for consecutive same-role
    for (var i = 1; i < messages.length; i++) {
      if (messages[i].role == messages[i - 1].role &&
          messages[i].role != 'tool') {
        // tool messages can be consecutive (multiple tool results)
        return true;
      }
    }

    return false;
  }

  // ── Private ──────────────────────────────────────────────────────────

  List<LlmMessage> _fillEmptyContent(List<LlmMessage> messages) {
    return messages.map((m) {
      if ((m.role == 'assistant' || m.role == 'user') &&
          (m.content == null || m.content!.isEmpty) &&
          (m.toolCalls == null || m.toolCalls!.isEmpty)) {
        return LlmMessage(role: m.role, content: emptyContentPlaceholder);
      }
      return m;
    }).toList();
  }

  List<LlmMessage> _pairOrphanToolCalls(List<LlmMessage> messages) {
    var out = [...messages];

    for (var i = 0; i < out.length; i++) {
      if (out[i].role != 'assistant') continue;
      if (out[i].toolCalls == null) continue;

      final orphanIds = <String>[];
      for (final tc in out[i].toolCalls!) {
        if (!_hasToolResultAnywhere(out, i + 1, tc.id)) {
          orphanIds.add(tc.id);
        }
      }

      if (orphanIds.isEmpty) continue;

      // Insert synthetic tool results after position i
      final syntheticResults = orphanIds
          .map((id) => LlmMessage.tool(
                toolCallId: id,
                name: 'unknown',
                content: abandonedToolPlaceholder,
                isError: true,
              ))
          .toList();

      // Insert after position i
      out = [...out.sublist(0, i + 1), ...syntheticResults, ...out.sublist(i + 1)];
      // Skip past the inserted results
      i += syntheticResults.length;
    }

    return out;
  }

  List<LlmMessage> _mergeConsecutiveSameRole(List<LlmMessage> messages) {
    if (messages.isEmpty) return messages;

    final merged = <LlmMessage>[];
    for (final m in messages) {
      if (merged.isNotEmpty && merged.last.role == m.role && m.role != 'tool') {
        // Merge: concatenate content, combine tool calls
        final last = merged.last;
        final combinedContent = [
          if (last.content != null && last.content!.isNotEmpty) last.content!,
          if (m.content != null && m.content!.isNotEmpty) m.content!,
        ].join('\n');

        final combinedToolCalls = <dynamic>[
          if (last.toolCalls != null) ...last.toolCalls!,
          if (m.toolCalls != null) ...m.toolCalls!,
        ];

        merged[merged.length - 1] = LlmMessage(
          role: last.role,
          content: combinedContent.isEmpty ? null : combinedContent,
          toolCalls: combinedToolCalls.cast(),
        );
      } else {
        merged.add(m);
      }
    }

    return merged;
  }

  bool _hasToolResultAt(List<LlmMessage> messages, int index, String toolCallId) {
    if (index >= messages.length) return false;
    final msg = messages[index];
    return msg.role == 'tool' && msg.toolCallId == toolCallId;
  }

  /// Checks if a tool result for [toolCallId] exists anywhere from [startIndex] onwards.
  ///
  /// Multiple tool results can follow an assistant message (one per tool call),
  /// so we need to scan all subsequent tool messages, not just the one at [startIndex].
  bool _hasToolResultAnywhere(List<LlmMessage> messages, int startIndex, String toolCallId) {
    for (var i = startIndex; i < messages.length; i++) {
      final msg = messages[i];
      if (msg.role == 'tool' && msg.toolCallId == toolCallId) {
        return true;
      }
      if (msg.role != 'tool') break;  // Stop at first non-tool message
    }
    return false;
  }
}
