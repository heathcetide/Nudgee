import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:nudgee/core/agent/providers/llm_client.dart';
import 'package:nudgee/core/agent/providers/openai_compatible_client.dart'
    show LlmException;
// Re-export LlmException for backward compatibility.
export 'package:nudgee/core/agent/providers/openai_compatible_client.dart'
    show LlmException;

/// LLM client for DeepSeek API (OpenAI-compatible).
///
/// Directly calls the DeepSeek `/v1/chat/completions` endpoint with
/// `stream: true`, supporting:
/// - Streaming text content (content deltas)
/// - Streaming thinking/reasoning content (reasoning deltas)
/// - Streaming tool calls (incremental tool call deltas)
/// - Token usage reporting
///
/// This bypasses the `flutter_ai_sdk` which doesn't support
/// streaming + tools simultaneously.
class DeepSeekClient implements LLMClient {
  /// API key for DeepSeek.
  final String apiKey;

  /// Base URL (default: https://api.deepseek.com/v1).
  final String baseUrl;

  /// Default model to use if not specified per-call.
  final String defaultModel;

  /// HTTP client (injectable for testing).
  final http.Client _httpClient;

  /// Request timeout for non-streaming calls.
  final Duration timeout;

  /// Mapping from API-safe tool names to internal tool names.
  ///
  /// Some API gateways (e.g. Qiniu/LiteLLM) require tool names to match
  /// `^[a-zA-Z0-9_-]+$` — dots are not allowed. We replace dots with
  /// underscores when sending, and use this map to convert back when
  /// parsing responses.
  Map<String, String> _apiToInternalNames = const {};

