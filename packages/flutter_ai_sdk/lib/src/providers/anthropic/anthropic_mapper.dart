import 'dart:convert';

import 'package:flutter_ai_sdk/src/batch/batch.dart';
import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';

/// Maps SDK models to and from the Anthropic wire format.
///
/// Stateless translation layer used by `AnthropicProvider`:
/// request building, response parsing and stream chunk decoding.
class AnthropicMapper {
  /// Creates an [AnthropicMapper].
  const AnthropicMapper();

  /// Builds the request body for the Anthropic messages API.
  Map<String, dynamic> buildRequestBody(
    List<Message> messages, {
    required AIConfig config,
    required String model,
    required bool stream,
  }) {
    // Separate system message from conversation
    var systemPrompt = config.systemPrompt;
    final conversationMessages = <Message>[];

    for (final message in messages) {
      if (message.role == MessageRole.system) {
        systemPrompt = message.text;
      } else {
        conversationMessages.add(message);
      }
    }

    final body = <String, dynamic>{
      'model': model,
      'messages': _mergeConsecutiveRoles(
        conversationMessages.map(formatMessage).toList(),
      ),
      'stream': stream,
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }

    // Anthropic requires max_tokens
    body['max_tokens'] = config.maxTokens ?? 4096;

    // Claude 4+ models reject requests carrying both temperature and top_p;
    // send at most one, preferring temperature.
    if (config.temperature != null) {
      body['temperature'] = config.temperature;
    } else if (config.topP != null) {
      body['top_p'] = config.topP;
    }

    final thinking = config.thinking;
    if (thinking != null) {
      // Adaptive thinking: the older `{type: "enabled", budget_tokens}`
      // form is deprecated/rejected on current models.
      body['thinking'] = {'type': 'adaptive'};
    }

    if (config.stopSequences != null) {
      body['stop_sequences'] = config.stopSequences;
    }
    if (config.tools != null && config.tools!.isNotEmpty) {
      body['tools'] = config.tools!.map((t) => t.toAnthropicFormat()).toList();
      if (config.toolChoice != null) {
        body['tool_choice'] =
            config.toolChoice!.toProviderFormat(AIProviderType.anthropic);
      }
    }

    // Prompt caching: top-level cache_control auto-places a cache
    // breakpoint on the last cacheable block of the request prefix.
    final promptCaching = config.promptCaching;
    if (promptCaching != null) {
      body['cache_control'] = {
        'type': 'ephemeral',
        if (promptCaching.ttl == PromptCacheTtl.oneHour) 'ttl': '1h',
      };
    }

    // output_config carries both the thinking effort level and structured
    // outputs, so they're merged into a single map.
    final outputConfig = <String, dynamic>{};
    if (thinking?.effort != null) {
      outputConfig['effort'] = thinking!.effort!.name;
    }
    // Structured outputs: Anthropic only supports schema-constrained JSON
    // (there is no plain "JSON mode" without a schema).
    final responseFormat = config.responseFormat;
    if (responseFormat is JsonResponseFormat && responseFormat.schema != null) {
      outputConfig['format'] = {
        'type': 'json_schema',
        'schema': responseFormat.schema,
      };
    }
    if (outputConfig.isNotEmpty) {
      body['output_config'] = outputConfig;
    }

    return body;
  }

  /// Builds the request body for the Anthropic count_tokens API.
  ///
  /// The endpoint only accepts the prompt-shaping fields of a messages
  /// request (model, messages, system, tools, tool_choice).
  Map<String, dynamic> buildCountTokensBody(
    List<Message> messages, {
    required AIConfig config,
    required String model,
  }) {
    const allowedFields = {
      'model',
      'messages',
      'system',
      'tools',
      'tool_choice',
    };
    return buildRequestBody(
      messages,
      config: config,
      model: model,
      stream: false,
    )..removeWhere((key, _) => !allowedFields.contains(key));
  }

  /// Merges consecutive messages that map to the same wire role.
  ///
  /// The Anthropic API requires user/assistant roles to alternate; tool
  /// results and regular user turns both map to the `user` role, so their
  /// content blocks must be combined into a single message.
  List<Map<String, dynamic>> _mergeConsecutiveRoles(
    List<Map<String, dynamic>> messages,
  ) {
    final merged = <Map<String, dynamic>>[];
    for (final message in messages) {
      if (merged.isNotEmpty && merged.last['role'] == message['role']) {
        (merged.last['content'] as List<dynamic>)
            .addAll(message['content'] as List<dynamic>);
      } else {
        merged.add(message);
      }
    }
    return merged;
  }

