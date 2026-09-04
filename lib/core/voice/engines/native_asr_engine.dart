/// Native ASR engine — uses the platform's built-in speech recognition
/// via the `speech_to_text` Flutter package.
///
/// This is the fallback engine that works without any cloud API keys.
/// Supports Android, iOS, macOS, and Web.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:nudgee/core/voice/asr_engine.dart';
import 'package:nudgee/core/voice/voice_types.dart';

class NativeAsrEngine extends AsrEngine {
  final AsrConfig _config;
  final stt.SpeechToText _stt = stt.SpeechToText();

  AsrResultCallback? _onResult;
  AsrErrorCallback? _onError;
  bool _connected = false;
  String _currentLocale = 'zh-CN';

  NativeAsrEngine(this._config) {
    _currentLocale = _config.language;
  }

  @override
  AsrVendor get vendor => AsrVendor.native;

  @override
  void init(AsrResultCallback onResult, AsrErrorCallback onError) {
    _onResult = onResult;
    _onError = onError;
  }

  @override
  Future<void> connect(String dialogId) async {
    final available = await _stt.initialize(
      onError: (error) {
        debugPrint('[NativeAsr] error: $error');
        _onError?.call(error, false);
      },
      onStatus: (status) {
        debugPrint('[NativeAsr] status: $status');
        if (status == 'done' || status == 'notListening') {
          _connected = false;
        }
      },
    );

    if (!available) {
      _onError?.call('Speech recognition not available on this device', true);
      return;
    }

    _connected = true;

    await _stt.listen(
      localeId: _currentLocale,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      onResult: (result) {
        _onResult?.call(AsrResult(
          text: result.recognizedWords,
          isFinal: result.finalResult,
          dialogId: dialogId,
        ));
      },
    );
  }

  @override
  bool get isActive => _connected && _stt.isListening;

  @override
  Future<void> sendAudio(Uint8List data) async {
    // Native speech_to_text manages its own audio capture from the mic.
    // Audio data sent here is ignored — the engine listens directly.
  }

  @override
  Future<void> sendEnd() async {
    await _stt.stop();
    _connected = false;
  }

  @override
  Future<void> stop() async {
    await _stt.stop();
    _connected = false;
  }

  @override
  void dispose() {
    _stt.stop();
  }
}
