/// Voice service — unified management of ASR and TTS engines.
///
/// Provides a single entry point for voice features:
/// - [startListening] / [stopListening] for ASR
/// - [speak] / [stopSpeaking] for TTS
/// - Configuration-driven vendor/provider selection
///
/// Registers all built-in engines on construction.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'package:nudgee/core/voice/asr_engine.dart';
import 'package:nudgee/core/voice/tts_engine.dart';
import 'package:nudgee/core/voice/voice_types.dart';
import 'package:nudgee/core/voice/engines/native_asr_engine.dart';
import 'package:nudgee/core/voice/engines/native_tts_engine.dart';
import 'package:nudgee/core/voice/engines/openai_tts_engine.dart';
import 'package:nudgee/core/voice/engines/volcengine_asr_engine.dart';
import 'package:nudgee/core/voice/engines/volcengine_tts_engine.dart';

/// Voice service state.
enum VoiceState {
  idle,
  listening,
  speaking,
  error,
}

/// Configuration for the voice service.
class VoiceServiceConfig {
  final AsrConfig asrConfig;
  final TtsConfig ttsConfig;

  const VoiceServiceConfig({
    required this.asrConfig,
    required this.ttsConfig,
  });

  static const VoiceServiceConfig defaultConfig = VoiceServiceConfig(
    asrConfig: AsrConfig(vendor: AsrVendor.native),
    ttsConfig: TtsConfig(provider: TtsProvider.native),
  );
}

class VoiceService extends ChangeNotifier {
  final VoiceServiceConfig _config;
  AsrEngine? _asrEngine;
  TtsEngine? _ttsEngine;
  AudioPlayer? _audioPlayer;

  VoiceState _state = VoiceState.idle;
  String _partialText = '';
  String _finalText = '';
  String _lastError = '';

  VoiceState get state => _state;
  String get partialText => _partialText;
  String get finalText => _finalText;
  String get lastError => _lastError;
  bool get isListening => _state == VoiceState.listening;
  bool get isSpeaking => _state == VoiceState.speaking;

  VoiceService([this._config = VoiceServiceConfig.defaultConfig]) {
    _registerEngines();
    _createEngines();
  }

  /// Registers all built-in engine creators with the factories.
  void _registerEngines() {
    // ASR
    AsrEngineFactory.instance
        .register(AsrVendor.native, (c) => NativeAsrEngine(c));
    AsrEngineFactory.instance
        .register(AsrVendor.volcengine, (c) => VolcengineAsrEngine(c));
    // TTS
    TtsEngineFactory.instance
        .register(TtsProvider.native, (c) => NativeTtsEngine(c));
    TtsEngineFactory.instance
        .register(TtsProvider.openai, (c) => OpenAiTtsEngine(c));
    TtsEngineFactory.instance
        .register(TtsProvider.volcengine, (c) => VolcengineTtsEngine(c));
  }

  void _createEngines() {
    _asrEngine = AsrEngineFactory.instance.create(_config.asrConfig);
    _ttsEngine = TtsEngineFactory.instance.create(_config.ttsConfig);
  }

  /// Updates the ASR configuration and recreates the engine.
  void updateAsrConfig(AsrConfig config) {
    _asrEngine?.dispose();
    _asrEngine = AsrEngineFactory.instance.create(config);
    debugPrint('[VoiceService] ASR engine updated: ${config.vendor}');
  }

  /// Updates the TTS configuration and recreates the engine.
  void updateTtsConfig(TtsConfig config) {
    _ttsEngine?.dispose();
    _ttsEngine = TtsEngineFactory.instance.create(config);
    debugPrint('[VoiceService] TTS engine updated: ${config.provider}');
  }

  // ── ASR ──────────────────────────────────────────────────────────────

  /// Starts listening for speech recognition.
  ///
  /// For cloud engines (volcengine), this records audio from the mic
  /// and sends it to the ASR WebSocket. For native engine, the platform
  /// handles mic capture internally.
  ///
  /// [onResult] is called with partial and final results.
  Future<void> startListening({
    required AsrResultCallback onResult,
    AsrErrorCallback? onError,
  }) async {
    if (_state == VoiceState.listening) return;

    _partialText = '';
    _finalText = '';
    _setState(VoiceState.listening);

    final dialogId = DateTime.now().millisecondsSinceEpoch.toString();

    _asrEngine!.init(
      (result) {
        if (!result.isFinal) {
          _partialText = result.text;
        } else {
          _finalText = result.text;
          _partialText = '';
        }
        onResult(result);
        if (result.isFinal) {
          _setState(VoiceState.idle);
        }
      },
      (error, isFatal) {
        debugPrint('[VoiceService] ASR error: $error (fatal: $isFatal)');
        _lastError = error.toString();
        if (isFatal) _setState(VoiceState.error);
        onError?.call(error, isFatal);
      },
    );

    try {
      await _asrEngine!.connect(dialogId);

      // For cloud engines, we need to capture and send audio.
      if (_config.asrConfig.vendor != AsrVendor.native) {
        await _startAudioCapture();
      }
    } catch (e) {
      debugPrint('[VoiceService] startListening error: $e');
      _lastError = e.toString();
      _setState(VoiceState.error);
    }
  }

