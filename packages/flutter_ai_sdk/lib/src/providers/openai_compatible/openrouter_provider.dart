import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/openai_compatible/openai_compatible_provider.dart';

/// OpenRouter provider implementation.
///
/// OpenRouter exposes an OpenAI-compatible chat completions API that routes
/// requests to many underlying models, so this provider only fixes the
/// endpoint, default model and capabilities and reuses the shared OpenAI
/// wire-format mapper. Vision support depends on the routed model and isn't
/// guaranteed, so it's omitted from the declared capabilities.
///
/// To identify your app on OpenRouter's leaderboards, pass the optional
/// `HTTP-Referer` and `X-OpenRouter-Title` headers via [AIConfig.headers].
///
/// Example:
/// ```dart
/// final provider = OpenRouterProvider(
///   AIConfig(
///     apiKey: '...',
///     model: 'openrouter/auto',
///   ),
/// );
///
/// final response = await provider.chat([
///   Message.user('Hello!'),
/// ]);
/// ```
class OpenRouterProvider extends OpenAICompatibleProvider {
  /// Creates an [OpenRouterProvider].
  ///
  /// A custom HTTP [client] can be injected, mainly for testing.
  OpenRouterProvider(super.config, {super.client})
      : super(
          providerType: AIProvider.openrouter,
          defaultModel: DefaultModels.openrouter,
          defaultBaseUrl: APIEndpoints.openrouter,
          capabilities: const {
            ModelCapability.text,
            ModelCapability.tools,
            ModelCapability.jsonMode,
            ModelCapability.streaming,
            ModelCapability.systemPrompt,
          },
        );
}
