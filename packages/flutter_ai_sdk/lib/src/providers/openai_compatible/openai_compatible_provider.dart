import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/embeddings/embeddings.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/base_provider.dart';
import 'package:flutter_ai_sdk/src/providers/openai/openai_mapper.dart';
import 'package:flutter_ai_sdk/src/utils/http_client.dart';
import 'package:meta/meta.dart';

/// Base for providers that expose an OpenAI-compatible chat completions API
/// (identical request/response wire format, different endpoint and models).
///
/// Used by `MistralProvider`, `XAIProvider`, `DeepSeekProvider` and
/// `OpenRouterProvider` — each is a thin subclass that only fixes the
/// endpoint, default model and capabilities; the request building, response
/// parsing and SSE decoding are all reused from [OpenAIMapper] unchanged.
abstract class OpenAICompatibleProvider extends BaseProvider {
  /// Creates an [OpenAICompatibleProvider].
  ///
  /// A custom HTTP [client] can be injected, mainly for testing.
  OpenAICompatibleProvider(
    super.config, {
    required this.providerType,
    required this.defaultModel,
    required this.capabilities,
    required String defaultBaseUrl,
    AIHttpClient? client,
  })  : _defaultBaseUrl = defaultBaseUrl,
        _client = client ?? AIHttpClient(config);

  @override
  final AIProvider providerType;

  @override
  final String defaultModel;

  @override
  final Set<ModelCapability> capabilities;

  final String _defaultBaseUrl;
  final AIHttpClient _client;

  static const OpenAIMapper _mapper = OpenAIMapper();

  /// Chat completions endpoint, honoring a custom [AIConfig.baseUrl].
  String get _chatEndpoint =>
      '${config.baseUrl ?? _defaultBaseUrl}/chat/completions';

  @override
  Future<AIResponse> chat(List<Message> messages) async {
    validateConfig();

    final body = _mapper.buildRequestBody(
      messages,
      config: config,
      model: model,
      stream: false,
    )..addAll(extraRequestFields);
    final response = await _client.post(_chatEndpoint, body: body);

    return _mapper.parseResponse(
      response.data as Map<String, dynamic>,
      provider: providerType,
    );
  }

  @override
  Stream<String> openStream(List<Message> messages) {
    final body = _mapper.buildRequestBody(
      messages,
      config: config,
      model: model,
      stream: true,
    )..addAll(extraRequestFields);
    return _client.postStream(_chatEndpoint, body: body);
  }

  /// Extra top-level fields merged into every request body.
  ///
  /// Lets subclasses opt into non-standard fields (e.g. DeepSeek's
  /// `thinking`) without the shared [OpenAIMapper] knowing about them.
  @protected
  Map<String, dynamic> get extraRequestFields => const {};

  @override
  StreamChunk? parseStreamChunk(String rawChunk) =>
      _mapper.parseStreamChunk(rawChunk);

  @override
  void dispose() {
    _client.dispose();
  }

  /// Sends an embeddings request via the shared OpenAI-compatible wire
  /// format.
  ///
  /// Not every OpenAI-compatible provider exposes an embeddings endpoint,
  /// so this is intentionally not part of the public `EmbeddingProvider`
  /// contract on this base class — only the subclasses that do (currently
  /// Mistral) implement that interface and delegate to this helper.
  @protected
  Future<EmbeddingResponse> embedViaMapper(
    List<String> input, {
    required String model,
  }) async {
    validateConfig();

    final body = _mapper.buildEmbeddingRequestBody(input, model: model);
    final response = await _client.post(
      '${config.baseUrl ?? _defaultBaseUrl}/embeddings',
      body: body,
    );

    return _mapper.parseEmbeddingResponse(
      response.data as Map<String, dynamic>,
    );
  }
}
