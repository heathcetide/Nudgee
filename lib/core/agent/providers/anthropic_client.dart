import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:nudgee/core/agent/providers/llm_client.dart';
import 'package:nudgee/core/agent/providers/openai_compatible_client.dart';

/// Anthropic (Claude) API client.
///
/// Anthropic uses a different API format from OpenAI:
/// - System prompt is a top-level field (not a message)
/// - Tool calls use a different format
/// - Streaming uses SSE with event types (content_block_start, etc.)
/// - max_tokens is required
///
/// Supports Claude 3.5 Sonnet, Claude 3 Opus, Claude 3 Haiku, and newer models.
///
/// Example:
/// ```dart
/// final client = AnthropicClient(
///   apiKey: 'sk-ant-...',
///   model: 'claude-3-5-sonnet-20241022',
/// );
/// final response = await client.chat(
///   messages: [LlmMessage.user('Hello!')],
/// );
/// ```
class AnthropicClient implements LLMClient {
  /// API key for Anthropic.
  final String apiKey;

  /// Base URL (default: https://api.anthropic.com/v1).
  final String baseUrl;

  /// Default model to use.
  final String defaultModel;

  /// Anthropic API version.
  final String apiVersion;

  /// HTTP client (injectable for testing).
  final http.Client _httpClient;

  /// Request timeout.
  final Duration timeout;

  /// Mapping from API-safe tool names to internal tool names.
  Map<String, String> _apiToInternalNames = const {};

  /// Creates an [AnthropicClient].
  AnthropicClient({
    required this.apiKey,
    this.baseUrl = 'https://api.anthropic.com/v1',
    this.defaultModel = 'claude-3-5-sonnet-20241022',
    this.apiVersion = '2023-06-01',
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 120),
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Stream<LlmChunk> streamChat({
    required List<LlmMessage> messages,
    String? model,
    double? temperature,
    int? maxTokens,
    List<LlmToolDefinition>? tools,
    String? systemPrompt,
  }) async* {
    final actualModel = model ?? defaultModel;
    final body = _buildRequestBody(
      messages: messages,
      model: actualModel,
      temperature: temperature,
      maxTokens: maxTokens,
      tools: tools,
      systemPrompt: systemPrompt,
      stream: true,
    );

    final request = http.Request('POST', Uri.parse('$baseUrl/messages'));
    request.headers['Content-Type'] = 'application/json';
    request.headers['x-api-key'] = apiKey;
    request.headers['anthropic-version'] = apiVersion;
    request.body = jsonEncode(body);

    final response = await _httpClient.send(request).timeout(timeout);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw LlmException(
        'Anthropic API error ${response.statusCode}: $errorBody',
        statusCode: response.statusCode,
      );
    }

    yield* _parseAnthropicSseStream(response.stream.transform(utf8.decoder));
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
    final actualModel = model ?? defaultModel;
    final body = _buildRequestBody(
      messages: messages,
      model: actualModel,
      temperature: temperature,
      maxTokens: maxTokens,
      tools: tools,
      systemPrompt: systemPrompt,
      stream: false,
    );

    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/messages'),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': apiVersion,
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw LlmException(
        'Anthropic API error ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseCompleteResponse(json);
  }

  @override
  List<String> availableModels() => const [
        'claude-3-5-sonnet-20241022',
        'claude-3-5-haiku-20241022',
        'claude-3-opus-20240229',
        'claude-3-sonnet-20240229',
        'claude-3-haiku-20240307',
      ];

  @override
  void dispose() {
    _httpClient.close();
  }

  // ── Private helpers ──────────────────────────────────────────────────

  Map<String, dynamic> _buildRequestBody({
    required List<LlmMessage> messages,
    required String model,
    double? temperature,
    int? maxTokens,
    List<LlmToolDefinition>? tools,
    String? systemPrompt,
    required bool stream,
  }) {
    // Extract system prompt from messages or parameter
    var system = systemPrompt;
    final conversationMessages = <LlmMessage>[];
    for (final msg in messages) {
      if (msg.role == 'system') {
        system = msg.content;
      } else {
        conversationMessages.add(msg);
      }
    }

    final body = <String, dynamic>{
      'model': model,
      'messages': conversationMessages.map(_formatMessage).toList(),
      'max_tokens': maxTokens ?? 4096,
      'stream': stream,
    };

    if (system != null && system.isNotEmpty) {
      body['system'] = system;
    }

    if (temperature != null) body['temperature'] = temperature;

    if (tools != null && tools.isNotEmpty) {
      _apiToInternalNames = _buildNameMap(tools);
      body['tools'] = tools.map((t) => {
            'name': t.name.replaceAll('.', '_'),
            'description': t.description,
            'input_schema': t.parametersSchema,
          }).toList();
    }

    return body;
  }

  Map<String, dynamic> _formatMessage(LlmMessage msg) {
    if (msg.role == 'tool') {
      // Tool results in Anthropic format
      return {
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': msg.toolCallId,
            'content': msg.content ?? '',
            if (msg.isError == true) 'is_error': true,
          },
        ],
      };
    }

    if (msg.role == 'assistant' && msg.toolCalls != null && msg.toolCalls!.isNotEmpty) {
      // Assistant with tool calls
      final content = <Map<String, dynamic>>[];
      if (msg.content != null && msg.content!.isNotEmpty) {
        content.add({'type': 'text', 'text': msg.content});
      }
      for (final tc in msg.toolCalls!) {
        content.add({
          'type': 'tool_use',
          'id': tc.id,
          'name': tc.name.replaceAll('.', '_'),
          'input': tc.arguments,
        });
      }
      return {'role': 'assistant', 'content': content};
    }

