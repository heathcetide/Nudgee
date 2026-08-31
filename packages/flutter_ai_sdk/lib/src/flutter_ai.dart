import 'dart:async';
import 'dart:convert';

import 'package:flutter_ai_sdk/src/batch/batch.dart';
import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/context/context_manager.dart';
import 'package:flutter_ai_sdk/src/context/persistence/memory.dart';
import 'package:flutter_ai_sdk/src/embeddings/embeddings.dart';
import 'package:flutter_ai_sdk/src/errors/errors.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/providers.dart';

/// Main entry point for the Flutter AI SDK.
///
/// Provides a unified interface for interacting with multiple AI providers.
/// Supports both simple chat and advanced features like streaming,
/// context management, and multimodal content.
///
/// ## Basic Usage
///
/// ```dart
/// // Initialize with OpenAI
/// final ai = FlutterAI(
///   provider: AIProvider.openai,
///   config: AIConfig(
///     apiKey: 'your-api-key',
///     model: 'gpt-5.5',
///   ),
/// );
///
/// // Simple chat
/// final response = await ai.chat('Hello, how are you?');
/// print(response.text);
///
/// // Streaming
/// await for (final chunk in ai.streamChat('Tell me a story')) {
///   print(chunk.delta);
/// }
/// ```
///
/// ## With Context Management
///
/// ```dart
/// final ai = FlutterAI(
///   provider: AIProvider.anthropic,
///   config: AIConfig(
///     apiKey: 'your-api-key',
///     systemPrompt: 'You are a helpful coding assistant.',
///   ),
/// );
///
/// // Multi-turn conversation
/// await ai.chat('What is Dart?');
/// await ai.chat('Can you show me an example?');
/// await ai.chat('How does it compare to JavaScript?');
/// ```
///
/// ## Multimodal Content
///
/// ```dart
/// final ai = FlutterAI(
///   provider: AIProvider.openai,
///   config: AIConfig(
///     apiKey: 'your-api-key',
///     model: 'gpt-5.5',
///   ),
/// );
///
/// final response = await ai.chatWithContent([
///   TextContent('What is in this image?'),
///   ImageContent.fromUrl('https://example.com/image.png'),
/// ]);
/// ```
class FlutterAI {
  /// Creates a [FlutterAI] instance.
  ///
  /// [provider] specifies which AI provider to use.
  /// [config] contains API key and other settings.
  /// [customProvider] replaces the built-in provider implementation —
  /// useful for plugging a custom [BaseProvider] or for testing.
  FlutterAI({
    required AIProvider provider,
    required AIConfig config,
    ContextManager? contextManager,
    BaseProvider? customProvider,
  })  : _providerType = provider,
        _config = config,
        _contextManager = contextManager ??
            ContextManager(
              systemPrompt: config.systemPrompt,
            ),
        _provider = customProvider ?? ProviderRegistry.create(provider, config);

  /// The provider type.
  final AIProvider _providerType;

  /// The configuration.
  final AIConfig _config;

  /// The underlying provider.
  final BaseProvider _provider;

  /// The context manager.
  final ContextManager _contextManager;

  /// Gets the provider type.
  AIProvider get provider => _providerType;

  /// Gets the configuration.
  AIConfig get config => _config;

  /// Gets the context manager.
  ContextManager get context => _contextManager;

  /// Gets the current conversation.
  Conversation get conversation => _contextManager.conversation;

  /// Sends a simple text message and gets a response.
  ///
  /// This is the simplest way to interact with the AI.
  /// Messages are automatically added to the conversation context.
  ///
  /// Example:
  /// ```dart
  /// final response = await ai.chat('Hello!');
  /// print(response.text);
  /// ```
  Future<AIResponse> chat(
    String message, {
    bool addToContext = true,
  }) async {
    if (addToContext) {
      _contextManager.addUserMessage(message);
    }

    final messages = _contextManager.getMessagesForRequest();
    final response = await _provider.chat(messages);

    if (addToContext) {
      _contextManager.addAssistantMessage(response.text);
    }

    return response;
  }

