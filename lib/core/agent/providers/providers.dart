/// LLM provider clients — unified interface for multiple AI APIs.
///
/// All providers implement [LLMClient], so they can be swapped
/// without changing agent code.
///
/// Providers:
/// - [OpenAIClient] — OpenAI GPT models (gpt-4o, o1, o3, etc.)
/// - [DeepSeekClientV2] — DeepSeek (deepseek-chat, deepseek-reasoner)
/// - [QiniuClient] — Qiniu Cloud LLM gateway (multi-model)
/// - [OpenRouterClient] — OpenRouter (100+ models)
/// - [AnthropicClient] — Anthropic Claude (different API format)
///
/// Usage:
/// ```dart
/// final client = OpenAIClient(apiKey: 'sk-...');
/// // or
/// final client = AnthropicClient(apiKey: 'sk-ant-...');
/// // or
/// final client = QiniuClient(apiKey: 'sk-...', defaultModel: 'gpt-5.4-mini');
/// ```
library;

export 'package:nudgee/core/agent/providers/llm_client.dart';
export 'package:nudgee/core/agent/providers/openai_compatible_client.dart';
export 'package:nudgee/core/agent/providers/openai_providers.dart';
export 'package:nudgee/core/agent/providers/anthropic_client.dart';

// Keep the original DeepSeekClient for backward compatibility.
export 'package:nudgee/core/agent/providers/deepseek_client.dart';
