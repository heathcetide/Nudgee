import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/openai_compatible/openai_compatible_provider.dart';
import 'package:meta/meta.dart';

/// DeepSeek provider implementation.
///
/// DeepSeek exposes an OpenAI-compatible chat completions API, so this
/// provider only fixes the endpoint, default model and capabilities and
/// reuses the shared OpenAI wire-format mapper. DeepSeek doesn't support
/// vision.
///
/// Example:
/// ```dart
/// final provider = DeepSeekProvider(
///   AIConfig(
///     apiKey: '...',
///     model: 'deepseek-v4-flash',
///   ),
/// );
///
/// final response = await provider.chat([
///   Message.user('Hello!'),
/// ]);
/// ```
class DeepSeekProvider extends OpenAICompatibleProvider {
  /// Creates a [DeepSeekProvider].
  ///
  /// A custom HTTP [client] can be injected, mainly for testing.
  DeepSeekProvider(super.config, {super.client})
      : super(
          providerType: AIProvider.deepseek,
          defaultModel: DefaultModels.deepseek,
          defaultBaseUrl: APIEndpoints.deepseek,
          capabilities: const {
            ModelCapability.text,
            ModelCapability.tools,
            ModelCapability.jsonMode,
            ModelCapability.streaming,
            ModelCapability.systemPrompt,
            ModelCapability.thinking,
          },
        );

  // DeepSeek's v4 models require explicitly opting into `reasoning_content`
  // via a top-level `thinking` field — it isn't returned by default.
  @override
  @protected
  Map<String, dynamic> get extraRequestFields => config.thinking != null
      ? {
          'thinking': {'type': 'enabled'},
        }
      : const {};
}
