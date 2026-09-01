import 'package:nudgee/core/agent/agent_event.dart';

/// A tool call request from the LLM.
///
/// Re-exported here for convenience — the canonical definition is in
/// [agent_event.dart].
export 'package:nudgee/core/agent/agent_event.dart' show ToolCall;

/// Abstract LLM client interface.
///
/// Implementations:
/// - [DeepSeekClient] — DeepSeek API (OpenAI-compatible)
///
/// Usage:
/// ```dart
/// final client = DeepSeekClient(apiKey: '...');
/// await for (final chunk in client.streamChat(
///   messages: [LlmMessage.user('Hello')],
///   systemPrompt: 'You are a helpful assistant',
/// )) {
///   if (chunk.hasContent) print(chunk.contentDelta);
/// }
/// ```
abstract class LLMClient {
  /// Streaming chat completion.
  ///
  /// Yields [LlmChunk]s as they arrive from the LLM.
  /// Supports thinking deltas, content deltas, and tool call deltas.
  Stream<LlmChunk> streamChat({
    required List<LlmMessage> messages,
    String? model,
    double? temperature,
    int? maxTokens,
    List<LlmToolDefinition>? tools,
    String? systemPrompt,
  });

  /// Non-streaming chat completion.
  ///
  /// Returns the full response at once. Use this when you need
  /// the complete result before proceeding (e.g. tool calls).
  Future<LlmCompleteResponse> chat({
    required List<LlmMessage> messages,
    String? model,
    double? temperature,
    int? maxTokens,
    List<LlmToolDefinition>? tools,
    String? systemPrompt,
  });

  /// Lists available models (static list, no network call).
  List<String> availableModels();

  /// Fetches available models from the API (/v1/models endpoint).
  /// Returns an empty list if the API doesn't support it or on error.
  Future<List<String>> fetchModels();

  /// Releases resources.
  void dispose();
}

/// A message in the LLM conversation history.
///
/// Simple representation used by [LLMClient] — not tied to any specific
/// provider's message format.
class LlmMessage {
  /// Role: 'system', 'user', 'assistant', or 'tool'.
  final String role;

  /// Text content (for user/assistant/system messages).
  final String? content;

  /// Tool calls made by the assistant (only for role='assistant').
  final List<ToolCall>? toolCalls;

  /// Tool call ID this message responds to (only for role='tool').
  final String? toolCallId;

  /// Name of the tool that produced this result (only for role='tool').
  final String? name;

  /// Whether this tool result is an error (only for role='tool').
  final bool? isError;

  /// Creates a system message.
  const LlmMessage.system(String text)
      : role = 'system',
        content = text,
        toolCalls = null,
        toolCallId = null,
        name = null,
        isError = null;

  /// Creates a user message.
  const LlmMessage.user(String text)
      : role = 'user',
        content = text,
        toolCalls = null,
        toolCallId = null,
        name = null,
        isError = null;

  /// Creates an assistant message (optionally with tool calls).
  const LlmMessage.assistant({String? text, List<ToolCall>? toolCalls})
      : role = 'assistant',
        content = text,
        toolCalls = toolCalls,
        toolCallId = null,
        name = null,
        isError = null;

  /// Creates a tool result message.
  const LlmMessage.tool({
    required String toolCallId,
    required String name,
    required String content,
    bool isError = false,
  })  : role = 'tool',
        content = content,
        toolCalls = null,
        toolCallId = toolCallId,
        name = name,
        isError = isError;

  /// Creates a message with explicit role.
  const LlmMessage({
    required this.role,
    this.content,
    this.toolCalls,
    this.toolCallId,
    this.name,
    this.isError,
  });

  @override
  String toString() {
    final parts = <String>['LlmMessage($role'];
    if (content != null && content!.isNotEmpty) {
      final preview = content!.length > 60 ? '${content!.substring(0, 60)}...' : content;
      parts.add('"$preview"');
    }
    if (toolCalls != null && toolCalls!.isNotEmpty) {
      parts.add('tools=${toolCalls!.map((t) => t.name).join(",")}');
    }
    parts.add(')');
    return parts.join(', ');
  }
}

/// A tool definition sent to the LLM so it knows what tools are available.
///
/// Follows the OpenAI function-calling JSON Schema format.
class LlmToolDefinition {
  /// Tool name (must match what the LLM returns in tool calls).
  final String name;

  /// Human-readable description of what the tool does.
  final String description;

  /// JSON Schema for the tool's parameters.
  final Map<String, dynamic> parametersSchema;

  /// Creates an [LlmToolDefinition].
  const LlmToolDefinition({
    required this.name,
    required this.description,
    required this.parametersSchema,
  });

  /// Converts to OpenAI function format.
  ///
  /// Some API gateways (e.g. Qiniu/LiteLLM) require tool names to match
  /// `^[a-zA-Z0-9_-]+$` — dots are not allowed. We replace dots with
  /// underscores here. The [DeepSeekClient] maintains a mapping to
  /// convert tool names back when parsing responses.
  Map<String, dynamic> toOpenAIJson() => {
        'type': 'function',
        'function': {
          'name': name.replaceAll('.', '_'),
          'description': description,
          'parameters': parametersSchema,
        },
      };

