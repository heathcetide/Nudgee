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

/// Mistral AI API client.
///
/// Mistral uses an OpenAI-compatible API format.
/// Supports Mistral Large, Medium, Small, and Codestral models.
///
/// Example:
/// ```dart
/// final client = MistralClient(apiKey: '...');
/// ```
class MistralClient extends OpenAICompatibleClient {
  /// Creates a [MistralClient].
  MistralClient({
    required super.apiKey,
    super.baseUrl = 'https://api.mistral.ai/v1',
    super.defaultModel = 'mistral-large-latest',
    super.httpClient,
    super.timeout,
  });

  @override
  List<String> availableModels() => const [
        'mistral-large-latest',
        'mistral-medium-latest',
        'mistral-small-latest',
        'mistral-tiny',
        'codestral-latest',
        'mistral-embed',
        'open-mistral-7b',
        'open-mixtral-8x7b',
        'open-mixtral-8x22b',
      ];
}

/// xAI (Grok) API client.
///
/// xAI uses an OpenAI-compatible API format.
/// Supports Grok models with real-time information access.
///
/// Example:
/// ```dart
/// final client = XAIClient(apiKey: 'xai-...');
/// ```
class XAIClient extends OpenAICompatibleClient {
  /// Creates a [XAIClient].
  XAIClient({
    required super.apiKey,
    super.baseUrl = 'https://api.x.ai/v1',
    super.defaultModel = 'grok-4',
    super.httpClient,
    super.timeout,
  });

  @override
  List<String> availableModels() => const [
        'grok-4',
        'grok-4-mini',
        'grok-3',
        'grok-3-mini',
        'grok-2',
        'grok-2-vision',
        'grok-beta',
        'grok-vision-beta',
      ];
}

/// Ollama API client (local models).
///
/// Ollama runs locally and does not require an API key.
/// Pass any non-empty string as [apiKey] (it will be ignored).
/// Set [baseUrl] to your Ollama server URL (default: localhost:11434).
///
/// Supports any model installed on the Ollama server:
/// - Llama 3.1, 3.2, 3.3
/// - Qwen 2.5
/// - Mistral
/// - Phi-3
/// - Gemma 2
/// - DeepSeek-R1
/// - And many more
///
/// Example:
/// ```dart
/// final client = OllamaClient(
///   apiKey: '', // not required
///   baseUrl: 'http://localhost:11434/v1',
///   defaultModel: 'llama3.2',
/// );
/// ```
class OllamaClient extends OpenAICompatibleClient {
  /// Creates an [OllamaClient].
  OllamaClient({
    super.apiKey = 'ollama',
    super.baseUrl = 'http://localhost:11434/v1',
    super.defaultModel = 'llama3.2',
    super.httpClient,
    super.timeout = const Duration(minutes: 5),
  });

  @override
  List<String> availableModels() => const [
        'llama3.3',
        'llama3.2',
        'llama3.1',
        'qwen2.5',
        'qwen2.5-coder',
        'mistral',
        'phi3',
        'gemma2',
        'deepseek-r1',
        'nomic-embed-text',
      ];
}

/// Groq API client (ultra-fast inference).
///
/// Groq uses an OpenAI-compatible API format and provides
/// extremely fast inference for open-source models.
///
/// Example:
/// ```dart
/// final client = GroqClient(apiKey: 'gsk_...');
/// ```
class GroqClient extends OpenAICompatibleClient {
  /// Creates a [GroqClient].
  GroqClient({
    required super.apiKey,
    super.baseUrl = 'https://api.groq.com/openai/v1',
    super.defaultModel = 'llama-3.3-70b-versatile',
    super.httpClient,
    super.timeout,
  });

  @override
  List<String> availableModels() => const [
        'llama-3.3-70b-versatile',
        'llama-3.1-8b-instant',
        'llama-3.1-70b-versatile',
        'mixtral-8x7b-32768',
        'gemma2-9b-it',
      ];
}

/// Together AI API client.
///
/// Together AI provides OpenAI-compatible access to many open-source models.
///
/// Example:
/// ```dart
/// final client = TogetherClient(apiKey: '...');
/// ```
class TogetherClient extends OpenAICompatibleClient {
  /// Creates a [TogetherClient].
  TogetherClient({
    required super.apiKey,
    super.baseUrl = 'https://api.together.xyz/v1',
    super.defaultModel = 'meta-llama/Llama-3-70b-chat-hf',
    super.httpClient,
    super.timeout,
  });

  @override
  List<String> availableModels() => const [
        'meta-llama/Llama-3-70b-chat-hf',
        'meta-llama/Llama-3-8b-chat-hf',
        'mistralai/Mixtral-8x7B-Instruct-v0.1',
        'Qwen/Qwen2.5-72B-Instruct-Turbo',
        'deepseek-ai/DeepSeek-V3',
      ];
}

/// Moonshot AI (Kimi) API client.
///
/// Moonshot uses an OpenAI-compatible API format.
/// Supports Kimi models with long context windows.
///
/// Example:
/// ```dart
/// final client = MoonshotClient(apiKey: 'sk-...');
/// ```
class MoonshotClient extends OpenAICompatibleClient {
  /// Creates a [MoonshotClient].
  MoonshotClient({
    required super.apiKey,
    super.baseUrl = 'https://api.moonshot.cn/v1',
    super.defaultModel = 'moonshot-v1-8k',
    super.httpClient,
    super.timeout,
  });

  @override
  List<String> availableModels() => const [
        'moonshot-v1-8k',
        'moonshot-v1-32k',
        'moonshot-v1-128k',
        'moonshot-v1-auto',
      ];
}

/// Zhipu AI (ChatGLM) API client.
///
/// Zhipu uses an OpenAI-compatible API format.
/// Supports GLM-4 model family.
///
/// Example:
/// ```dart
/// final client = ZhipuClient(apiKey: '...');
/// ```
class ZhipuClient extends OpenAICompatibleClient {
  /// Creates a [ZhipuClient].
  ZhipuClient({
    required super.apiKey,
    super.baseUrl = 'https://open.bigmodel.cn/api/paas/v4',
    super.defaultModel = 'glm-4',
    super.httpClient,
    super.timeout,
  });

  @override
  List<String> availableModels() => const [
        'glm-4',
        'glm-4-air',
        'glm-4-flash',
        'glm-4-long',
        'glm-4v',
        'glm-3-turbo',
      ];
}

/// SiliconFlow API client.
///
/// SiliconFlow provides OpenAI-compatible access to many models
/// with generous free tier.
///
/// Example:
/// ```dart
/// final client = SiliconFlowClient(apiKey: 'sk-...');
/// ```
class SiliconFlowClient extends OpenAICompatibleClient {
  /// Creates a [SiliconFlowClient].
  SiliconFlowClient({
    required super.apiKey,
    super.baseUrl = 'https://api.siliconflow.cn/v1',
    super.defaultModel = 'deepseek-ai/DeepSeek-V3',
    super.httpClient,
    super.timeout,
  });

  @override
  List<String> availableModels() => const [
        'deepseek-ai/DeepSeek-V3',
        'deepseek-ai/DeepSeek-R1',
        'Qwen/Qwen2.5-72B-Instruct',
        'meta-llama/Meta-Llama-3.1-405B-Instruct',
        'google/gemma-2-27b-it',
      ];
}