  /// Sends content (potentially multimodal) and gets a response.
  ///
  /// Use this for sending images, documents, etc.
  ///
  /// Example:
  /// ```dart
  /// final response = await ai.chatWithContent([
  ///   TextContent('Describe this image'),
  ///   ImageContent.fromUrl('https://...'),
  /// ]);
  /// ```
  Future<AIResponse> chatWithContent(
    List<Content> content, {
    bool addToContext = true,
  }) async {
    final message = Message(
      role: MessageRole.user,
      content: content,
    );

    if (addToContext) {
      _contextManager.addMessage(message);
    }

    final messages = _contextManager.getMessagesForRequest();
    final response = await _provider.chat(messages);

    if (addToContext) {
      _contextManager.addAssistantMessage(response.text);
    }

    return response;
  }

  /// Sends a message with tools/functions available.
  ///
  /// The response may include tool calls that your code should handle.
  ///
  /// Example:
  /// ```dart
  /// final response = await ai.chatWithTools(
  ///   'What is the weather in Paris?',
  ///   tools: [weatherTool],
  /// );
  ///
  /// if (response.hasToolCalls) {
  ///   for (final call in response.toolCalls!) {
  ///     final result = await executeToolCall(call);
  ///     await ai.submitToolResult(
  ///       toolCallId: call.id,
  ///       name: call.name,
  ///       result: result,
  ///     );
  ///   }
  /// }
  /// ```
  Future<AIResponse> chatWithTools(
    String message, {
    required List<Tool> tools,
    ToolChoice? toolChoice,
    bool addToContext = true,
  }) async {
    // Create a modified config with tools
    final toolConfig = _config.copyWith(
      tools: tools,
      toolChoice: toolChoice,
    );

    // Create a temporary provider with the tool config
    final toolProvider = ProviderRegistry.create(_providerType, toolConfig);

    if (addToContext) {
      _contextManager.addUserMessage(message);
    }

    final messages = _contextManager.getMessagesForRequest();
    final response = await toolProvider.chat(messages);

    // Add assistant response with tool calls to context
    if (addToContext) {
      final assistantMessage = Message.assistant(
        response.text,
        toolCalls: response.toolCalls,
      );
      _contextManager.addMessage(assistantMessage);
    }

    return response;
  }

  /// Submits a tool result back to the model.
  ///
  /// Call this after executing a tool call to continue the conversation.
  ///
  /// Example:
  /// ```dart
  /// final response = await ai.submitToolResult(
  ///   toolCallId: 'call_123',
  ///   name: 'get_weather',
  ///   result: {'temperature': 22, 'condition': 'sunny'},
  /// );
  /// ```
  Future<AIResponse> submitToolResult({
    required String toolCallId,
    required String name,
    required dynamic result,
    bool isError = false,
  }) async {
    _contextManager.addToolResult(
      toolCallId: toolCallId,
      name: name,
      result: result,
      isError: isError,
    );

    final messages = _contextManager.getMessagesForRequest();
    final response = await _provider.chat(messages);

    _contextManager.addAssistantMessage(response.text);

    return response;
  }

  /// Streams a response from the AI.
  ///
  /// Yields chunks as they are generated.
  ///
  /// Example:
  /// ```dart
  /// final buffer = StringBuffer();
  /// await for (final chunk in ai.streamChat('Tell me a story')) {
  ///   if (chunk.isDelta) {
  ///     buffer.write(chunk.delta);
  ///     print(chunk.delta);
  ///   }
  /// }
  /// ```
  Stream<StreamChunk> streamChat(
    String message, {
    bool addToContext = true,
  }) async* {
    if (addToContext) {
      _contextManager.addUserMessage(message);
    }

    final messages = _contextManager.getMessagesForRequest();
    final buffer = StringBuffer();

    await for (final chunk in _provider.streamChat(messages)) {
      if (chunk.isDelta && chunk.delta != null) {
        buffer.write(chunk.delta);
      }
      yield chunk;
    }

    if (addToContext) {
      _contextManager.addAssistantMessage(buffer.toString());
    }
  }

