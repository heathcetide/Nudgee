import 'dart:async';

import 'package:nudgee/core/agent/agent_event.dart';
import 'package:nudgee/core/agent/providers/deepseek_client.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';

/// Mock LLM client for testing — returns pre-programmed responses.
///
/// Usage:
/// ```dart
/// final mock = MockLLMClient();
/// mock.enqueueContent('Hello!');
/// mock.enqueueToolCalls([ToolCall(id: '1', name: 'echo', arguments: {})]]);
/// mock.enqueueContent('Done!');
///
/// final harness = AgentHarness(llmClient: mock, ...);
/// ```
class MockLLMClient implements LLMClient {
  final List<_MockResponse> _queue = [];
  final List<_MockRequest> _requests = [];

  /// Enqueues a simple text response (streaming).
  void enqueueContent(String text) {
    _queue.add(_MockResponse(content: text));
  }

  /// Enqueues a tool call response (non-streaming).
  void enqueueToolCalls(List<ToolCall> toolCalls, {String content = ''}) {
    _queue.add(_MockResponse(toolCalls: toolCalls, content: content));
  }

  /// Enqueues a thinking + content response.
  void enqueueThinking(String thinking, String content) {
    _queue.add(_MockResponse(thinking: thinking, content: content));
  }

  /// Enqueues an error.
  void enqueueError(String message) {
    _queue.add(_MockResponse(error: message));
  }

  /// All requests made to this client (for assertions).
  List<_MockRequest> get requests => List.unmodifiable(_requests);

  /// Clears the request log.
  void clearRequests() {
    _requests.clear();
  }

  @override
  Stream<LlmChunk> streamChat({
    required List<LlmMessage> messages,
    String? model,
    double? temperature,
    int? maxTokens,
    List<LlmToolDefinition>? tools,
    String? systemPrompt,
  }) async* {
    _requests.add(_MockRequest(
      messages: messages,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      tools: tools,
      systemPrompt: systemPrompt,
      streaming: true,
    ));

    if (_queue.isEmpty) {
      yield const LlmChunk(isDone: true, finishReason: 'stop');
      return;
    }

    final response = _queue.removeAt(0);

    if (response.error != null) {
      throw LlmException(response.error!);
    }

    // Stream thinking
    if (response.thinking != null) {
      yield LlmChunk(thinkingDelta: response.thinking);
    }

    // Stream content
    if (response.content != null) {
      yield LlmChunk(contentDelta: response.content);
    }

    // Done
    yield LlmChunk(
      isDone: true,
      finishReason: 'stop',
      usage: LlmUsage(
        inputTokens: 100,
        outputTokens: response.content?.length ?? 0,
      ),
    );
  }

  @override
  Future<LlmCompleteResponse> chat({
    required List<LlmMessage> messages,
    String? model,
    double? temperature,
    int? maxTokens,
    List<LlmToolDefinition>? tools,
    String? systemPrompt,
  }) async {
    _requests.add(_MockRequest(
      messages: messages,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      tools: tools,
      systemPrompt: systemPrompt,
      streaming: false,
    ));

    if (_queue.isEmpty) {
      return const LlmCompleteResponse(
        content: '',
        toolCalls: [],
        finishReason: 'stop',
      );
    }

    final response = _queue.removeAt(0);

    if (response.error != null) {
      throw LlmException(response.error!);
    }

    return LlmCompleteResponse(
      content: response.content ?? '',
      thinking: response.thinking,
      toolCalls: response.toolCalls ?? [],
      finishReason: response.toolCalls != null ? 'tool_calls' : 'stop',
      usage: LlmUsage(
        inputTokens: 100,
        outputTokens: (response.content?.length ?? 0) + 50,
      ),
    );
  }

  @override
  List<String> availableModels() => const ['mock-model'];

  @override
  Future<List<String>> fetchModels() async => const ['mock-model'];

  @override
  void dispose() {}
}

class _MockResponse {
  final String? content;
  final String? thinking;
  final List<ToolCall>? toolCalls;
  final String? error;

  _MockResponse({this.content, this.thinking, this.toolCalls, this.error});
}

class _MockRequest {
  final List<LlmMessage> messages;
  final String? model;
  final double? temperature;
  final int? maxTokens;
  final List<LlmToolDefinition>? tools;
  final String? systemPrompt;
  final bool streaming;

  _MockRequest({
    required this.messages,
    this.model,
    this.temperature,
    this.maxTokens,
    this.tools,
    this.systemPrompt,
    required this.streaming,
  });
}
