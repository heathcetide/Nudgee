import 'package:flutter_ai_sdk/src/models/enums.dart';

/// Default models for each provider.
class DefaultModels {
  DefaultModels._();

  /// Default OpenAI model.
  static const String openai = 'gpt-5.5';

  /// Default Anthropic model.
  static const String anthropic = 'claude-opus-4-8';

  /// Default Google AI model.
  static const String googleAI = 'gemini-3.5-flash';

  /// Default Ollama model.
  static const String ollama = 'llama3.1';

  /// Default Mistral AI model.
  static const String mistral = 'mistral-large-latest';

  /// Default xAI model.
  static const String xai = 'grok-4.5';

  /// Default DeepSeek model.
  static const String deepseek = 'deepseek-v4-flash';

  /// Default OpenRouter model.
  static const String openrouter = 'openrouter/auto';

  /// Default OpenAI embedding model.
  static const String openaiEmbedding = 'text-embedding-3-small';

  /// Default Google AI embedding model.
  static const String googleAIEmbedding = 'gemini-embedding-001';

  /// Default Ollama embedding model.
  static const String ollamaEmbedding = 'embeddinggemma';

  /// Default Mistral embedding model.
  static const String mistralEmbedding = 'mistral-embed';

  /// Gets the default model for a provider.
  static String forProvider(AIProvider provider) => switch (provider) {
        AIProvider.openai => openai,
        AIProvider.anthropic => anthropic,
        AIProvider.googleAI => googleAI,
        AIProvider.ollama => ollama,
        AIProvider.mistral => mistral,
        AIProvider.xai => xai,
        AIProvider.deepseek => deepseek,
        AIProvider.openrouter => openrouter,
      };
}

/// API endpoints for each provider.
class APIEndpoints {
  APIEndpoints._();

  /// OpenAI API base URL.
  static const String openai = 'https://api.openai.com/v1';

  /// Anthropic API base URL.
  static const String anthropic = 'https://api.anthropic.com/v1';

  /// Google AI API base URL.
  static const String googleAI =
      'https://generativelanguage.googleapis.com/v1beta';

  /// Ollama API base URL (local server).
  static const String ollama = 'http://localhost:11434/api';

  /// Mistral AI API base URL.
  static const String mistral = 'https://api.mistral.ai/v1';

  /// xAI API base URL.
  static const String xai = 'https://api.x.ai/v1';

  /// DeepSeek API base URL (no `/v1` segment).
  static const String deepseek = 'https://api.deepseek.com';

  /// OpenRouter API base URL.
  static const String openrouter = 'https://openrouter.ai/api/v1';

  /// Gets the default endpoint for a provider.
  static String forProvider(AIProvider provider) => switch (provider) {
        AIProvider.openai => openai,
        AIProvider.anthropic => anthropic,
        AIProvider.googleAI => googleAI,
        AIProvider.ollama => ollama,
        AIProvider.mistral => mistral,
        AIProvider.xai => xai,
        AIProvider.deepseek => deepseek,
        AIProvider.openrouter => openrouter,
      };
}
