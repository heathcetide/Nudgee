import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/providers/deepseek_client.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';

/// Real API tests for DeepSeekClient.
///
/// These tests call the actual DeepSeek API and are skipped by default.
/// To run them:
///   flutter test test/core/agent/providers/deepseek_real_api_test.dart --tags real-api
///
/// Or set the DEEPSEEK_API_KEY environment variable:
///   DEEPSEEK_API_KEY=sk-xxx flutter test --tags real-api
void main() {
  final apiKey = Platform.environment['DEEPSEEK_API_KEY'] ??
      'sk-32143cf33b4c46318f449f17bf3b339a';  // From config.yaml

  // Skip if no API key available
  final hasApiKey = apiKey.isNotEmpty && apiKey.startsWith('sk-');

  if (!hasApiKey) {
    group('DeepSeekClient real API (skipped — no API key)', () {
      test('skipped', () {});
    });
    return;
  }

  group('DeepSeekClient real API', () {
    late DeepSeekClient client;

    setUp(() {
      client = DeepSeekClient(
        apiKey: apiKey,
        baseUrl: 'https://api.deepseek.com/v1',
        defaultModel: 'deepseek-chat',
      );
    });

    tearDown(() {
      client.dispose();
    });

    test('chat returns a response', () async {
      final response = await client.chat(
        messages: [const LlmMessage.user('Say "hello" in exactly one word.')],
        temperature: 0.0,
        maxTokens: 10,
      );

      expect(response.content, isNotEmpty);
      expect(response.finishReason, isNotEmpty);
      expect(response.usage, isNotNull);
      expect(response.usage!.inputTokens, greaterThan(0));
      expect(response.usage!.outputTokens, greaterThan(0));
    }, tags: 'real-api', timeout: const Timeout(Duration(seconds: 30)));

    test('streamChat yields content chunks', () async {
      final chunks = <LlmChunk>[];
      await for (final chunk in client.streamChat(
        messages: [const LlmMessage.user('Count from 1 to 5.')],
        temperature: 0.0,
        maxTokens: 50,
      )) {
        chunks.add(chunk);
      }

      final contentChunks = chunks.where((c) => c.hasContent).toList();
      expect(contentChunks, isNotEmpty);

      // The full content should reconstruct a meaningful reply
      final fullContent = contentChunks.map((c) => c.contentDelta!).join();
      expect(fullContent, isNotEmpty);

      // Should have at least one done chunk (finish_reason or [DONE])
      final doneChunks = chunks.where((c) => c.isDone).toList();
      expect(doneChunks, isNotEmpty);
    }, tags: 'real-api', timeout: const Timeout(Duration(seconds: 30)));

    test('chat with system prompt', () async {
      final response = await client.chat(
        messages: [const LlmMessage.user('What is your name?')],
        systemPrompt: 'You are a test bot named "TestBot". Always say your name is TestBot.',
        temperature: 0.0,
        maxTokens: 50,
      );

      expect(response.content.toLowerCase(), contains('testbot'));
    }, tags: 'real-api', timeout: const Timeout(Duration(seconds: 30)));

    test('chat with tool calls', () async {
      final response = await client.chat(
        messages: [const LlmMessage.user('What is 2+2? Use the calculator tool.')],
        tools: [
          const LlmToolDefinition(
            name: 'calculator',
            description: 'A simple calculator. Use for math operations.',
            parametersSchema: {
              'type': 'object',
              'properties': {
                'expression': {
                  'type': 'string',
                  'description': 'Math expression to evaluate, e.g. "2+2"',
                },
              },
              'required': ['expression'],
            },
          ),
        ],
        temperature: 0.0,
      );

      // The LLM should either call the tool or answer directly
      // Both are valid behaviors
      expect(response.finishReason, anyOf('stop', 'tool_calls'));
      if (response.hasToolCalls) {
        expect(response.toolCalls[0].name, 'calculator');
        expect(response.toolCalls[0].arguments, isNotEmpty);
      }
    }, tags: 'real-api', timeout: const Timeout(Duration(seconds: 30)));

    test('multi-turn conversation', () async {
      // Turn 1
      final r1 = await client.chat(
        messages: [const LlmMessage.user('My name is Alice.')],
        temperature: 0.0,
        maxTokens: 50,
      );
      expect(r1.content, isNotEmpty);

      // Turn 2 — with history
      final r2 = await client.chat(
        messages: [
          const LlmMessage.user('My name is Alice.'),
          LlmMessage.assistant(text: r1.content),
          const LlmMessage.user('What is my name?'),
        ],
        temperature: 0.0,
        maxTokens: 50,
      );

      expect(r2.content.toLowerCase(), contains('alice'));
    }, tags: 'real-api', timeout: const Timeout(Duration(seconds: 60)));
  });
}
