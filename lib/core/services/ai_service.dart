import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';

import 'package:nudgee/core/config/app_config.dart';

/// Centralized AI service wrapping [FlutterAI] SDK.
///
/// Reads config from [AppConfig.ai] (loaded from `config.yaml`).
/// Supports streaming chat, context management, and clear/reset.
class AiService {
  FlutterAI? _ai;
  bool _initialized = false;

  /// Whether the AI service is configured and ready.
  bool get isConfigured => _ai != null;

  /// Initialize from [AppConfig]. Safe to call multiple times.
  void init() {
    if (_initialized) return;
    _initialized = true;

    final cfg = AppConfig.ai;
    if (cfg == null || cfg.apiKey.isEmpty || cfg.apiKey == 'YOUR_DEEPSEEK_API_KEY') {
      debugPrint('[AiService] No valid AI config found, service disabled');
      return;
    }

    try {
      final provider = _parseProvider(cfg.provider);
      _ai = FlutterAI(
        provider: provider,
        config: AIConfig(
          apiKey: cfg.apiKey,
          model: cfg.model,
          baseUrl: cfg.baseUrl,
          systemPrompt: cfg.systemPrompt,
          temperature: 0.7,
          maxTokens: 4096,
        ),
      );
      debugPrint('[AiService] Initialized with provider=${cfg.provider}, model=${cfg.model}');
    } catch (e) {
      debugPrint('[AiService] Init failed: $e');
    }
  }

  /// Parse provider string from config to [AIProvider] enum.
  AIProvider _parseProvider(String name) {
    switch (name.toLowerCase()) {
      case 'openai':
        return AIProvider.openai;
      case 'anthropic':
        return AIProvider.anthropic;
      case 'googleai':
      case 'google_ai':
      case 'google':
        return AIProvider.googleAI;
      case 'ollama':
        return AIProvider.ollama;
      case 'mistral':
        return AIProvider.mistral;
      case 'xai':
        return AIProvider.xai;
      case 'deepseek':
        return AIProvider.deepseek;
      case 'openrouter':
        return AIProvider.openrouter;
      default:
        return AIProvider.deepseek;
    }
  }

  /// Send a simple message and get a response.
  Future<String> chat(String message) async {
    if (_ai == null) throw StateError('AI service not configured');
    final response = await _ai!.chat(message);
    return response.text;
  }

  /// Stream a response. Yields text deltas as they arrive.
  Stream<String> streamChat(String message) async* {
    if (_ai == null) throw StateError('AI service not configured');
    await for (final chunk in _ai!.streamChat(message)) {
      if (chunk.isDelta && chunk.delta != null) {
        yield chunk.delta!;
      }
    }
  }

  /// Clear conversation context.
  void clearContext() {
    _ai?.clearContext();
  }

  /// Reset with optional new system prompt.
  void reset({String? systemPrompt}) {
    _ai?.reset(systemPrompt: systemPrompt);
  }

  /// Get conversation history.
  List<Message> get history => _ai?.history ?? [];

  /// Dispose resources.
  void dispose() {
    _ai?.dispose();
    _ai = null;
  }
}