  /// Creates a [DeepSeekClient].
  DeepSeekClient({
    required this.apiKey,
    this.baseUrl = 'https://api.deepseek.com/v1',
    this.defaultModel = 'deepseek-chat',
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

    // Build request body
    final body = <String, dynamic>{
      'model': actualModel,
      'messages': _buildMessages(messages, systemPrompt),
      'stream': true,
      'stream_options': {'include_usage': true},
    };

    if (temperature != null) body['temperature'] = temperature;
    if (maxTokens != null) body['max_tokens'] = maxTokens;
    if (tools != null && tools.isNotEmpty) {
      _apiToInternalNames = _buildNameMap(tools);
      body['tools'] = tools.map((t) => t.toOpenAIJson()).toList();
    }

    // Make streaming request
    final request = http.Request('POST', Uri.parse('$baseUrl/chat/completions'));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.body = jsonEncode(body);

    final response = await _httpClient
        .send(request)
        .timeout(timeout);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw LlmException(
        'DeepSeek API error ${response.statusCode}: $errorBody',
        statusCode: response.statusCode,
      );
    }

    // Parse SSE stream
    yield* _parseSseStream(response.stream.transform(utf8.decoder));
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

    final body = <String, dynamic>{
      'model': actualModel,
      'messages': _buildMessages(messages, systemPrompt),
      'stream': false,
    };

    if (temperature != null) body['temperature'] = temperature;
    if (maxTokens != null) body['max_tokens'] = maxTokens;
    if (tools != null && tools.isNotEmpty) {
      _apiToInternalNames = _buildNameMap(tools);
      body['tools'] = tools.map((t) => t.toOpenAIJson()).toList();
    }

    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw LlmException(
        'DeepSeek API error ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseCompleteResponse(json);
  }

  @override
  List<String> availableModels() => const [
        'deepseek-chat',
        'deepseek-reasoner',
      ];

  @override
  Future<List<String>> fetchModels() async {
    try {
      final url = Uri.parse('$baseUrl/models');
      final response = await _httpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(timeout);

      if (response.statusCode != 200) return availableModels();

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List?;
      if (data == null) return availableModels();

      final models = data
          .map((e) => (e as Map<String, dynamic>)['id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList()
        ..sort();

      return models.isEmpty ? availableModels() : models;
    } catch (_) {
      return availableModels();
    }
  }

  @override
  void dispose() {
    _httpClient.close();
  }

  // ── Private helpers ──────────────────────────────────────────────────

  /// Builds a mapping from API-safe names (dots replaced with underscores)
  /// to internal tool names.
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

  /// Resolves an API-safe tool name back to the internal name.
  String _resolveToolName(String apiName) {
    return _apiToInternalNames[apiName] ?? apiName;
  }

  List<Map<String, dynamic>> _buildMessages(
    List<LlmMessage> messages,
    String? systemPrompt,
  ) {
    final result = <Map<String, dynamic>>[];

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      result.add({'role': 'system', 'content': systemPrompt});
    }

    for (final msg in messages) {
      final m = <String, dynamic>{'role': msg.role};

      // Multimodal: if user message has images, send content as array
      // of text + image_url parts (OpenAI vision format).
      if (msg.images != null && msg.images!.isNotEmpty && msg.role == 'user') {
        final contentParts = <Map<String, dynamic>>[];
        if (msg.content != null && msg.content!.isNotEmpty) {
          contentParts.add({'type': 'text', 'text': msg.content});
        }
        for (final img in msg.images!) {
          contentParts.add({
            'type': 'image_url',
            'image_url': {'url': img},
          });
        }
        m['content'] = contentParts;
      } else if (msg.content != null) {
        m['content'] = msg.content;
      } else if (msg.role == 'assistant') {
        // Assistant with tool calls but no text
        m['content'] = null;
      }

      if (msg.toolCalls != null && msg.toolCalls!.isNotEmpty) {
        m['tool_calls'] = msg.toolCalls!.map((tc) => {
              'id': tc.id,
              'type': 'function',
              'function': {
                'name': tc.name.replaceAll('.', '_'),
                'arguments': jsonEncode(tc.arguments),
              },
            }).toList();
      }

      if (msg.toolCallId != null) {
        m['tool_call_id'] = msg.toolCallId;
      }

      if (msg.name != null) {
        m['name'] = msg.name;
      }

      result.add(m);
    }

    return result;
  }

  Stream<LlmChunk> _parseSseStream(Stream<String> lines) async* {
    final buffer = StringBuffer();
    final toolCallAccumulators = <int, _ToolCallAccumulator>{};

    await for (final line in lines) {
      buffer.write(line);

      // Process complete lines
      while (true) {
        final bufStr = buffer.toString();
        final nlIndex = bufStr.indexOf('\n');
        if (nlIndex < 0) break;

        final rawLine = bufStr.substring(0, nlIndex);
        buffer.clear();
        buffer.write(bufStr.substring(nlIndex + 1));

        final trimmed = rawLine.trim();
        if (trimmed.isEmpty) continue;
        if (!trimmed.startsWith('data: ')) continue;

        final data = trimmed.substring(6);
        if (data == '[DONE]') {
          // [DONE] just signals end of stream — don't yield another done chunk
          // (the finish_reason chunk already yielded isDone=true)
          return;
        }

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final chunk = _parseStreamChunk(json, toolCallAccumulators);
          if (chunk != null) yield chunk;
        } catch (e) {
          // Skip malformed lines
        }
      }
    }
  }

  LlmChunk? _parseStreamChunk(
    Map<String, dynamic> json,
    Map<int, _ToolCallAccumulator> accumulators,
  ) {
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      // Check for usage-only chunk (sent at end with stream_options)
      final usage = json['usage'] as Map<String, dynamic>?;
      if (usage != null) {
        return LlmChunk(
          isDone: true,
          usage: LlmUsage.fromJson(usage),
        );
      }
      return null;
    }

    final choice = choices[0] as Map<String, dynamic>;
    final delta = choice['delta'] as Map<String, dynamic>?;
    final finishReason = choice['finish_reason'] as String?;

    if (finishReason != null) {
      final usage = json['usage'] as Map<String, dynamic>?;
      return LlmChunk(
        isDone: true,
        finishReason: finishReason,
        usage: usage != null ? LlmUsage.fromJson(usage) : null,
      );
    }

    if (delta == null) return null;

    // Reasoning/thinking content (DeepSeek-reasoner)
    final reasoningContent = delta['reasoning_content'] as String?;
    if (reasoningContent != null && reasoningContent.isNotEmpty) {
      return LlmChunk(thinkingDelta: reasoningContent);
    }

    // Regular content
    final content = delta['content'] as String?;
    if (content != null && content.isNotEmpty) {
      return LlmChunk(contentDelta: content);
    }

    // Tool calls (incremental)
    final toolCalls = delta['tool_calls'] as List<dynamic>?;
    if (toolCalls != null && toolCalls.isNotEmpty) {
      final tc = toolCalls[0] as Map<String, dynamic>;
      final index = tc['index'] as int? ?? 0;
      final id = tc['id'] as String?;
      final function = tc['function'] as Map<String, dynamic>?;
      final name = function?['name'] as String?;
      final argsDelta = function?['arguments'] as String?;

      // Accumulate
      final acc = accumulators.putIfAbsent(index, () => _ToolCallAccumulator());
      if (id != null) acc.id = id;
      if (name != null) acc.name = _resolveToolName(name);
      if (argsDelta != null) acc.argumentsBuffer.write(argsDelta);

      return LlmChunk(
        toolCallDelta: LlmToolCallDelta(
          index: index,
          id: id,
          name: name != null ? _resolveToolName(name) : null,
          argumentsDelta: argsDelta,
        ),
      );
    }

    return null;
  }

  LlmCompleteResponse _parseCompleteResponse(Map<String, dynamic> json) {
    final choices = json['choices'] as List<dynamic>;
    final choice = choices[0] as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>;
    final finishReason = choice['finish_reason'] as String? ?? 'stop';

    final content = message['content'] as String?;
    final reasoningContent = message['reasoning_content'] as String?;

    final toolCallsJson = message['tool_calls'] as List<dynamic>?;
    final toolCalls = <ToolCall>[];
    if (toolCallsJson != null) {
      for (final tc in toolCallsJson) {
        final tcMap = tc as Map<String, dynamic>;
        final function = tcMap['function'] as Map<String, dynamic>;
        final args = function['arguments'] as String;
        Map<String, dynamic> parsedArgs;
        try {
          parsedArgs = jsonDecode(args) as Map<String, dynamic>;
        } catch (_) {
          parsedArgs = {'_raw': args};
        }
        toolCalls.add(ToolCall(
          id: tcMap['id'] as String,
          name: _resolveToolName(function['name'] as String),
          arguments: parsedArgs,
        ));
      }
    }

    final usageJson = json['usage'] as Map<String, dynamic>?;

    return LlmCompleteResponse(
      content: content ?? '',
      thinking: reasoningContent,
      toolCalls: toolCalls,
      finishReason: finishReason,
      usage: usageJson != null ? LlmUsage.fromJson(usageJson) : null,
    );
  }
}

/// Accumulator for incremental tool call parsing.
class _ToolCallAccumulator {
  String? id;
  String? name;
  final StringBuffer argumentsBuffer = StringBuffer();
}
