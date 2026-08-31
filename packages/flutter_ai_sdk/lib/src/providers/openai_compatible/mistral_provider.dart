import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/embeddings/embeddings.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/openai_compatible/openai_compatible_provider.dart';

/// Mistral AI provider implementation.
///
/// Mistral exposes an OpenAI-compatible chat completions API, so this
/// provider only fixes the endpoint, default model and capabilities and
/// reuses the shared OpenAI wire-format mapper.
///
/// Example:
/// ```dart
/// final provider = MistralProvider(
///   AIConfig(
///     apiKey: '...',
///     model: 'mistral-large-latest',
///   ),
/// );
///
/// final response = await provider.chat([
///   Message.user('Hello!'),
/// ]);
/// ```
class MistralProvider extends OpenAICompatibleProvider
    implements EmbeddingProvider {
  /// Creates a [MistralProvider].
  ///
  /// A custom HTTP [client] can be injected, mainly for testing.
  MistralProvider(super.config, {super.client})
      : super(
          providerType: AIProvider.mistral,
          defaultModel: DefaultModels.mistral,
          defaultBaseUrl: APIEndpoints.mistral,
          capabilities: const {
            ModelCapability.text,
            ModelCapability.vision,
            ModelCapability.tools,
            ModelCapability.jsonMode,
            ModelCapability.streaming,
            ModelCapability.systemPrompt,
          },
        );

  @override
  Future<EmbeddingResponse> embed(EmbeddingRequest request) => embedViaMapper(
        request.input,
        model: request.model ?? DefaultModels.mistralEmbedding,
      );
}
