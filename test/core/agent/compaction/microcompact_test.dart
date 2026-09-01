import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/compaction/microcompact.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';

void main() {
  late Microcompact microcompact;

  setUp(() {
    microcompact = Microcompact();
  });

  group('Microcompact.compact', () {
    test('returns messages unchanged when few tool results', () {
      final messages = [
        const LlmMessage.user('Hello'),
        const LlmMessage.assistant(text: 'Let me check.'),
        const LlmMessage.assistant(toolCalls: [
          ToolCall(id: 'tc1', name: 'echo', arguments: {}),
        ]),
        const LlmMessage.tool(toolCallId: 'tc1', name: 'echo', content: 'hi'),
        const LlmMessage.assistant(text: 'Done!'),
      ];

      final result = microcompact.compact(messages);
      expect(result, equals(messages));
    });

    test('returns messages unchanged when tool results are small', () {
      // Many tool results but each is tiny
      final messages = <LlmMessage>[
        const LlmMessage.user('Hello'),
      ];
      for (var i = 0; i < 10; i++) {
        messages.add(LlmMessage.assistant(toolCalls: [
          ToolCall(id: 'tc$i', name: 'echo', arguments: {}),
        ]));
        messages.add(LlmMessage.tool(
          toolCallId: 'tc$i',
          name: 'echo',
          content: 'r$i',  // Very short
        ));
      }

      final result = microcompact.compact(messages);
      // Should not elide because total tokens < threshold
      expect(result, equals(messages));
    });

    test('elides old tool results when threshold exceeded', () {
      // Create many large tool results
      final messages = <LlmMessage>[
        const LlmMessage.user('Process all this data'),
      ];

      // Add 10 tool results, each ~5000 chars (~1250 tokens)
      for (var i = 0; i < 10; i++) {
        messages.add(LlmMessage.assistant(toolCalls: [
          ToolCall(id: 'tc$i', name: 'fetch', arguments: {}),
        ]));
        messages.add(LlmMessage.tool(
          toolCallId: 'tc$i',
          name: 'fetch',
          content: 'X' * 5000,  // ~1250 tokens each
        ));
      }

      // Total tool tokens: ~12500, which is < 40000 threshold
      // Need more to trigger eliding
      // Let's add 40 more
      for (var i = 10; i < 50; i++) {
        messages.add(LlmMessage.assistant(toolCalls: [
          ToolCall(id: 'tc$i', name: 'fetch', arguments: {}),
        ]));
        messages.add(LlmMessage.tool(
          toolCallId: 'tc$i',
          name: 'fetch',
          content: 'X' * 5000,
        ));
      }

      final result = microcompact.compact(messages);

      // The last 3 tool results should be kept in full
      // The rest should be elided
      final toolMessages = result.where((m) => m.role == 'tool').toList();
      expect(toolMessages, hasLength(50));

      // Last 3 should have original content
      final last3 = toolMessages.skip(47).toList();
      for (final m in last3) {
        expect(m.content, isNot(Microcompact.elidedPlaceholder));
        expect(m.content!.length, 5000);
      }

      // Earlier ones should be elided
      final earlier = toolMessages.take(47).toList();
      for (final m in earlier) {
        expect(m.content, Microcompact.elidedPlaceholder);
      }
    });

    test('elided placeholder is short', () {
      expect(Microcompact.elidedPlaceholder.length, lessThan(100));
    });
  });

  group('Microcompact.estimateTotalTokens', () {
    test('returns 0 for empty list', () {
      expect(microcompact.estimateTotalTokens([]), 0);
    });

    test('estimates tokens for text content', () {
      final messages = [
        const LlmMessage.user('Hello world'),  // 11 chars ≈ 3 tokens
      ];
      final tokens = microcompact.estimateTotalTokens(messages);
      expect(tokens, greaterThan(0));
      expect(tokens, lessThan(10));  // Rough estimate
    });

    test('includes tool call tokens', () {
      final messages = [
        const LlmMessage.assistant(toolCalls: [
          ToolCall(id: 'tc1', name: 'search', arguments: {'q': 'test'}),
        ]),
      ];
      final tokens = microcompact.estimateTotalTokens(messages);
      expect(tokens, greaterThan(0));
    });

    test('handles empty content', () {
      final messages = [
        const LlmMessage.assistant(text: ''),
      ];
      expect(microcompact.estimateTotalTokens(messages), 0);
    });
  });
}
