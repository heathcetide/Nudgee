/// LLM provider clients — unified interface for multiple AI APIs.
///
/// All providers implement [LLMClient], so they can be swapped
/// without changing agent code.
///
/// OpenAI-compatible providers (same API format):
/// - [OpenAIClient] — OpenAI GPT models (gpt-4o, o1, o3, etc.)
/// - [DeepSeekClientV2] — DeepSeek (deepseek-chat, deepseek-reasoner)
/// - [QiniuClient] — Qiniu Cloud LLM gateway (multi-model)
/// - [OpenRouterClient] — OpenRouter (100+ models)
/// - [MistralClient] — Mistral AI (Mistral Large, Codestral, etc.)
/// - [XAIClient] — xAI Grok models
/// - [OllamaClient] — Ollama local models (no API key needed)
/// - [GroqClient] — Groq ultra-fast inference
/// - [TogetherClient] — Together AI (open-source models)
/// - [MoonshotClient] — Moonshot AI (Kimi, long context)
/// - [ZhipuClient] — Zhipu AI (ChatGLM)
/// - [SiliconFlowClient] — SiliconFlow (free tier, many models)
///
/// Independent API format providers:
/// - [AnthropicClient] — Anthropic Claude (different API format)
/// - [GoogleAIClient] — Google AI Gemini (different API format)
///
/// Usage:
/// ```dart
/// final client = OpenAIClient(apiKey: 'sk-...');
/// // or
/// final client = GoogleAIClient(apiKey: 'AIza...');
/// // or
/// final client = OllamaClient(baseUrl: 'http://localhost:11434/v1');
/// ```
library;

export 'package:nudgee/core/agent/providers/llm_client.dart';
export 'package:nudgee/core/agent/providers/openai_compatible_client.dart';
export 'package:nudgee/core/agent/providers/openai_providers.dart';
export 'package:nudgee/core/agent/providers/anthropic_client.dart';
export 'package:nudgee/core/agent/providers/google_ai_client.dart';

// Keep the original DeepSeekClient for backward compatibility.
export 'package:nudgee/core/agent/providers/deepseek_client.dart';
