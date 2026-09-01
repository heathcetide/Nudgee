import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';
import 'package:nudgee/core/agent/sanitize/message_sanitizer.dart';

void main() {
  late MessageSanitizer sanitizer;

  setUp(() {
    sanitizer = MessageSanitizer();
  });

  group('MessageSanitizer.clean', () {
    test('returns clean conversation unchanged', () {
      final messages = [
        const LlmMessage.user('Hello'),
        const LlmMessage.assistant(text: 'Hi there!'),
        const LlmMessage.user('Bye'),
      ];

      final result = sanitizer.sanitize(messages);
      expect(result, equals(messages));
    });

    test('returns empty list unchanged', () {
      final result = sanitizer.sanitize([]);
      expect(result, isEmpty);
    });
  });

  group('MessageSanitizer.empty content', () {
    test('fills empty assistant content with placeholder', () {
      final messages = [
        const LlmMessage.user('Hello'),
        const LlmMessage.assistant(text: ''),
        const LlmMessage.user('Continue'),
      ];

      final result = sanitizer.sanitize(messages);

      // The empty assistant message should be filled
      expect(result[1].content, MessageSanitizer.emptyContentPlaceholder);
    });

    test('fills null assistant content with placeholder', () {
      final messages = [
        const LlmMessage.user('Hello'),
        const LlmMessage.assistant(text: null),
        const LlmMessage.user('Continue'),
      ];

      final result = sanitizer.sanitize(messages);

      expect(result[1].content, MessageSanitizer.emptyContentPlaceholder);
    });

    test('does not fill assistant with tool calls but no text', () {
      // An assistant message with tool calls but no text is valid
      final messages = [
        const LlmMessage.user('Hello'),
        const LlmMessage.assistant(toolCalls: [
          ToolCall(id: 'tc1', name: 'echo', arguments: {}),
        ]),
        const LlmMessage.tool(toolCallId: 'tc1', name: 'echo', content: 'hi'),
      ];

      final result = sanitizer.sanitize(messages);
      // Should not need sanitizing — tool calls are present
      expect(result[1].content, isNot(MessageSanitizer.emptyContentPlaceholder));
    });
  });

  group('MessageSanitizer.orphan tool calls', () {
    test('inserts synthetic tool result for orphan tool call', () {
      final messages = [
        const LlmMessage.user('Hello'),
        const LlmMessage.assistant(toolCalls: [
          ToolCall(id: 'tc_orphan', name: 'echo', arguments: {}),
        ]),
        // Missing tool result for tc_orphan
        const LlmMessage.user('What happened?'),
      ];

      final result = sanitizer.sanitize(messages);

      // Should have inserted a tool result after the assistant message
      // Find the tool result message
      final toolResults = result.where((m) => m.role == 'tool').toList();
      expect(toolResults, hasLength(1));
      expect(toolResults[0].toolCallId, 'tc_orphan');
      expect(toolResults[0].isError, true);
      expect(toolResults[0].content, MessageSanitizer.abandonedToolPlaceholder);
    });

    test('handles multiple orphan tool calls', () {
      final messages = [
        const LlmMessage.user('Hello'),
        const LlmMessage.assistant(toolCalls: [
          ToolCall(id: 'tc1', name: 'echo', arguments: {}),
          ToolCall(id: 'tc2', name: 'search', arguments: {}),
        ]),
        // No tool results at all
        const LlmMessage.user('Continue'),
      ];

      final result = sanitizer.sanitize(messages);

      final toolResults = result.where((m) => m.role == 'tool').toList();
      expect(toolResults, hasLength(2));
    });

    test('does not insert synthetic result when tool result exists', () {
      final messages = [
        const LlmMessage.user('Hello'),
        const LlmMessage.assistant(toolCalls: [
          ToolCall(id: 'tc1', name: 'echo', arguments: {}),
        ]),
        const LlmMessage.tool(toolCallId: 'tc1', name: 'echo', content: 'hi'),
        const LlmMessage.user('Thanks!'),
      ];

      final result = sanitizer.sanitize(messages);

      final toolResults = result.where((m) => m.role == 'tool').toList();
      expect(toolResults, hasLength(1));  // Only the original
    });
  });

  group('MessageSanitizer.consecutive same role', () {
    test('merges consecutive user messages', () {
      final messages = [
        const LlmMessage.user('Hello'),
        const LlmMessage.user('How are you?'),
        const LlmMessage.assistant(text: 'I am fine.'),
      ];

      final result = sanitizer.sanitize(messages);

      // The two user messages should be merged
      expect(result, hasLength(2));
      expect(result[0].role, 'user');
      expect(result[0].content, contains('Hello'));
      expect(result[0].content, contains('How are you?'));
      expect(result[1].role, 'assistant');
    });

    test('merges consecutive assistant messages', () {
      final messages = [
        const LlmMessage.user('Hello'),
        const LlmMessage.assistant(text: 'Hi'),
        const LlmMessage.assistant(text: ' there!'),
      ];

      final result = sanitizer.sanitize(messages);

      expect(result, hasLength(2));
      expect(result[1].role, 'assistant');
      expect(result[1].content, contains('Hi'));
      expect(result[1].content, contains('there!'));
    });

    test('does not merge consecutive tool messages', () {
      // Multiple tool results in a row are valid (one per tool call)
      final messages = [
        const LlmMessage.assistant(toolCalls: [
          ToolCall(id: 'tc1', name: 'echo', arguments: {}),
          ToolCall(id: 'tc2', name: 'search', arguments: {}),
        ]),
        const LlmMessage.tool(toolCallId: 'tc1', name: 'echo', content: 'r1'),
        const LlmMessage.tool(toolCallId: 'tc2', name: 'search', content: 'r2'),
      ];

      final result = sanitizer.sanitize(messages);

      // Tool messages should NOT be merged
      final toolMessages = result.where((m) => m.role == 'tool').toList();
      expect(toolMessages, hasLength(2));
    });
  });

  group('MessageSanitizer.needsSanitize', () {
    test('returns false for clean conversation', () {
      final messages = [
        const LlmMessage.user('Hello'),
        const LlmMessage.assistant(text: 'Hi!'),
      ];
      expect(sanitizer.needsSanitize(messages), false);
    });

    test('returns true for empty assistant content', () {
      final messages = [
        const LlmMessage.user('Hello'),
        const LlmMessage.assistant(text: ''),
      ];
      expect(sanitizer.needsSanitize(messages), true);
    });

    test('returns true for orphan tool call', () {
      final messages = [
        const LlmMessage.user('Hello'),
        const LlmMessage.assistant(toolCalls: [
          ToolCall(id: 'tc1', name: 'echo', arguments: {}),
        ]),
      ];
      expect(sanitizer.needsSanitize(messages), true);
    });

    test('returns true for consecutive same role', () {
      final messages = [
        const LlmMessage.user('Hello'),
        const LlmMessage.user('Again'),
      ];
      expect(sanitizer.needsSanitize(messages), true);
    });

    test('returns false for empty list', () {
      expect(sanitizer.needsSanitize([]), false);
    });
  });
}