  /// Stops listening.
  Future<void> stopListening() async {
    try {
      await _asrEngine?.sendEnd();
      await _stopAudioCapture();
      await _asrEngine?.stop();
    } catch (e) {
      debugPrint('[VoiceService] stopListening error: $e');
    }
    _setState(VoiceState.idle);
  }

  Future<void> _startAudioCapture() async {
    // Cloud ASR engines (volcengine) require audio capture via the `record`
    // package. It's not included by default to avoid build issues on Linux.
    // To enable cloud ASR, add `record: 5.1.2` to pubspec.yaml and uncomment
    // the audio capture code below.
    //
    // final recorder = AudioRecorder();
    // if (!await recorder.hasPermission()) { ... }
    // final stream = await recorder.startStream(RecordConfig(...));
    // stream.listen((data) {
    //   if (_asrEngine!.isActive) _asrEngine!.sendAudio(Uint8List.fromList(data));
    // });
    debugPrint('[VoiceService] Cloud ASR audio capture not available '
        '(record package not installed). Use native ASR instead.');
  }

  Future<void> _stopAudioCapture() async {
    // No-op when record package is not installed.
  }

  // ── TTS ──────────────────────────────────────────────────────────────

  /// Synthesizes [text] to speech and plays it.
  ///
  /// For cloud engines (OpenAI, Volcengine), audio bytes are received
  /// and played via [just_audio]. For native engine, the platform TTS
  /// plays directly.
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (_state == VoiceState.speaking) await stopSpeaking();

    _setState(VoiceState.speaking);

    try {
      if (_config.ttsConfig.provider == TtsProvider.native) {
        // Native TTS plays directly through the speaker.
        await _ttsEngine!.synthesize(text: text);
        _setState(VoiceState.idle);
      } else {
        // Cloud TTS — get bytes and play via just_audio.
        final bytes = await _ttsEngine!.synthesize(text: text);
        if (bytes.isNotEmpty) {
          await _playAudioBytes(bytes);
        }
        _setState(VoiceState.idle);
      }
    } catch (e) {
      debugPrint('[VoiceService] speak error: $e');
      _lastError = e.toString();
      _setState(VoiceState.error);
    }
  }

  /// Stops any ongoing speech synthesis.
  Future<void> stopSpeaking() async {
    try {
      await _ttsEngine?.stop();
      await _audioPlayer?.stop();
    } catch (e) {
      debugPrint('[VoiceService] stopSpeaking error: $e');
    }
    _setState(VoiceState.idle);
  }

  Future<void> _playAudioBytes(Uint8List bytes) async {
    _audioPlayer ??= AudioPlayer();

    final format = _config.ttsConfig.audioFormat;

    if (format.codec == 'pcm') {
      // For PCM, we need to wrap in WAV header for just_audio.
      final wavBytes = _pcmToWav(bytes, format);
      final uri = Uri.dataFromBytes(wavBytes.toList(), mimeType: 'audio/wav');
      await _audioPlayer!.setAudioSource(AudioSource.uri(uri));
    } else {
      final mimeType = format.codec == 'mp3' ? 'audio/mpeg' : 'audio/wav';
      final uri = Uri.dataFromBytes(bytes.toList(), mimeType: mimeType);
      await _audioPlayer!.setAudioSource(AudioSource.uri(uri));
    }

    await _audioPlayer!.play();
    await _audioPlayer!.playerStateStream.firstWhere(
      (state) => state.processingState == ProcessingState.completed,
    );
  }

  /// Wraps raw PCM bytes in a WAV header for playback.
  Uint8List _pcmToWav(Uint8List pcm, AudioFormat format) {
    final dataSize = pcm.length;
    final headerSize = 44;
    final totalSize = headerSize + dataSize;

    final wav = Uint8List(totalSize);
    final view = ByteData.view(wav.buffer);

    // RIFF header
    view.setUint32(0, 0x52494646, Endian.big); // 'RIFF'
    view.setUint32(4, totalSize - 8, Endian.little);
    view.setUint32(8, 0x57415645, Endian.big); // 'WAVE'

    // fmt chunk
    view.setUint32(12, 0x666d7420, Endian.big); // 'fmt '
    view.setUint32(16, 16, Endian.little); // chunk size
    view.setUint16(20, 1, Endian.little); // audio format = PCM
    view.setUint16(22, format.channels, Endian.little);
    view.setUint32(24, format.sampleRate, Endian.little);
    view.setUint32(28, format.sampleRate * format.bytesPerSample, Endian.little);
    view.setUint16(32, format.bytesPerSample, Endian.little);
    view.setUint16(34, format.bitDepth, Endian.little);

    // data chunk
    view.setUint32(36, 0x64617461, Endian.big); // 'data'
    view.setUint32(40, dataSize, Endian.little);

    wav.setRange(44, totalSize, pcm);
    return wav;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────

  void _setState(VoiceState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _asrEngine?.dispose();
    _ttsEngine?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }
}
