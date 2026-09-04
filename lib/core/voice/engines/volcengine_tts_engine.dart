/// Volcengine TTS engine — HTTP-based text-to-speech synthesis.
///
/// Ported from ling-base's `voice/synthesizer/volcengine/` Go implementation.
/// Uses the Volcengine TTS HTTP API with base64-encoded audio response.
///
/// API reference:
/// https://openspeech.bytedance.com/api/v1/tts

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:nudgee/core/voice/tts_engine.dart';
import 'package:nudgee/core/voice/voice_types.dart';

const _ttsUrl = 'https://openspeech.bytedance.com/api/v1/tts';
const _ttsSuccessCode = 3000;

class VolcengineTtsEngine extends TtsEngine {
  final TtsConfig _config;
  final Dio _dio;
  final Uuid _uuid = const Uuid();
  bool _stopped = false;

  VolcengineTtsEngine(this._config)
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));

  @override
  TtsProvider get provider => TtsProvider.volcengine;

  @override
  AudioFormat get outputFormat => _config.audioFormat;

  @override
  Future<Uint8List> synthesize({
    required String text,
    TtsAudioCallback? onAudio,
  }) async {
    if (text.isEmpty) return Uint8List(0);
    _stopped = false;

    final reqId = _uuid.v4();
    final params = {
      'app': {
        'appid': _config.appId,
        'token': 'access_token',
        'cluster': _config.cluster.isNotEmpty
            ? _config.cluster
            : 'volcano_tts',
      },
      'user': {'uid': 'nudgee_user'},
      'audio': {
        'voice_type': _config.voiceType.isNotEmpty
            ? _config.voiceType
            : 'BV700_streaming',
        'encoding': _config.audioFormat.codec,
        'speed_ratio': _config.speedRatio,
        'volume_ratio': _config.volumeRatio,
        'pitch_ratio': _config.pitchRatio,
        if (_config.audioFormat.sampleRate > 0)
          'rate': _config.audioFormat.sampleRate,
      },
      'request': {
        'reqid': reqId,
        'text': text,
        'text_type': 'plain',
        'operation': 'query',
        'with_timestamp': '1',
      },
    };

    try {
      final response = await _dio.post(
        _ttsUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer;${_config.accessToken}',
          },
        ),
        data: jsonEncode(params),
      );

      if (_stopped) return Uint8List(0);

      final resp = response.data as Map<String, dynamic>;
      final code = resp['code'] as int? ?? 0;
      if (code != _ttsSuccessCode) {
        final msg = resp['message'] ?? 'unknown error';
        debugPrint('[VolcTts] error: code=$code, message=$msg');
        throw Exception('Volcengine TTS error: code=$code, message=$msg');
      }

      final dataBase64 = resp['data'] as String? ?? '';
      if (dataBase64.isEmpty) {
        debugPrint('[VolcTts] empty audio data');
        return Uint8List(0);
      }

      final bytes = base64Decode(dataBase64);
      onAudio?.call(TtsAudioChunk(bytes, isLast: true));
      return bytes;
    } on DioException catch (e) {
      debugPrint('[VolcTts] dio error: ${e.message}');
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
