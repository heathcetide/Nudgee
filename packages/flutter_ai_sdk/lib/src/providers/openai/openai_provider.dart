import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter_ai_sdk/src/batch/batch.dart';
import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/embeddings/embeddings.dart';
import 'package:flutter_ai_sdk/src/errors/errors.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/base_provider.dart';
import 'package:flutter_ai_sdk/src/providers/openai/openai_mapper.dart';
import 'package:flutter_ai_sdk/src/utils/http_client.dart';

/// OpenAI API provider implementation.
///
/// Supports GPT-5.x and other OpenAI models with full
/// support for streaming, vision, and function calling.
///
/// Example:
/// ```dart
/// final provider = OpenAIProvider(
///   AIConfig(
///     apiKey: 'sk-...',
///     model: 'gpt-5.5',
///   ),
/// );
///
/// final response = await provider.chat([
///   Message.user('Hello!'),
/// ]);
/// ```
class OpenAIProvider extends BaseProvider
    implements EmbeddingProvider, BatchProvider {
  /// Creates an [OpenAIProvider].
  ///
  /// A custom HTTP [client] can be injected, mainly for testing.
  OpenAIProvider(super.config, {AIHttpClient? client})
      : _client = client ?? AIHttpClient(config);

  final AIHttpClient _client;

  static const OpenAIMapper _mapper = OpenAIMapper();

  @override
  AIProvider get providerType => AIProvider.openai;

  @override
  String get defaultModel => DefaultModels.openai;

  @override
  Set<ModelCapability> get capabilities => {
        ModelCapability.text,
        ModelCapability.vision,
        ModelCapability.tools,
        ModelCapability.jsonMode,
        ModelCapability.streaming,
        ModelCapability.systemPrompt,
      };

  /// OpenAI API endpoint for chat completions.
  String get _chatEndpoint {
    final base = config.baseUrl ?? APIEndpoints.openai;
    return '$base/chat/completions';
  }

  @override
  Future<AIResponse> chat(List<Message> messages) async {
    validateConfig();

    final body = _mapper.buildRequestBody(
      messages,
      config: config,
      model: model,
      stream: false,
    );
    final response = await _client.post(_chatEndpoint, body: body);

    return _mapper.parseResponse(response.data as Map<String, dynamic>);
  }

  @override
  Stream<String> openStream(List<Message> messages) {
    final body = _mapper.buildRequestBody(
      messages,
      config: config,
      model: model,
      stream: true,
    );
    return _client.postStream(_chatEndpoint, body: body);
  }

  @override
  StreamChunk? parseStreamChunk(String rawChunk) =>
      _mapper.parseStreamChunk(rawChunk);

  /// OpenAI API endpoint for embeddings.
  String get _embeddingsEndpoint {
    final base = config.baseUrl ?? APIEndpoints.openai;
    return '$base/embeddings';
  }

  @override
  Future<EmbeddingResponse> embed(EmbeddingRequest request) async {
    validateConfig();

    final body = _mapper.buildEmbeddingRequestBody(
      request.input,
      model: request.model ?? DefaultModels.openaiEmbedding,
    );
    final response = await _client.post(_embeddingsEndpoint, body: body);

    return _mapper
        .parseEmbeddingResponse(response.data as Map<String, dynamic>);
  }

  @override
  void dispose() {
    _client.dispose();
  }

  /// OpenAI API endpoint for file uploads.
  String get _filesEndpoint {
    final base = config.baseUrl ?? APIEndpoints.openai;
    return '$base/files';
  }

  /// OpenAI API endpoint for batch jobs.
  String get _batchesEndpoint {
    final base = config.baseUrl ?? APIEndpoints.openai;
    return '$base/batches';
  }

  @override
  Future<BatchJob> submitBatch(List<BatchRequest> requests) async {
    validateConfig();

    final jsonl = _mapper.buildBatchJsonl(requests, defaultModel: defaultModel);
    final formData = FormData.fromMap({
      'purpose': 'batch',
      'file': MultipartFile.fromBytes(
        utf8.encode(jsonl),
        filename: 'batch.jsonl',
      ),
    });
    final fileResponse = await _client.postMultipart(
      _filesEndpoint,
      formData: formData,
    );
    final fileId = (fileResponse.data as Map<String, dynamic>)['id'] as String;

    final batchResponse = await _client.post(
      _batchesEndpoint,
      body: {
        'input_file_id': fileId,
        'endpoint': '/v1/chat/completions',
        'completion_window': '24h',
      },
    );

    return _mapper.parseBatchJob(batchResponse.data as Map<String, dynamic>);
  }

  @override
  Future<BatchJob> getBatchStatus(String batchId) async {
    validateConfig();

    final response = await _client.get('$_batchesEndpoint/$batchId');

    return _mapper.parseBatchJob(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<BatchResult>> getBatchResults(String batchId) async {
    validateConfig();

    final job = await getBatchStatus(batchId);
    final raw = job.metadata?['raw'] as Map<String, dynamic>?;
    final outputFileId = raw?['output_file_id'] as String?;
    if (outputFileId == null) {
      throw const AIModelError(
        message: 'Batch has no output file yet — is it terminal?',
        code: 'batch_not_ready',
      );
    }

    final response = await _client.get('$_filesEndpoint/$outputFileId/content');

    return _mapper.parseBatchResults(response.data as String);
  }
}