    return {
      'role': msg.role,
      'content': msg.content ?? '',
    };
  }

  Map<String, String> _buildNameMap(List<LlmToolDefinition> tools) {
    final map = <String, String>{};
    for (final t in tools) {
      final apiName = t.name.replaceAll('.', '_');
      if (apiName != t.name) {
        map[apiName] = t.name;
      }
    }
    return map;
  }

  String _resolveToolName(String apiName) {
    return _apiToInternalNames[apiName] ?? apiName;
  }

  /// Parse Anthropic SSE stream format.
  ///
  /// Anthropic uses event-typed SSE:
  /// - event: message_start — contains message metadata
  /// - event: content_block_start — starts a content block (text or tool_use)
  /// - event: content_block_delta — incremental content
  /// - event: content_block_stop — ends a content block
  /// - event: message_delta — message-level changes (stop_reason, usage)
  /// - event: message_stop — message complete
  Stream<LlmChunk> _parseAnthropicSseStream(Stream<String> lines) async* {
    final buffer = StringBuffer();
    String? currentEventType;
    final blockState = _AnthropicBlockState();

    await for (final line in lines) {
      buffer.write(line);

      while (true) {
        final bufStr = buffer.toString();
        final nlIndex = bufStr.indexOf('\n');
        if (nlIndex < 0) break;

        final rawLine = bufStr.substring(0, nlIndex);
        buffer.clear();
        buffer.write(bufStr.substring(nlIndex + 1));

        final trimmed = rawLine.trim();

        // Event type line
        if (trimmed.startsWith('event: ')) {
          currentEventType = trimmed.substring(7);
          continue;
        }

        // Data line
        if (!trimmed.startsWith('data: ')) continue;

        final data = trimmed.substring(6);
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final chunk = _parseAnthropicEvent(json, currentEventType, blockState);
          if (chunk != null) yield chunk;
        } catch (_) {}
      }
    }
  }

  LlmChunk? _parseAnthropicEvent(
    Map<String, dynamic> json,
    String? eventType,
    _AnthropicBlockState state,
  ) {
    switch (eventType) {
      case 'message_start':
        return null;

      case 'content_block_start':
        final index = json['index'] as int? ?? 0;
        final contentBlock = json['content_block'] as Map<String, dynamic>?;
        final type = contentBlock?['type'] as String?;
        state.currentIndex = index;
        state.currentType = type;

        if (type == 'tool_use') {
          state.toolUseId = contentBlock?['id'] as String?;
          state.toolUseName =
              _resolveToolName(contentBlock?['name'] as String? ?? '');
        }
        return null;

      case 'content_block_delta':
        final delta = json['delta'] as Map<String, dynamic>?;
        if (delta == null) return null;
        final deltaType = delta['type'] as String?;

        if (deltaType == 'text_delta') {
          final text = delta['text'] as String?;
          if (text != null && text.isNotEmpty) {
            return LlmChunk(contentDelta: text);
          }
        } else if (deltaType == 'thinking_delta') {
          final thinking = delta['thinking'] as String?;
          if (thinking != null && thinking.isNotEmpty) {
            return LlmChunk(thinkingDelta: thinking);
          }
        } else if (deltaType == 'input_json_delta') {
          final partialJson = delta['partial_json'] as String?;
          if (partialJson != null && state.currentIndex != null) {
            return LlmChunk(
              toolCallDelta: LlmToolCallDelta(
                index: state.currentIndex!,
                id: state.toolUseId,
                name: state.toolUseName,
                argumentsDelta: partialJson,
              ),
            );
          }
        }
        return null;

      case 'content_block_stop':
        state.currentIndex = null;
        state.currentType = null;
        return null;

      case 'message_delta':
        final delta = json['delta'] as Map<String, dynamic>?;
        final usage = json['usage'] as Map<String, dynamic>?;
        final stopReason = delta?['stop_reason'] as String?;

        if (stopReason != null || usage != null) {
          final outputTokens = usage?['output_tokens'] as int? ?? 0;
          return LlmChunk(
            isDone: true,
            finishReason: stopReason ?? 'stop',
            usage: LlmUsage(
              inputTokens: 0,
              outputTokens: outputTokens,
            ),
          );
        }
        return null;

      case 'message_stop':
        return null;

      default:
        return null;
    }
  }

  LlmCompleteResponse _parseCompleteResponse(Map<String, dynamic> json) {
    final content = json['content'] as List<dynamic>;
    final stopReason = json['stop_reason'] as String? ?? 'stop';

    final textParts = <String>[];
    final toolCalls = <ToolCall>[];

    for (final block in content) {
      final blockMap = block as Map<String, dynamic>;
      final type = blockMap['type'] as String;

      if (type == 'text') {
        textParts.add(blockMap['text'] as String);
      } else if (type == 'tool_use') {
        final id = blockMap['id'] as String;
        final name = _resolveToolName(blockMap['name'] as String);
        final input = blockMap['input'] as Map<String, dynamic>;
        toolCalls.add(ToolCall(
          id: id,
          name: name,
          arguments: input,
        ));
      }
    }

    final usage = json['usage'] as Map<String, dynamic>?;
    final inputTokens = usage?['input_tokens'] as int? ?? 0;
    final outputTokens = usage?['output_tokens'] as int? ?? 0;

    return LlmCompleteResponse(
      content: textParts.join(),
      toolCalls: toolCalls,
      finishReason: stopReason,
      usage: LlmUsage(
        inputTokens: inputTokens,
        outputTokens: outputTokens,
      ),
    );
  }
}

/// Mutable state for tracking the current content block during SSE parsing.
class _AnthropicBlockState {
  int? currentIndex;
  String? currentType;
  String? toolUseId;
  String? toolUseName;
}
