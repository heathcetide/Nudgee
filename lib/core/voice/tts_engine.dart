/// TTS (Text-to-Speech) engine interface and factory.
///
/// Modeled after ling-base's `voice/synthesizer/` package.
/// Each vendor implementation registers with the factory via
/// [TtsEngineFactory.register].

import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/voice/voice_types.dart';

/// The core TTS engine interface that all vendors implement.
abstract class TtsEngine {
  /// The provider identifier.
  TtsProvider get provider;

  /// The audio output format.
  AudioFormat get outputFormat;

  /// Synthesizes [text] to speech.
  ///
  /// Audio chunks are delivered via [onAudio]. Returns the complete
  /// audio bytes when synthesis is finished (non-streaming engines
  /// return everything at once; streaming engines return empty list
  /// and deliver via callback).
  Future<Uint8List> synthesize({
    required String text,
    TtsAudioCallback? onAudio,
  });

  /// Stops any ongoing synthesis.
  Future<void> stop();

  /// Releases all resources.
  void dispose();
}

/// Factory that creates TTS engines by provider.
class TtsEngineFactory {
  static final TtsEngineFactory _instance = TtsEngineFactory._();
  static TtsEngineFactory get instance => _instance;
  TtsEngineFactory._();

  final Map<TtsProvider, TtsEngine Function(TtsConfig)> _creators = {};

  /// Registers a creator function for a provider.
  void register(TtsProvider provider, TtsEngine Function(TtsConfig) creator) {
    _creators[provider] = creator;
  }

  /// Creates a TTS engine for the given config.
  TtsEngine create(TtsConfig config) {
    final creator = _creators[config.provider];
    if (creator == null) {
      throw ArgumentError('TTS provider ${config.provider} not registered');
    }
    return creator(config);
  }

  /// Returns all registered providers.
  List<TtsProvider> get supportedProviders => _creators.keys.toList();

  /// Checks if a provider is registered.
  bool isSupported(TtsProvider provider) => _creators.containsKey(provider);
}

/// Convenience function to create a TTS engine.
TtsEngine createTtsEngine(TtsConfig config) =>
    TtsEngineFactory.instance.create(config);