  /// Streams a response with multimodal content.
  ///
  /// Example:
  /// ```dart
  /// await for (final chunk in ai.streamChatWithContent([
  ///   TextContent('Describe this image'),
  ///   ImageContent.fromUrl('https://...'),
  /// ])) {
  ///   print(chunk.delta);
  /// }
  /// ```
  Stream<StreamChunk> streamChatWithContent(
    List<Content> content, {
    bool addToContext = true,
  }) async* {
    final message = Message(
      role: MessageRole.user,
      content: content,
    );

    if (addToContext) {
      _contextManager.addMessage(message);
    }

    final messages = _contextManager.getMessagesForRequest();
    final buffer = StringBuffer();

    await for (final chunk in _provider.streamChat(messages)) {
      if (chunk.isDelta && chunk.delta != null) {
        buffer.write(chunk.delta);
      }
      yield chunk;
    }

    if (addToContext) {
      _contextManager.addAssistantMessage(buffer.toString());
    }
  }

  /// Counts the tokens of the current context, optionally with [message]
  /// appended as a user turn.
  ///
  /// Uses the provider's native token counting endpoint when available
  /// (Anthropic, Google AI) and a local estimation otherwise.
  ///
  /// Example:
  /// ```dart
  /// final tokens = await ai.countTokens(message: 'Long prompt...');
  /// if (tokens > 100000) {
  ///   // Trim the context before sending
  /// }
  /// ```
  Future<int> countTokens({String? message}) {
    final messages = [
      ..._contextManager.getMessagesForRequest(),
      if (message != null) Message.user(message),
    ];
    return _provider.countTokens(messages);
  }

  /// Attaches [memory] so the conversation is saved automatically after
  /// every turn (see [ContextManager.attachMemory]).
  ///
  /// Example:
  /// ```dart
  /// await ai.attachMemory(InMemoryMemory());
  /// await ai.chat('Hello!'); // saved automatically
  /// ```
  Future<void> attachMemory(Memory memory) =>
      _contextManager.attachMemory(memory);

  /// Stops auto-saving to the currently attached memory, if any.
  Future<void> detachMemory() => _contextManager.detachMemory();

  /// Saves the current conversation to [memory] once, without attaching
  /// it for auto-save.
  Future<void> saveConversation(Memory memory) =>
      memory.saveConversation(_contextManager.conversation);

  /// Loads a previously saved conversation from [memory], replacing the
  /// current one. Returns `false` if no conversation with that [id] exists.
  ///
  /// Example:
  /// ```dart
  /// final restored = await ai.loadConversation(memory, savedId);
  /// if (restored) print('Resumed: ${ai.conversation.title}');
  /// ```
  Future<bool> loadConversation(Memory memory, String id) =>
      _contextManager.loadFromMemory(memory, id);

  /// Clears the conversation context.
  void clearContext() {
    _contextManager.clear();
  }

  /// Resets the conversation with an optional new system prompt.
  void reset({String? systemPrompt}) {
    _contextManager.reset(systemPrompt: systemPrompt);
  }

  /// Gets conversation history.
  List<Message> get history => _contextManager.messages;

  /// Generates an embedding vector for [text].
  ///
  /// Throws [AIFeatureNotSupportedError] if the current provider doesn't
  /// implement [EmbeddingProvider] (Anthropic has no embeddings API, for
  /// instance).
  ///
  /// Example:
  /// ```dart
  /// final vector = await ai.embed('Hello, world!');
  /// ```
  Future<List<double>> embed(String text, {String? model}) async {
    final response = await _embeddingProvider.embed(
      EmbeddingRequest(input: [text], model: model),
    );
    return response.embeddings.single;
  }

  /// Generates embedding vectors for multiple [texts] in a single request.
  ///
  /// Throws [AIFeatureNotSupportedError] if the current provider doesn't
  /// implement [EmbeddingProvider].
  Future<List<List<double>>> embedBatch(
    List<String> texts, {
    String? model,
  }) async {
    final response = await _embeddingProvider.embed(
      EmbeddingRequest(input: texts, model: model),
    );
    return response.embeddings;
  }

