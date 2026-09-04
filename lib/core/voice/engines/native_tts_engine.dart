/// Native TTS engine — uses the platform's built-in text-to-speech
/// via the `flutter_tts` Flutter package.
///
/// This is the fallback engine that works without any cloud API keys.
/// Supports Android, iOS, macOS, and Web.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:nudgee/core/voice/tts_engine.dart';
import 'package:nudgee/core/voice/voice_types.dart';

class NativeTtsEngine extends TtsEngine {
  final TtsConfig _config;
  final FlutterTts _flutterTts = FlutterTts();

  NativeTtsEngine(this._config) {
    _initTts();
  }

  void _initTts() {
    _flutterTts.setStartHandler(() {
      debugPrint('[NativeTts] started');
    });
    _flutterTts.setCompletionHandler(() {
      debugPrint('[NativeTts] completed');
    });
    _flutterTts.setErrorHandler((error) {
      debugPrint('[NativeTts] error: $error');
    });

    // Apply config
    _flutterTts.setLanguage(_config.appId.isNotEmpty ? _config.appId : 'zh-CN');
    _flutterTts.setSpeechRate((_config.speedRatio - 1.0).clamp(-1.0, 1.0));
    _flutterTts.setVolume(_config.volumeRatio.clamp(0.0, 1.0));
    _flutterTts.setPitch((_config.pitchRatio - 1.0).clamp(-0.5, 0.5));
  }

  @override
  TtsProvider get provider => TtsProvider.native;

  @override
  AudioFormat get outputFormat => _config.audioFormat;

  @override
  Future<Uint8List> synthesize({
    required String text,
    TtsAudioCallback? onAudio,
  }) async {
    // Native TTS plays directly through the speaker — no raw audio bytes.
    // We synthesize and return empty bytes.
    await _flutterTts.speak(text);
    return Uint8List(0);
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }

  @override
  void dispose() {
    _flutterTts.stop();
  }
}
