import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:nudgee/core/agent/providers/llm_client.dart';

/// LLM client for any OpenAI-compatible API.
///
/// This is the base class for all providers that use the OpenAI
/// chat completions wire format (DeepSeek, Qiniu, OpenRouter, etc.).
///
/// Subclasses just need to override:
/// - [defaultBaseUrl] — the API base URL
/// - [defaultModel] — the default model name
/// - [availableModels] — list of supported models
///
/// The wire format (request building, SSE parsing, response parsing)
/// is identical across all OpenAI-compatible providers.
class OpenAICompatibleClient implements LLMClient {
  /// API key.
  final String apiKey;

  /// Base URL (e.g. 'https://api.openai.com/v1').
  final String baseUrl;

  /// Default model to use if not specified per-call.
  final String defaultModel;

  /// HTTP client (injectable for testing).
  final http.Client _httpClient;

  /// Request timeout for non-streaming calls.
  final Duration timeout;

  /// Mapping from API-safe tool names to internal tool names.
  Map<String, String> _apiToInternalNames = const {};

  /// Creates an [OpenAICompatibleClient].
  OpenAICompatibleClient({
    required this.apiKey,
    required this.baseUrl,
    required this.defaultModel,
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

    final request = http.Request('POST', Uri.parse('$baseUrl/chat/completions'));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.body = jsonEncode(body);

    final response = await _httpClient.send(request).timeout(timeout);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw LlmException(
        'API error ${response.statusCode}: $errorBody',
        statusCode: response.statusCode,
      );
    }

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
        'API error ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseCompleteResponse(json);
  }

  @override
  List<String> availableModels() => [defaultModel];

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

      if (response.statusCode != 200) {
        return availableModels();
      }

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
    } catch (e) {
      // Fallback to static list on any error.
      return availableModels();
    }
  }

  @override
  void dispose() {
    _httpClient.close();
  }

  // ── Private helpers ──────────────────────────────────────────────────

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

  /// Attempts to repair common JSON issues from LLM responses.
  ///
  /// Common problems:
  /// - Truncated JSON (incomplete string/value at the end)
  /// - Trailing comma before } or ]
  /// - Unescaped newlines in string values
  String _repairJson(String json) {
    var result = json.trim();

    // Remove trailing commas before } or ]
    result = result.replaceAll(RegExp(r',\s*}'), '}');
    result = result.replaceAll(RegExp(r',\s*\]'), ']');

    // If the JSON is truncated (unbalanced braces), try to close it
    int braces = 0;
    int brackets = 0;
    bool inString = false;
    String? stringChar;
    for (var i = 0; i < result.length; i++) {
      final ch = result[i];
      if (inString) {
        if (ch == '\\') {
          i++; // skip next char
        } else if (ch == stringChar) {
          inString = false;
        }
      } else {
        if (ch == '"' || ch == "'") {
          inString = true;
          stringChar = ch;
        } else if (ch == '{') {
          braces++;
        } else if (ch == '}') {
          braces--;
        } else if (ch == '[') {
          brackets++;
        } else if (ch == ']') {
          brackets--;
        }
      }
    }

    // Close unclosed strings
    if (inString) {
      result += stringChar!;
    }

    // Close unclosed brackets and braces
    for (var i = 0; i < brackets; i++) {
      result += ']';
    }
    for (var i = 0; i < braces; i++) {
      result += '}';
    }

    return result;
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
        if (data == '[DONE]') return;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final chunk = _parseStreamChunk(json, toolCallAccumulators);
          if (chunk != null) yield chunk;
        } catch (_) {}
      }
    }
  }

  LlmChunk? _parseStreamChunk(
    Map<String, dynamic> json,
    Map<int, _ToolCallAccumulator> accumulators,
  ) {
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      final usage = json['usage'] as Map<String, dynamic>?;
      if (usage != null) {
        return LlmChunk(isDone: true, usage: LlmUsage.fromJson(usage));
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

    // Reasoning/thinking content (DeepSeek-reasoner, o1, etc.)
    final reasoningContent = delta['reasoning_content'] as String?;
    if (reasoningContent != null && reasoningContent.isNotEmpty) {
      return LlmChunk(thinkingDelta: reasoningContent);
    }

    final content = delta['content'] as String?;
    if (content != null && content.isNotEmpty) {
      return LlmChunk(contentDelta: content);
    }

    final toolCalls = delta['tool_calls'] as List<dynamic>?;
    if (toolCalls != null && toolCalls.isNotEmpty) {
      final tc = toolCalls[0] as Map<String, dynamic>;
      final index = tc['index'] as int? ?? 0;
      final id = tc['id'] as String?;
      final function = tc['function'] as Map<String, dynamic>?;
      final name = function?['name'] as String?;
      final argsDelta = function?['arguments'] as String?;

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
        final args = function['arguments'];
        Map<String, dynamic> parsedArgs;
        try {
          // arguments may be a String (JSON) or already a Map
          if (args is Map<String, dynamic>) {
            parsedArgs = args;
          } else if (args is String) {
            parsedArgs = jsonDecode(args) as Map<String, dynamic>;
          } else {
            parsedArgs = {'_raw': args.toString()};
          }
        } catch (e) {
          // JSON parsing failed — try to repair common issues
          final repaired = _repairJson(args.toString());
          try {
            parsedArgs = jsonDecode(repaired) as Map<String, dynamic>;
          } catch (_) {
            parsedArgs = {'_raw': args.toString()};
          }
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

/// Exception thrown by LLM clients.
class LlmException implements Exception {
  final String message;
  final int? statusCode;

  const LlmException(this.message, {this.statusCode});

  @override
  String toString() =>
      'LlmException(${statusCode ?? "?"}): $message';
}