  @override
  String toString() => 'LlmToolDefinition($name)';
}

/// A streaming chunk from the LLM.
///
/// Each chunk represents a delta — either thinking text, content text,
/// or a tool call. A single LLM response may yield many chunks.
class LlmChunk {
  /// Thinking/reasoning delta (DeepSeek-reasoner).
  final String? thinkingDelta;

  /// Content/reply delta.
  final String? contentDelta;

  /// A tool call delta (accumulated incrementally).
  final LlmToolCallDelta? toolCallDelta;

  /// Whether this is the final chunk (includes [usage] if available).
  final bool isDone;

  /// Token usage (only present on the final chunk).
  final LlmUsage? usage;

  /// Finish reason from the API (only on final chunk).
  final String? finishReason;

  /// Creates an [LlmChunk].
  const LlmChunk({
    this.thinkingDelta,
    this.contentDelta,
    this.toolCallDelta,
    this.isDone = false,
    this.usage,
    this.finishReason,
  });

  /// Whether this chunk contains thinking content.
  bool get hasThinking => thinkingDelta != null && thinkingDelta!.isNotEmpty;

  /// Whether this chunk contains reply content.
  bool get hasContent => contentDelta != null && contentDelta!.isNotEmpty;

  /// Whether this chunk contains a tool call.
  bool get hasToolCall => toolCallDelta != null;

  @override
  String toString() {
    if (isDone) return 'LlmChunk(done, usage=$usage, finish=$finishReason)';
    if (hasThinking) return 'LlmChunk(thinking: $thinkingDelta)';
    if (hasContent) return 'LlmChunk(content: $contentDelta)';
    if (hasToolCall) return 'LlmChunk(toolCall: $toolCallDelta)';
    return 'LlmChunk(empty)';
  }
}

/// Incremental tool call delta (streamed piece by piece).
///
/// The LLM streams tool calls incrementally — [index] identifies which
/// tool call this delta belongs to (multiple tools can be called at once).
class LlmToolCallDelta {
  /// Index of this tool call in the response (0-based).
  final int index;

  /// Tool call ID (may arrive in the first chunk only).
  final String? id;

  /// Tool name (may arrive in the first chunk only).
  final String? name;

  /// Partial JSON arguments string (accumulated across chunks).
  final String? argumentsDelta;

  /// Creates a [LlmToolCallDelta].
  const LlmToolCallDelta({
    required this.index,
    this.id,
    this.name,
    this.argumentsDelta,
  });

  @override
  String toString() => 'LlmToolCallDelta(idx=$index, name=$name, args=$argumentsDelta)';
}

/// Token usage statistics for a single LLM call.
class LlmUsage {
  /// Input (prompt) tokens.
  final int inputTokens;

  /// Output (completion) tokens.
  final int outputTokens;

  /// Reasoning/thinking tokens (DeepSeek-reasoner).
  final int thinkingTokens;

  /// Total tokens.
  int get totalTokens => inputTokens + outputTokens + thinkingTokens;

  /// Creates [LlmUsage].
  const LlmUsage({
    required this.inputTokens,
    required this.outputTokens,
    this.thinkingTokens = 0,
  });

  /// Creates from JSON (OpenAI format).
  factory LlmUsage.fromJson(Map<String, dynamic> json) {
    final promptTokens = json['prompt_tokens'] as int? ?? 0;
    final completionTokens = json['completion_tokens'] as int? ?? 0;
    // DeepSeek reports reasoning tokens in completion_tokens_details
    final details = json['completion_tokens_details'] as Map<String,dynamic>?;
    final reasoningTokens = details?['reasoning_tokens'] as int? ?? 0;
    return LlmUsage(
      inputTokens: promptTokens,
      outputTokens: completionTokens - reasoningTokens,
      thinkingTokens: reasoningTokens,
    );
  }

  @override
  String toString() =>
      'LlmUsage(in=$inputTokens, out=$outputTokens, think=$thinkingTokens)';

  /// Serializes to JSON.
  Map<String, dynamic> toJson() => {
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'thinkingTokens': thinkingTokens,
        'totalTokens': totalTokens,
      };
}

/// Complete (non-streaming) LLM response.
///
/// Returned by [LLMClient.chat] for non-streaming calls.
class LlmCompleteResponse {
  /// Reply text content.
  final String content;

  /// Thinking/reasoning content (if any).
  final String? thinking;

  /// Tool calls requested by the LLM.
  final List<ToolCall> toolCalls;

  /// Finish reason ('stop', 'tool_calls', 'length', 'content_filter').
  final String finishReason;

  /// Token usage.
  final LlmUsage? usage;

  /// Creates a [LlmCompleteResponse].
  const LlmCompleteResponse({
    required this.content,
    this.thinking,
    required this.toolCalls,
    required this.finishReason,
    this.usage,
  });

  /// Whether the LLM requested tool calls.
  bool get hasToolCalls => toolCalls.isNotEmpty;

  @override
  String toString() =>
      'LlmCompleteResponse(finish=$finishReason, tools=${toolCalls.length}, tokens=${usage?.totalTokens})';
}