  /// Formats a message for the Anthropic API.
  Map<String, dynamic> formatMessage(Message message) {
    final role = switch (message.role) {
      MessageRole.user => 'user',
      MessageRole.assistant => 'assistant',
      MessageRole.tool => 'user', // Tool results are sent as user messages
      MessageRole.system => 'user', // Should be filtered out
    };

    // Handle tool results
    if (message.role == MessageRole.tool) {
      final toolResults =
          message.content.whereType<ToolResultContent>().toList();
      return {
        'role': role,
        'content': toolResults
            .map(
              (tr) => {
                'type': 'tool_result',
                'tool_use_id': tr.toolCallId,
                'content':
                    tr.result is String ? tr.result : jsonEncode(tr.result),
                if (tr.isError) 'is_error': true,
              },
            )
            .toList(),
      };
    }

    // Handle content
    final content = message.content.map(formatContent).toList();

    // Add tool use blocks for assistant messages with tool calls
    if (message.role == MessageRole.assistant && message.hasToolCalls) {
      for (final toolCall in message.toolCalls!) {
        content.add({
          'type': 'tool_use',
          'id': toolCall.id,
          'name': toolCall.name,
          'input': toolCall.arguments,
        });
      }
    }

    return {
      'role': role,
      'content': content,
    };
  }

