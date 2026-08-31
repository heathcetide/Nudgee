import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nudgee/core/config/app_config.dart';

/// Centralized AI service wrapping [FlutterAI] SDK.
///
/// Reads config from [AppConfig.ai] (loaded from `config.yaml`).
/// Supports streaming chat, context management, model switching, and clear/reset.
class AiService {
  FlutterAI? _ai;
  bool _initialized = false;
  String _currentModel = '';
  List<String> _availableModels = [];

  /// SharedPreferences key for persisted model selection.
  static const String _modelKey = 'ai_selected_model';

  /// Whether the AI service is configured and ready.
  bool get isConfigured => _ai != null;

  /// The currently selected model.
  String get currentModel => _currentModel;

  /// Available models (either fetched from API or fallback defaults).
  List<String> get availableModels => _availableModels;

  /// Initialize from [AppConfig]. Safe to call multiple times.
  void init() {
    if (_initialized) return;
    _initialized = true;

    final cfg = AppConfig.ai;
    if (cfg == null || cfg.apiKey.isEmpty) {
      debugPrint('[AiService] No valid AI config found, service disabled');
      return;
    }

    _currentModel = cfg.model;
    _recreateAi();

    // Load persisted model preference (async, non-blocking).
    _loadPersistedModel();

    // Fetch available models from API (async, non-blocking).
    _fetchModels();

    debugPrint('[AiService] Initialized with provider=${cfg.provider}, model=$_currentModel');
  }

  /// Load persisted model from SharedPreferences.
  Future<void> _loadPersistedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_modelKey);
      if (saved != null && saved.isNotEmpty) {
        _currentModel = saved;
        _recreateAi();
      }
    } catch (e) {
      debugPrint('[AiService] Failed to load persisted model: $e');
    }
  }

  /// Fetch available models from the /v1/models endpoint.
  Future<void> _fetchModels() async {
    final cfg = AppConfig.ai;
    if (cfg == null || cfg.baseUrl == null) return;

    try {
      final url = '${cfg.baseUrl}/models';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${cfg.apiKey}'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        final models = data
            .map((m) => (m is Map<String, dynamic> ? m['id'] : null) as String?)
            .whereType<String>()
            .toList();

        if (models.isNotEmpty) {
          _availableModels = models;
          debugPrint('[AiService] Fetched ${models.length} models from API');
        }
      }
    } catch (e) {
      debugPrint('[AiService] Failed to fetch models: $e');
    }

    // Fallback defaults if fetch failed or returned empty.
    if (_availableModels.isEmpty) {
      _availableModels = _defaultModels;
    }
  }

  /// Default model list (used when API fetch fails).
  static const List<String> _defaultModels = [
    'gpt-5.5',
    'gpt-5.4',
    'gpt-5.4-mini',
    'gpt-5.6-luna',
    'gpt-5.6-sol',
    'gpt-5.6-terra',
    'grok-4.5',
    'grok-4.6',
  ];

  /// Switch to a different model. Recreates the [FlutterAI] instance.
  Future<void> switchModel(String model) async {
    if (model == _currentModel) return;
    _currentModel = model;
    _recreateAi();

    // Persist the selection.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelKey, model);
    } catch (e) {
      debugPrint('[AiService] Failed to persist model: $e');
    }

    debugPrint('[AiService] Switched to model: $model');
  }

  /// Recreate the [FlutterAI] instance with the current model.
  void _recreateAi() {
    final cfg = AppConfig.ai;
    if (cfg == null) return;

    _ai?.dispose();

    try {
      final provider = _parseProvider(cfg.provider);
      _ai = FlutterAI(
        provider: provider,
        config: AIConfig(
          apiKey: cfg.apiKey,
          model: _currentModel,
          baseUrl: cfg.baseUrl,
          systemPrompt: cfg.systemPrompt,
          temperature: 0.7,
          maxTokens: 4096,
        ),
      );
    } catch (e) {
      debugPrint('[AiService] Recreate failed: $e');
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
        return AIProvider.openai;
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
