import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/openai_compatible/openai_compatible_provider.dart';

/// xAI provider implementation (Grok family).
///
/// xAI exposes an OpenAI-compatible chat completions API, so this provider
/// only fixes the endpoint, default model and capabilities and reuses the
/// shared OpenAI wire-format mapper.
///
/// Example:
/// ```dart
/// final provider = XAIProvider(
///   AIConfig(
///     apiKey: '...',
///     model: 'grok-4.5',
///   ),
/// );
///
/// final response = await provider.chat([
///   Message.user('Hello!'),
/// ]);
/// ```
class XAIProvider extends OpenAICompatibleProvider {
  /// Creates an [XAIProvider].
  ///
  /// A custom HTTP [client] can be injected, mainly for testing.
  XAIProvider(super.config, {super.client})
      : super(
          providerType: AIProvider.xai,
          defaultModel: DefaultModels.xai,
          defaultBaseUrl: APIEndpoints.xai,
          capabilities: const {
            ModelCapability.text,
            ModelCapability.vision,
            ModelCapability.tools,
            ModelCapability.jsonMode,
            ModelCapability.streaming,
            ModelCapability.systemPrompt,
          },
        );
}