  /// Formats content for the Anthropic API.
  Map<String, dynamic> formatContent(Content content) {
    switch (content) {
      case TextContent(:final text):
        return {'type': 'text', 'text': text};
      case ImageContent(:final url, :final data, :final mimeType):
        if (url != null) {
          return {
            'type': 'image',
            'source': {
              'type': 'url',
              'url': url,
            },
          };
        }
        return {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': mimeType ?? 'image/png',
            'data': data,
          },
        };
      case DocumentContent(
          :final url,
          :final data,
          :final mimeType,
          :final name
        ):
        if (url != null) {
          return {
            'type': 'document',
            'source': {
              'type': 'url',
              'url': url,
            },
            if (name != null) 'name': name,
          };
        }
        return {
          'type': 'document',
          'source': {
            'type': 'base64',
            'media_type': mimeType,
            'data': data,
          },
          if (name != null) 'name': name,
        };
      default:
        return {'type': 'text', 'text': content.toString()};
    }
  }

  /// Parses a response body from the Anthropic API.
  AIResponse parseResponse(Map<String, dynamic> data) {
    final contentList = data['content'] as List<dynamic>;
    final content = <Content>[];
    final toolCalls = <ToolCallContent>[];

    for (final item in contentList) {
      final itemMap = item as Map<String, dynamic>;
      final type = itemMap['type'] as String;

      switch (type) {
        case 'text':
          content.add(TextContent(itemMap['text'] as String));
        case 'thinking':
          content.add(
            ThinkingContent(
              itemMap['thinking'] as String,
              signature: itemMap['signature'] as String?,
            ),
          );
        case 'tool_use':
          toolCalls.add(
            ToolCallContent(
              id: itemMap['id'] as String,
              name: itemMap['name'] as String,
              arguments: itemMap['input'] as Map<String, dynamic>,
            ),
          );
      }
    }

    final stopReasonStr = data['stop_reason'] as String?;
    final usage = parseUsage(data['usage'] as Map<String, dynamic>?);

    return AIResponse(
      id: data['id'] as String,
      content: content,
      finishReason: parseStopReason(stopReasonStr),
      toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
      usage: usage,
      model: data['model'] as String?,
      provider: AIProvider.anthropic,
      createdAt: DateTime.now(),
      metadata: {'raw': data},
    );
  }

  /// Parses a streaming SSE chunk from the Anthropic API.
  ///
  /// The signature that authenticates a completed thinking block arrives as
  /// a separate `signature_delta` event; it isn't attached to the streamed
  /// [ThinkingContent] (only available on the non-streaming response).
  StreamChunk? parseStreamChunk(String chunk) {
    // Handle SSE format
    if (!chunk.startsWith('data: ')) return null;

    final dataStr = chunk.substring(6).trim();
    if (dataStr.isEmpty) return null;

    try {
      final data = jsonDecode(dataStr) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'content_block_delta':
          final delta = data['delta'] as Map<String, dynamic>?;
          if (delta != null) {
            final deltaType = delta['type'] as String?;
            if (deltaType == 'text_delta') {
              return StreamChunk.delta(delta['text'] as String);
            }
            if (deltaType == 'thinking_delta') {
              return StreamChunk.thinkingDelta(delta['thinking'] as String);
            }
            if (deltaType == 'input_json_delta') {
              return StreamChunk(
                type: StreamEventType.toolCallDelta,
                metadata: {'partial_json': delta['partial_json']},
              );
            }
          }

        case 'message_delta':
          final delta = data['delta'] as Map<String, dynamic>?;
          final stopReason = delta?['stop_reason'] as String?;
          final usageData = data['usage'] as Map<String, dynamic>?;

          if (stopReason != null || usageData != null) {
            return StreamChunk.done(
              finishReason: parseStopReason(stopReason),
              usage: parseUsage(usageData),
            );
          }

        case 'message_stop':
          return const StreamChunk.done();
      }

      return null;
    } catch (e) {
      return StreamChunk.error(e);
    }
  }

  /// Parses usage counters, including prompt cache reads and writes.
  Usage? parseUsage(Map<String, dynamic>? usageData) {
    if (usageData == null) return null;
    return Usage(
      promptTokens: usageData['input_tokens'] as int? ?? 0,
      completionTokens: usageData['output_tokens'] as int? ?? 0,
      cachedTokens: usageData['cache_read_input_tokens'] as int?,
      cacheWriteTokens: usageData['cache_creation_input_tokens'] as int?,
    );
  }

  /// Parses a stop reason string.
  FinishReason parseStopReason(String? reason) => switch (reason) {
        'end_turn' => FinishReason.stop,
        'stop_sequence' => FinishReason.stop,
        'max_tokens' => FinishReason.maxTokens,
        'model_context_window_exceeded' => FinishReason.maxTokens,
        'tool_use' => FinishReason.toolCalls,
        'refusal' => FinishReason.contentFilter,
        _ => FinishReason.unknown,
      };

  /// Builds the request body for the Anthropic message batches API.
  Map<String, dynamic> buildBatchRequestBody(
    List<BatchRequest> requests, {
    required String defaultModel,
  }) =>
      {
        'requests': requests
            .map(
              (request) => {
                'custom_id': request.customId,
                'params': buildRequestBody(
                  request.messages,
                  config: request.config,
                  model: request.config.model ?? defaultModel,
                  stream: false,
                ),
              },
            )
            .toList(),
      };

  /// Parses a batch job status response.
  BatchJob parseBatchJob(Map<String, dynamic> data) {
    final counts = data['request_counts'] as Map<String, dynamic>?;
    final succeeded = counts?['succeeded'] as int?;
    final errored = counts?['errored'] as int?;
    final canceled = counts?['canceled'] as int?;
    final expired = counts?['expired'] as int?;
    final processing = counts?['processing'] as int?;

    return BatchJob(
      id: data['id'] as String,
      status: parseBatchStatus(data['processing_status'] as String?),
      totalRequests: counts == null
          ? null
          : (succeeded ?? 0) +
              (errored ?? 0) +
              (canceled ?? 0) +
              (expired ?? 0) +
              (processing ?? 0),
      completedRequests: succeeded,
      failedRequests: counts == null
          ? null
          : (errored ?? 0) + (canceled ?? 0) + (expired ?? 0),
      metadata: {'raw': data},
    );
  }

  /// Parses a batch job processing status.
  BatchStatus parseBatchStatus(String? status) => switch (status) {
        'ended' => BatchStatus.completed,
        _ => BatchStatus.inProgress,
      };

  /// Parses a batch results JSONL body (one JSON object per line).
  List<BatchResult> parseBatchResults(String jsonl) {
    final results = <BatchResult>[];

    for (final line in jsonl.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final data = jsonDecode(trimmed) as Map<String, dynamic>;
      final customId = data['custom_id'] as String;
      final result = data['result'] as Map<String, dynamic>;
      final type = result['type'] as String?;

      if (type == 'succeeded') {
        final message = result['message'] as Map<String, dynamic>;
        results.add(
          BatchResult(customId: customId, response: parseResponse(message)),
        );
      } else {
        results.add(
          BatchResult(
            customId: customId,
            error: result['error'] ?? {'type': type},
          ),
        );
      }
    }

    return results;
  }
}
