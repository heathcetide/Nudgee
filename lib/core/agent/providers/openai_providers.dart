import 'package:nudgee/core/agent/providers/openai_compatible_client.dart';

/// OpenAI API client (GPT-4o, GPT-5, o1, o3, etc.).
///
/// Uses the OpenAI chat completions endpoint with full support for:
/// - Streaming text content
/// - Streaming thinking/reasoning content (o1, o3 models)
/// - Streaming tool calls
/// - Token usage reporting
///
/// Example:
/// ```dart
/// final client = OpenAIClient(apiKey: 'sk-...');
/// final response = await client.chat(
///   messages: [LlmMessage.user('Hello')],
///   model: 'gpt-4o',
/// );
/// ```
class OpenAIClient extends OpenAICompatibleClient {
  /// Creates an [OpenAIClient].
  OpenAIClient({
    required super.apiKey,
    super.baseUrl = 'https://api.openai.com/v1',
    super.defaultModel = 'gpt-4o',
    super.httpClient,
    super.timeout,
  });

  @override
  List<String> availableModels() => const [
        'gpt-4o',
        'gpt-4o-mini',
        'gpt-4-turbo',
        'gpt-4',
        'o1',
        'o1-mini',
        'o3',
        'o3-mini',
      ];
}

/// DeepSeek API client.
///
/// DeepSeek uses an OpenAI-compatible API format.
/// Supports deepseek-chat and deepseek-reasoner (with thinking content).
///
/// Example:
/// ```dart
/// final client = DeepSeekClient(apiKey: 'sk-...');
/// ```
class DeepSeekClientV2 extends OpenAICompatibleClient {
  /// Creates a [DeepSeekClientV2].
  DeepSeekClientV2({
    required super.apiKey,
    super.baseUrl = 'https://api.deepseek.com/v1',
    super.defaultModel = 'deepseek-chat',
    super.httpClient,
    super.timeout,
  });

  @override
  List<String> availableModels() => const [
        'deepseek-chat',
        'deepseek-reasoner',
      ];
}

/// Qiniu Cloud LLM gateway client.
///
/// Qiniu provides an OpenAI-compatible API gateway that routes
/// to multiple models (GPT, DeepSeek, Claude, etc.) through a single endpoint.
///
/// Example:
/// ```dart
/// final client = QiniuClient(
///   apiKey: 'sk-...',
///   model: 'gpt-5.4-mini',
/// );
/// ```
class QiniuClient extends OpenAICompatibleClient {
  /// Creates a [QiniuClient].
  QiniuClient({
    required super.apiKey,
    super.baseUrl = 'https://llmapi.qiniu.io/v1',
    super.defaultModel = 'gpt-5.4-mini',
    super.httpClient,
    super.timeout,
  });

  @override
  List<String> availableModels() => const [
        'gpt-5.4-mini',
        'gpt-4o',
        'gpt-4o-mini',
        'deepseek-chat',
        'deepseek-reasoner',
        'claude-3-5-sonnet',
        'qwen-plus',
      ];
}

/// OpenRouter API client.
///
/// OpenRouter provides access to 100+ models through a single
/// OpenAI-compatible API.
///
/// Example:
/// ```dart
/// final client = OpenRouterClient(
///   apiKey: 'sk-or-...',
///   model: 'anthropic/claude-3.5-sonnet',
/// );
/// ```
class OpenRouterClient extends OpenAICompatibleClient {
  /// Creates an [OpenRouterClient].
  OpenRouterClient({
    required super.apiKey,
    super.baseUrl = 'https://openrouter.ai/api/v1',
    super.defaultModel = 'openai/gpt-4o',
    super.httpClient,
    super.timeout,
  });

  @override
  List<String> availableModels() => const [
        'openai/gpt-4o',
        'openai/gpt-4o-mini',
        'anthropic/claude-3.5-sonnet',
        'google/gemini-flash-1.5',
        'meta-llama/llama-3.1-70b-instruct',
        'deepseek/deepseek-chat',
      ];
}
