import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:nudgee/core/agent/providers/llm_client.dart';
import 'package:nudgee/core/agent/providers/openai_compatible_client.dart';

/// Google AI (Gemini) API client.
///
/// Google AI uses a different API format from OpenAI:
/// - Endpoint: `/models/{model}:generateContent` (non-stream)
///   or `/models/{model}:streamGenerateContent?alt=sse` (stream)
/// - API key is in the URL query param `?key=...`
/// - System prompt is a top-level `systemInstruction` field
/// - Messages use `contents` array with `parts` (text, functionCall, etc.)
/// - Tool calls use `functionDeclarations` and `functionCall`/`functionResponse`
/// - Streaming uses SSE with `data: {...}` lines
///
/// Supports Gemini 2.0 Flash, Gemini 1.5 Pro/Flash, and newer models.
///
/// Example:
/// ```dart
/// final client = GoogleAIClient(
///   apiKey: 'AIza...',
///   model: 'gemini-2.0-flash',
/// );
/// final response = await client.chat(
///   messages: [LlmMessage.user('Hello!')],
/// );
/// ```
class GoogleAIClient implements LLMClient {
  /// API key for Google AI.
  final String apiKey;

  /// Base URL (default: https://generativelanguage.googleapis.com/v1beta).
  final String baseUrl;

  /// Default model to use.
  final String defaultModel;

  /// HTTP client (injectable for testing).
  final http.Client _httpClient;

  /// Request timeout.
  final Duration timeout;

  /// Mapping from API-safe tool names to internal tool names.
  Map<String, String> _apiToInternalNames = const {};

  /// Creates a [GoogleAIClient].
  GoogleAIClient({
    required this.apiKey,
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
    this.defaultModel = 'gemini-2.0-flash',
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
      temperature: temperature,
      maxTokens: maxTokens,
      tools: tools,
      systemPrompt: systemPrompt,
    );

    final url = Uri.parse(
      '$baseUrl/models/$actualModel:streamGenerateContent?alt=sse&key=$apiKey',
    );

    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode(body);

    final response = await _httpClient.send(request).timeout(timeout);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw LlmException(
        'Google AI API error ${response.statusCode}: $errorBody',
        statusCode: response.statusCode,
      );
    }

