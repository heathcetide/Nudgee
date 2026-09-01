import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';

void main() {
  group('LlmMessage', () {
    test('system message', () {
      const msg = LlmMessage.system('You are helpful.');
      expect(msg.role, 'system');
      expect(msg.content, 'You are helpful.');
      expect(msg.toolCalls, isNull);
      expect(msg.toolCallId, isNull);
    });

    test('user message', () {
      const msg = LlmMessage.user('Hello!');
      expect(msg.role, 'user');
      expect(msg.content, 'Hello!');
      expect(msg.toolCalls, isNull);
    });

    test('assistant message with text only', () {
      const msg = LlmMessage.assistant(text: 'Hi there!');
      expect(msg.role, 'assistant');
      expect(msg.content, 'Hi there!');
      expect(msg.toolCalls, isNull);
    });

    test('assistant message with tool calls', () {
      const calls = [
        ToolCall(id: 'tc1', name: 'echo', arguments: {'msg': 'hi'}),
      ];
      const msg = LlmMessage.assistant(toolCalls: calls);
      expect(msg.role, 'assistant');
      expect(msg.content, isNull);
      expect(msg.toolCalls, hasLength(1));
      expect(msg.toolCalls![0].name, 'echo');
    });

    test('tool result message', () {
      const msg = LlmMessage.tool(
        toolCallId: 'tc1',
        name: 'echo',
        content: 'Echo: hi',
      );
      expect(msg.role, 'tool');
      expect(msg.toolCallId, 'tc1');
      expect(msg.name, 'echo');
      expect(msg.content, 'Echo: hi');
      expect(msg.isError, false);
    });

    test('tool result message with error', () {
      const msg = LlmMessage.tool(
        toolCallId: 'tc2',
        name: 'fail',
        content: 'Error occurred',
        isError: true,
      );
      expect(msg.isError, true);
    });

    test('toString contains role', () {
      const msg = LlmMessage.user('test');
      expect(msg.toString(), contains('user'));
    });

    test('toString truncates long content', () {
      final longText = 'A' * 100;
      final msg = LlmMessage.user(longText);
      final str = msg.toString();
      expect(str, contains('...'));
      expect(str.length, lessThan(100));
    });

    test('toString shows tool call names', () {
      const msg = LlmMessage.assistant(toolCalls: [
        ToolCall(id: '1', name: 'tool_a', arguments: {}),
        ToolCall(id: '2', name: 'tool_b', arguments: {}),
      ]);
      final str = msg.toString();
      expect(str, contains('tool_a'));
      expect(str, contains('tool_b'));
    });
  });

  group('LlmToolDefinition', () {
    test('creates with required fields', () {
      const def = LlmToolDefinition(
        name: 'echo',
        description: 'Echo tool',
        parametersSchema: {'type': 'object'},
      );
      expect(def.name, 'echo');
      expect(def.description, 'Echo tool');
      expect(def.parametersSchema, {'type': 'object'});
    });

    test('toOpenAIJson produces correct format', () {
      const def = LlmToolDefinition(
        name: 'search',
        description: 'Search the web',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
          },
        },
      );
      final json = def.toOpenAIJson();

      expect(json['type'], 'function');
      expect(json['function']['name'], 'search');
      expect(json['function']['description'], 'Search the web');
      expect(json['function']['parameters']['type'], 'object');
    });
  });

  group('LlmChunk', () {
    test('thinking delta chunk', () {
      const chunk = LlmChunk(thinkingDelta: 'reasoning');
      expect(chunk.hasThinking, true);
      expect(chunk.hasContent, false);
      expect(chunk.hasToolCall, false);
      expect(chunk.isDone, false);
    });

    test('content delta chunk', () {
      const chunk = LlmChunk(contentDelta: 'reply');
      expect(chunk.hasThinking, false);
      expect(chunk.hasContent, true);
      expect(chunk.hasToolCall, false);
    });

    test('tool call delta chunk', () {
      const chunk = LlmChunk(
        toolCallDelta: LlmToolCallDelta(index: 0, name: 'echo'),
      );
      expect(chunk.hasToolCall, true);
      expect(chunk.hasContent, false);
    });

    test('done chunk', () {
      const chunk = LlmChunk(
        isDone: true,
        finishReason: 'stop',
        usage: LlmUsage(inputTokens: 10, outputTokens: 5),
      );
      expect(chunk.isDone, true);
      expect(chunk.finishReason, 'stop');
      expect(chunk.usage?.inputTokens, 10);
    });

    test('empty chunk', () {
      const chunk = LlmChunk();
      expect(chunk.hasThinking, false);
      expect(chunk.hasContent, false);
      expect(chunk.hasToolCall, false);
      expect(chunk.isDone, false);
    });
  });

  group('LlmUsage', () {
    test('creates with required fields', () {
      const usage = LlmUsage(inputTokens: 100, outputTokens: 50);
      expect(usage.inputTokens, 100);
      expect(usage.outputTokens, 50);
      expect(usage.thinkingTokens, 0);
      expect(usage.totalTokens, 150);
    });

    test('with thinking tokens', () {
      const usage = LlmUsage(
        inputTokens: 100,
        outputTokens: 50,
        thinkingTokens: 30,
      );
      expect(usage.totalTokens, 180);
    });

    test('fromJson parses OpenAI format', () {
      final json = {
        'prompt_tokens': 200,
        'completion_tokens': 100,
        'completion_tokens_details': {
          'reasoning_tokens': 40,
        },
      };
      final usage = LlmUsage.fromJson(json);
      expect(usage.inputTokens, 200);
      expect(usage.outputTokens, 60);  // 100 - 40
      expect(usage.thinkingTokens, 40);
      expect(usage.totalTokens, 300);
    });

    test('fromJson handles missing fields', () {
      final usage = LlmUsage.fromJson({});
      expect(usage.inputTokens, 0);
      expect(usage.outputTokens, 0);
      expect(usage.thinkingTokens, 0);
    });
  });

  group('LlmCompleteResponse', () {
    test('creates with all fields', () {
      const response = LlmCompleteResponse(
        content: 'Hello!',
        thinking: 'Let me think...',
        toolCalls: [
          ToolCall(id: '1', name: 'echo', arguments: {}),
        ],
        finishReason: 'tool_calls',
        usage: LlmUsage(inputTokens: 10, outputTokens: 5),
      );
      expect(response.content, 'Hello!');
      expect(response.thinking, 'Let me think...');
      expect(response.toolCalls, hasLength(1));
      expect(response.finishReason, 'tool_calls');
      expect(response.hasToolCalls, true);
    });

    test('hasToolCalls is false when empty', () {
      const response = LlmCompleteResponse(
        content: 'Done',
        toolCalls: [],
        finishReason: 'stop',
      );
      expect(response.hasToolCalls, false);
    });
  });

  group('LlmToolCallDelta', () {
    test('creates with all fields', () {
      const delta = LlmToolCallDelta(
        index: 1,
        id: 'call_abc',
        name: 'search',
        argumentsDelta: '{"query":',
      );
      expect(delta.index, 1);
      expect(delta.id, 'call_abc');
      expect(delta.name, 'search');
      expect(delta.argumentsDelta, '{"query":');
    });

    test('creates with minimal fields', () {
      const delta = LlmToolCallDelta(index: 0);
      expect(delta.index, 0);
      expect(delta.id, isNull);
      expect(delta.name, isNull);
      expect(delta.argumentsDelta, isNull);
    });
  });
}
