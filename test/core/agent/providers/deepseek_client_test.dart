import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nudgee/core/agent/providers/deepseek_client.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';

/// A mock HTTP client that can return either regular Responses or StreamedResponses.
class MockStreamClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest) _handler;

  MockStreamClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _handler(request);
}

/// Creates a mock client that returns a streamed SSE response.
http.Client mockSseClient(String sseData, {int statusCode = 200}) {
  return MockStreamClient((request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(sseData)),
      statusCode,
      headers: {'content-type': 'text/event-stream'},
    );
  });
}

/// Creates a mock client that returns a regular JSON response.
http.Client mockJsonClient(String jsonBody, {int statusCode = 200}) {
  return MockStreamClient((request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonBody)),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  });
}

void main() {
  group('DeepSeekClient', () {
    test('availableModels returns deepseek models', () {
      final client = DeepSeekClient(apiKey: 'test-key');
      final models = client.availableModels();
      expect(models, contains('deepseek-chat'));
      expect(models, contains('deepseek-reasoner'));
      client.dispose();
    });

    test('chat sends correct request body', () async {
      final mockClient = MockStreamClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), contains('chat/completions'));
        expect(request.headers['Authorization'], 'Bearer test-key');
        expect(request.headers['Content-Type'], 'application/json');

        final reqBody = (request as http.Request).body;
        final body = jsonDecode(reqBody) as Map<String, dynamic>;
        expect(body['model'], 'deepseek-chat');
        expect(body['stream'], false);
        expect(body['messages'], isA<List>());

        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'id': 'chatcmpl-123',
            'choices': [
              {
                'index': 0,
                'message': {
                  'role': 'assistant',
                  'content': 'Hello!',
                },
                'finish_reason': 'stop',
              }
            ],
            'usage': {
              'prompt_tokens': 10,
              'completion_tokens': 5,
            },
          }))),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = DeepSeekClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final response = await client.chat(
        messages: [const LlmMessage.user('Hi')],
        systemPrompt: 'You are helpful.',
      );

      expect(response.content, 'Hello!');
      expect(response.toolCalls, isEmpty);
      expect(response.finishReason, 'stop');
      expect(response.usage?.inputTokens, 10);
      expect(response.usage?.outputTokens, 5);
      client.dispose();
    });

    test('chat parses tool calls from response', () async {
      final mockClient = mockJsonClient(jsonEncode({
        'id': 'chatcmpl-456',
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'content': null,
              'tool_calls': [
                {
                  'id': 'call_abc',
                  'type': 'function',
                  'function': {
                    'name': 'echo',
                    'arguments': '{"message":"hello"}',
                  },
                }
              ],
            },
            'finish_reason': 'tool_calls',
          }
        ],
        'usage': {
          'prompt_tokens': 20,
          'completion_tokens': 10,
        },
      }));

      final client = DeepSeekClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final response = await client.chat(
        messages: [const LlmMessage.user('Echo hello')],
        tools: [
          const LlmToolDefinition(
            name: 'echo',
            description: 'Echo tool',
            parametersSchema: {'type': 'object'},
          ),
        ],
      );

      expect(response.hasToolCalls, true);
      expect(response.toolCalls, hasLength(1));
      expect(response.toolCalls[0].id, 'call_abc');
      expect(response.toolCalls[0].name, 'echo');
      expect(response.toolCalls[0].arguments['message'], 'hello');
      expect(response.finishReason, 'tool_calls');
      client.dispose();
    });

    test('chat parses reasoning_content from DeepSeek-reasoner', () async {
      final mockClient = mockJsonClient(jsonEncode({
        'id': 'chatcmpl-789',
        'choices': [
          {
            'index': 0,
            'message': {
              'role': 'assistant',
              'content': 'The answer is 42.',
              'reasoning_content': 'Let me think about this...',
            },
            'finish_reason': 'stop',
          }
        ],
        'usage': {
          'prompt_tokens': 10,
          'completion_tokens': 50,
          'completion_tokens_details': {
            'reasoning_tokens': 30,
          },
        },
      }));

      final client = DeepSeekClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final response = await client.chat(
        messages: [const LlmMessage.user('What is the answer?')],
        model: 'deepseek-reasoner',
      );

      expect(response.content, 'The answer is 42.');
      expect(response.thinking, 'Let me think about this...');
      expect(response.usage?.thinkingTokens, 30);
      expect(response.usage?.outputTokens, 20);  // 50 - 30
      client.dispose();
    });

    test('chat throws LlmException on non-200 response', () async {
      final mockClient = mockJsonClient('{"error": "Invalid API key"}', statusCode: 401);

      final client = DeepSeekClient(
        apiKey: 'bad-key',
        httpClient: mockClient,
      );

      expect(
        () => client.chat(messages: [const LlmMessage.user('Hi')]),
        throwsA(isA<LlmException>()),
      );

      client.dispose();
    });

    test('streamChat yields content chunks from SSE', () async {
      final sseData = [
        'data: {"choices":[{"delta":{"content":"Hello"}}]}',
        '',
        'data: {"choices":[{"delta":{"content":" world"}}]}',
        '',
        'data: {"choices":[{"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":5,"completion_tokens":10}}',
        '',
        'data: [DONE]',
        '',
      ].join('\n');

      final mockClient = mockSseClient(sseData);

      final client = DeepSeekClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final chunks = <LlmChunk>[];
      await for (final chunk in client.streamChat(
        messages: [const LlmMessage.user('Hi')],
      )) {
        chunks.add(chunk);
      }

      // Should have content chunks + done chunk
      final contentChunks = chunks.where((c) => c.hasContent).toList();
      expect(contentChunks, hasLength(2));
      expect(contentChunks[0].contentDelta, 'Hello');
      expect(contentChunks[1].contentDelta, ' world');

      final doneChunks = chunks.where((c) => c.isDone).toList();
      expect(doneChunks, hasLength(1));
      expect(doneChunks.first.usage?.inputTokens, 5);
      expect(doneChunks.first.usage?.outputTokens, 10);

      client.dispose();
    });

    test('streamChat yields thinking chunks for reasoning content', () async {
      final sseData = [
        'data: {"choices":[{"delta":{"reasoning_content":"Thinking..."}}]}',
        '',
        'data: {"choices":[{"delta":{"content":"Answer"}}]}',
        '',
        'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}',
        '',
        'data: [DONE]',
        '',
      ].join('\n');

      final mockClient = mockSseClient(sseData);

      final client = DeepSeekClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final chunks = <LlmChunk>[];
      await for (final chunk in client.streamChat(
        messages: [const LlmMessage.user('Think and answer')],
      )) {
        chunks.add(chunk);
      }

      final thinkingChunks = chunks.where((c) => c.hasThinking).toList();
      expect(thinkingChunks, hasLength(1));
      expect(thinkingChunks.first.thinkingDelta, 'Thinking...');

      final contentChunks = chunks.where((c) => c.hasContent).toList();
      expect(contentChunks, hasLength(1));
      expect(contentChunks.first.contentDelta, 'Answer');

      client.dispose();
    });

    test('streamChat throws LlmException on error response', () async {
      final mockClient = mockSseClient('error', statusCode: 500);

      final client = DeepSeekClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      expect(
        () => client.streamChat(messages: [const LlmMessage.user('Hi')]).toList(),
        throwsA(isA<LlmException>()),
      );

      client.dispose();
    });

    test('builds messages with system prompt prepended', () async {
      String? capturedBody;

      final mockClient = MockStreamClient((request) async {
        if (request is http.Request) capturedBody = request.body;
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'id': 'test',
            'choices': [
              {
                'index': 0,
                'message': {'role': 'assistant', 'content': 'OK'},
                'finish_reason': 'stop',
              }
            ],
            'usage': {'prompt_tokens': 5, 'completion_tokens': 2},
          }))),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = DeepSeekClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      await client.chat(
        messages: [
          const LlmMessage.user('Hello'),
          const LlmMessage.assistant(text: 'Hi'),
          const LlmMessage.user('Bye'),
        ],
        systemPrompt: 'You are a test bot.',
      );

      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      final messages = body['messages'] as List;

      // System prompt should be first
      expect(messages[0]['role'], 'system');
      expect(messages[0]['content'], 'You are a test bot.');

      // Then the conversation
      expect(messages[1]['role'], 'user');
      expect(messages[2]['role'], 'assistant');
      expect(messages[3]['role'], 'user');

      client.dispose();
    });

    test('includes tools in request when provided', () async {
      String? capturedBody;

      final mockClient = MockStreamClient((request) async {
        if (request is http.Request) capturedBody = request.body;
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'id': 'test',
            'choices': [
              {
                'index': 0,
                'message': {'role': 'assistant', 'content': 'OK'},
                'finish_reason': 'stop',
              }
            ],
            'usage': {'prompt_tokens': 5, 'completion_tokens': 2},
          }))),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = DeepSeekClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      await client.chat(
        messages: [const LlmMessage.user('Hi')],
        tools: [
          const LlmToolDefinition(
            name: 'echo',
            description: 'Echo',
            parametersSchema: {'type': 'object'},
          ),
        ],
      );

      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body['tools'], isA<List>());
      expect(body['tools'][0]['type'], 'function');
      expect(body['tools'][0]['function']['name'], 'echo');

      client.dispose();
    });

    test('includes temperature and maxTokens when provided', () async {
      String? capturedBody;

      final mockClient = MockStreamClient((request) async {
        if (request is http.Request) capturedBody = request.body;
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'id': 'test',
            'choices': [
              {
                'index': 0,
                'message': {'role': 'assistant', 'content': 'OK'},
                'finish_reason': 'stop',
              }
            ],
            'usage': {'prompt_tokens': 5, 'completion_tokens': 2},
          }))),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = DeepSeekClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      await client.chat(
        messages: [const LlmMessage.user('Hi')],
        temperature: 0.3,
        maxTokens: 1024,
      );

      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body['temperature'], 0.3);
      expect(body['max_tokens'], 1024);

      client.dispose();
    });
  });
}