  /// The provider cast to [EmbeddingProvider], if it supports embeddings.
  EmbeddingProvider get _embeddingProvider {
    if (_provider is! EmbeddingProvider) {
      throw AIFeatureNotSupportedError(
        message: '${_providerType.name} does not support embeddings',
        feature: 'embeddings',
      );
    }
    return _provider as EmbeddingProvider;
  }

  /// Submits [requests] as a new batch job, typically at a reduced cost
  /// compared to synchronous requests (non-latency-sensitive workloads).
  ///
  /// Throws [AIFeatureNotSupportedError] if the current provider doesn't
  /// implement [BatchProvider] (only Anthropic and OpenAI currently do).
  ///
  /// Example:
  /// ```dart
  /// final job = await ai.submitBatch([
  ///   BatchRequest(
  ///     customId: 'q1',
  ///     messages: [Message.user('...')],
  ///     config: ai.config,
  ///   ),
  /// ]);
  /// ```
  Future<BatchJob> submitBatch(List<BatchRequest> requests) =>
      _batchProvider.submitBatch(requests);

  /// Fetches the current status of the batch job [batchId].
  Future<BatchJob> getBatchStatus(String batchId) =>
      _batchProvider.getBatchStatus(batchId);

  /// Fetches the results of the (terminal) batch job [batchId].
  ///
  /// Results are not guaranteed to come back in submission order — match
  /// them to requests via `BatchResult.customId`.
  Future<List<BatchResult>> getBatchResults(String batchId) =>
      _batchProvider.getBatchResults(batchId);

  /// Polls the batch job [batchId] until it reaches a terminal state,
  /// yielding every intermediate [BatchJob] (including the final one).
  ///
  /// Uses exponential backoff between polls — see [pollBatchJob].
  Stream<BatchJob> waitForBatchCompletion(
    String batchId, {
    Duration initialInterval = const Duration(seconds: 5),
    Duration maxInterval = const Duration(seconds: 60),
  }) =>
      pollBatchJob(
        _batchProvider,
        batchId,
        initialInterval: initialInterval,
        maxInterval: maxInterval,
      );

  /// The provider cast to [BatchProvider], if it supports batch processing.
  BatchProvider get _batchProvider {
    if (_provider is! BatchProvider) {
      throw AIFeatureNotSupportedError(
        message: '${_providerType.name} does not support batch processing',
        feature: 'batch',
      );
    }
    return _provider as BatchProvider;
  }

  /// Disposes resources.
  void dispose() {
    _provider.dispose();
    _contextManager.dispose();
  }
}

/// Extension for convenience methods.
extension FlutterAIExtensions on FlutterAI {
  /// Sends a message and extracts JSON from the response.
  ///
  /// Useful for structured data extraction.
  ///
  /// Example:
  /// ```dart
  /// final data = await ai.chatForJson(
  ///   'Extract the following information as JSON: ...',
  /// );
  /// ```
  Future<Map<String, dynamic>?> chatForJson(
    String message, {
    bool addToContext = true,
  }) async {
    final jsonConfig = _config.copyWith(
      responseFormat: const JsonResponseFormat(),
    );

    final jsonProvider = ProviderRegistry.create(provider, jsonConfig);

    if (addToContext) {
      context.addUserMessage(message);
    }

    final messages = context.getMessagesForRequest();
    final response = await jsonProvider.chat(messages);

    if (addToContext) {
      context.addAssistantMessage(response.text);
    }

    try {
      // Attempt to parse JSON from response
      final text = response.text.trim();
      // Find JSON object in response
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final jsonStr = text.substring(start, end + 1);
        final decoded = json.decode(jsonStr);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {
      // Return null if parsing fails
    }

    return null;
  }

  /// Generates a summary of the conversation.
  Future<String> summarizeConversation() async {
    final messages = context.messages;
    if (messages.isEmpty) return '';

    final summaryPrompt = '''
Please provide a brief summary of the following conversation:

${messages.map((m) => '${m.role.name}: ${m.text}').join('\n')}

Summary:''';

    final response = await chat(summaryPrompt, addToContext: false);
    return response.text;
  }

  /// Checks if the provider supports a capability.
  bool hasCapability(ModelCapability capability) =>
      _provider.hasCapability(capability);
}
