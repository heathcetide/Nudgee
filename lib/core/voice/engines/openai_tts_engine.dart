/// OpenAI TTS engine — uses OpenAI's Text-to-Speech HTTP API.
///
/// Supports both OpenAI's official API and compatible endpoints
/// (e.g., Azure OpenAI, local TTS servers) via [baseUrl].
///
/// API reference: https://platform.openai.com/docs/api-reference/audio/create-speech

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:nudgee/core/voice/tts_engine.dart';
import 'package:nudgee/core/voice/voice_types.dart';

class OpenAiTtsEngine extends TtsEngine {
  final TtsConfig _config;
  final Dio _dio;
  bool _stopped = false;

  OpenAiTtsEngine(this._config)
      : _dio = Dio(BaseOptions(
          baseUrl: _config.baseUrl ?? 'https://api.openai.com/v1',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));

  @override
  TtsProvider get provider => TtsProvider.openai;

  @override
  AudioFormat get outputFormat => _config.audioFormat;

  @override
  Future<Uint8List> synthesize({
    required String text,
    TtsAudioCallback? onAudio,
  }) async {
    if (text.isEmpty) return Uint8List(0);
    _stopped = false;

    final format = _config.audioFormat.codec == 'pcm' ? 'pcm' : 'mp3';

    try {
      final response = await _dio.post(
        '/audio/speech',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_config.apiKey}',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.bytes,
        ),
        data: jsonEncode({
          'model': _config.model,
          'input': text,
          'voice': _config.voiceType.isNotEmpty ? _config.voiceType : 'alloy',
          'response_format': format,
          'speed': _config.speedRatio,
        }),
      );

      if (_stopped) return Uint8List(0);

      final bytes = Uint8List.fromList(response.data as List<int>);
      onAudio?.call(TtsAudioChunk(bytes, isLast: true));
      return bytes;
    } on DioException catch (e) {
      debugPrint('[OpenAiTts] error: ${e.message}');
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _dio.close(force: true);
  }

  @override
  void dispose() {
    _dio.close(force: true);
  }
}