    yield* _parseGeminiSseStream(response.stream.transform(utf8.decoder));
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
      temperature: temperature,
      maxTokens: maxTokens,
      tools: tools,
      systemPrompt: systemPrompt,
    );

    final url = Uri.parse(
      '$baseUrl/models/$actualModel:generateContent?key=$apiKey',
    );

    final response = await _httpClient
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw LlmException(
        'Google AI API error ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseCompleteResponse(json);
  }

  @override
  List<String> availableModels() => const [
        'gemini-2.0-flash',
        'gemini-2.0-flash-thinking-exp',
        'gemini-1.5-pro',
        'gemini-1.5-flash',
        'gemini-1.5-flash-8b',
        'gemini-exp-1206',
      ];

  @override
  Future<List<String>> fetchModels() async => availableModels();

  @override
  void dispose() {
    _httpClient.close();
  }

  // ── Private helpers ──────────────────────────────────────────────────

  Map<String, dynamic> _buildRequestBody({
    required List<LlmMessage> messages,
    double? temperature,
    int? maxTokens,
    List<LlmToolDefinition>? tools,
    String? systemPrompt,
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
      'contents': conversationMessages.map(_formatMessage).toList(),
    };

    // System instruction
    if (system != null && system.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': system},
        ],
      };
    }

    // Generation config
    final generationConfig = <String, dynamic>{};
    if (maxTokens != null) generationConfig['maxOutputTokens'] = maxTokens;
    if (temperature != null) generationConfig['temperature'] = temperature;
    if (generationConfig.isNotEmpty) {
      body['generationConfig'] = generationConfig;
    }

    // Tools
    if (tools != null && tools.isNotEmpty) {
      // Build name mapping (dots → underscores for API safety)
      final mapped = <String, String>{};
      for (final t in tools) {
        final apiName = t.name.replaceAll('.', '_');
        if (apiName != t.name) mapped[apiName] = t.name;
      }
      _apiToInternalNames = mapped;

      body['tools'] = [
        {
          'functionDeclarations': tools.map((t) {
            final apiName = t.name.replaceAll('.', '_');
            return {
              'name': apiName,
              'description': t.description,
              'parameters': t.parametersSchema,
            };
          }).toList(),
        },
      ];
    }

    return body;
  }

  Map<String, dynamic> _formatMessage(LlmMessage msg) {
    // Role mapping: user → user, assistant → model, tool → function
    final role = switch (msg.role) {
      'user' => 'user',
      'assistant' => 'model',
      'tool' => 'function', // tool results use 'function' role
      _ => 'user',
    };

    // Tool result message
    if (msg.role == 'tool') {
      return {
        'role': 'function',
        'parts': [
          {
            'functionResponse': {
              'name': msg.name?.replaceAll('.', '_') ?? 'tool',
              'response': {'result': msg.content},
            },
          },
        ],
      };
    }

    // Assistant message with tool calls
    if (msg.role == 'assistant' && msg.toolCalls != null) {
      final parts = <Map<String, dynamic>>[];
      if (msg.content != null && msg.content!.isNotEmpty) {
        parts.add({'text': msg.content});
      }
      for (final tc in msg.toolCalls!) {
        parts.add({
          'functionCall': {
            'name': tc.name.replaceAll('.', '_'),
            'args': tc.arguments,
          },
        });
      }
      return {'role': role, 'parts': parts};
    }

    // Regular text message
    return {
      'role': role,
      'parts': [
        {'text': msg.content ?? ''},
      ],
    };
  }

  LlmCompleteResponse _parseCompleteResponse(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      return const LlmCompleteResponse(
        content: '',
        toolCalls: [],
        finishReason: 'stop',
      );
    }

    final candidate = candidates[0] as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;

    var textContent = '';
    final toolCalls = <ToolCall>[];

    if (parts != null) {
      for (final part in parts) {
        if (part is! Map<String, dynamic>) continue;
        if (part.containsKey('text')) {
          textContent += part['text'] as String? ?? '';
        }
        if (part.containsKey('functionCall')) {
          final fc = part['functionCall'] as Map<String, dynamic>;
          final apiName = fc['name'] as String? ?? '';
          final internalName = _apiToInternalNames[apiName] ?? apiName;
          final args = fc['args'] as Map<String, dynamic>? ?? {};
          toolCalls.add(ToolCall(
            id: 'call_${toolCalls.length}',
            name: internalName,
            arguments: args,
          ));
        }
      }
    }

    final finishReason = candidate['finishReason'] as String? ?? 'stop';
    final usage = json['usageMetadata'] as Map<String, dynamic>?;

    return LlmCompleteResponse(
      content: textContent,
      toolCalls: toolCalls,
      finishReason: finishReason == 'STOP' ? 'stop' : finishReason.toLowerCase(),
      usage: usage != null
          ? LlmUsage(
              inputTokens: usage['promptTokenCount'] as int? ?? 0,
              outputTokens: usage['candidatesTokenCount'] as int? ?? 0,
              thinkingTokens:
                  usage['thoughtsTokenCount'] as int? ?? 0,
            )
          : null,
    );
  }

  Stream<LlmChunk> _parseGeminiSseStream(Stream<String> lines) async* {
    var buffer = '';
    var toolCallIndex = 0;

    await for (final line in lines) {
      buffer += line;

      // Process complete lines
      while (buffer.contains('\n')) {
        final idx = buffer.indexOf('\n');
        final rawLine = buffer.substring(0, idx).trim();
        buffer = buffer.substring(idx + 1);

        if (rawLine.isEmpty || !rawLine.startsWith('data: ')) continue;

        final dataStr = rawLine.substring(6);
        if (dataStr == '[DONE]') {
          yield const LlmChunk(isDone: true);
          return;
        }

        try {
          final json = jsonDecode(dataStr) as Map<String, dynamic>;
          final candidates = json['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) continue;

          final candidate = candidates[0] as Map<String, dynamic>;
          final content = candidate['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List?;

          if (parts != null) {
            for (final part in parts) {
              if (part is! Map<String, dynamic>) continue;

              // Text content
              if (part.containsKey('text')) {
                final text = part['text'] as String? ?? '';
                if (text.isNotEmpty) {
                  yield LlmChunk(contentDelta: text);
                }
              }

              // Function call
              if (part.containsKey('functionCall')) {
                final fc = part['functionCall'] as Map<String, dynamic>;
                final apiName = fc['name'] as String? ?? '';
                final internalName = _apiToInternalNames[apiName] ?? apiName;
                final args = fc['args'] as Map<String, dynamic>? ?? {};
                yield LlmChunk(
                  toolCallDelta: LlmToolCallDelta(
                    index: toolCallIndex++,
                    id: 'call_$toolCallIndex',
                    name: internalName,
                    argumentsDelta: jsonEncode(args),
                  ),
                );
              }
            }
          }

          // Check for finish
          final finishReason = candidate['finishReason'] as String?;
          if (finishReason != null && finishReason != 'FINISH_REASON_UNSPECIFIED') {
            final usage = json['usageMetadata'] as Map<String, dynamic>?;
            yield LlmChunk(
              isDone: true,
              finishReason:
                  finishReason == 'STOP' ? 'stop' : finishReason.toLowerCase(),
              usage: usage != null
                  ? LlmUsage(
                      inputTokens:
                          usage['promptTokenCount'] as int? ?? 0,
                      outputTokens:
                          usage['candidatesTokenCount'] as int? ?? 0,
                      thinkingTokens:
                          usage['thoughtsTokenCount'] as int? ?? 0,
                    )
                  : null,
            );
          }
        } catch (_) {
          // Skip malformed JSON
        }
      }
    }
  }
}
