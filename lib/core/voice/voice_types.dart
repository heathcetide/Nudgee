/// Core types for the voice subsystem (ASR + TTS).
///
/// Modeled after ling-base's `voice/recognizer/types.go` and
/// `voice/synthesizer/types.go`, adapted for Dart/Flutter.

import 'dart:typed_data';

/// ASR vendor identifiers.
enum AsrVendor {
  volcengine,
  qcloud,
  openai,
  native,
}

/// TTS provider identifiers.
enum TtsProvider {
  volcengine,
  openai,
  native,
}

/// Audio format configuration.
class AudioFormat {
  final int sampleRate;
  final int bitDepth;
  final int channels;
  final String codec; // "pcm", "mp3", "wav", "opus"

  const AudioFormat({
    this.sampleRate = 16000,
    this.bitDepth = 16,
    this.channels = 1,
    this.codec = 'pcm',
  });

  /// Bytes per sample = (bitDepth / 8) * channels
  int get bytesPerSample => (bitDepth ~/ 8) * channels;

  /// Bytes per millisecond = sampleRate * bytesPerSample / 1000
  int get bytesPerMs => (sampleRate * bytesPerSample) ~/ 1000;

  /// Default 16kHz, 16-bit, mono PCM.
  static const AudioFormat defaultFormat = AudioFormat();
}

/// ASR recognition result.
class AsrResult {
  final String text;
  final bool isFinal;
  final Duration? duration;
  final String? dialogId;
  final Object? error;

  const AsrResult({
    required this.text,
    this.isFinal = false,
    this.duration,
    this.dialogId,
    this.error,
  });

  @override
  String toString() =>
      'AsrResult(text: "$text", isFinal: $isFinal, error: $error)';
}

/// Callback for ASR results.
typedef AsrResultCallback = void Function(AsrResult result);

/// Callback for ASR errors.
typedef AsrErrorCallback = void Function(Object error, bool isFatal);

/// TTS audio chunk delivered during synthesis.
class TtsAudioChunk {
  final Uint8List data;
  final bool isLast;

  const TtsAudioChunk(this.data, {this.isLast = false});
}

/// Callback for TTS audio chunks.
typedef TtsAudioCallback = void Function(TtsAudioChunk chunk);

/// Word-level timing info from TTS.
class TtsWordTiming {
  final String word;
  final int startTimeMs;
  final int endTimeMs;
  final double confidence;

  const TtsWordTiming({
    required this.word,
    required this.startTimeMs,
    required this.endTimeMs,
    this.confidence = 1.0,
  });
}

/// ASR engine configuration.
class AsrConfig {
  final AsrVendor vendor;
  final String appId;
  final String token;
  final String cluster;
  final String? url;
  final AudioFormat audioFormat;
  final String language;
  final bool enablePunctuation;
  final bool enableITN;

  const AsrConfig({
    required this.vendor,
    this.appId = '',
    this.token = '',
    this.cluster = '',
    this.url,
    this.audioFormat = AudioFormat.defaultFormat,
    this.language = 'zh-CN',
    this.enablePunctuation = true,
    this.enableITN = true,
  });

  AsrConfig copyWith({
    AsrVendor? vendor,
    String? appId,
    String? token,
    String? cluster,
    String? url,
    AudioFormat? audioFormat,
    String? language,
    bool? enablePunctuation,
    bool? enableITN,
  }) =>
      AsrConfig(
        vendor: vendor ?? this.vendor,
        appId: appId ?? this.appId,
        token: token ?? this.token,
        cluster: cluster ?? this.cluster,
        url: url ?? this.url,
        audioFormat: audioFormat ?? this.audioFormat,
        language: language ?? this.language,
        enablePunctuation: enablePunctuation ?? this.enablePunctuation,
        enableITN: enableITN ?? this.enableITN,
      );
}

/// TTS engine configuration.
class TtsConfig {
  final TtsProvider provider;
  final String appId;
  final String accessToken;
  final String cluster;
  final String voiceType;
  final String? url;
  final String apiKey; // For OpenAI
  final String? baseUrl; // For OpenAI compatible APIs
  final String model; // For OpenAI
  final AudioFormat audioFormat;
  final double speedRatio;
  final double volumeRatio;
  final double pitchRatio;

  const TtsConfig({
    required this.provider,
    this.appId = '',
    this.accessToken = '',
    this.cluster = '',
    this.voiceType = '',
    this.url,
    this.apiKey = '',
    this.baseUrl,
    this.model = 'tts-1',
    this.audioFormat = const AudioFormat(sampleRate: 24000, codec: 'mp3'),
    this.speedRatio = 1.0,
    this.volumeRatio = 1.0,
    this.pitchRatio = 1.0,
  });

  TtsConfig copyWith({
    TtsProvider? provider,
    String? appId,
    String? accessToken,
    String? cluster,
    String? voiceType,
    String? url,
    String? apiKey,
    String? baseUrl,
    String? model,
    AudioFormat? audioFormat,
    double? speedRatio,
    double? volumeRatio,
    double? pitchRatio,
  }) =>
      TtsConfig(
        provider: provider ?? this.provider,
        appId: appId ?? this.appId,
        accessToken: accessToken ?? this.accessToken,
        cluster: cluster ?? this.cluster,
        voiceType: voiceType ?? this.voiceType,
        url: url ?? this.url,
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        audioFormat: audioFormat ?? this.audioFormat,
        speedRatio: speedRatio ?? this.speedRatio,
        volumeRatio: volumeRatio ?? this.volumeRatio,
        pitchRatio: pitchRatio ?? this.pitchRatio,
      );
}
