/// Volcengine ASR engine — WebSocket-based streaming speech recognition.
///
/// Ported from ling-base's `voice/recognizer/volcengine/` Go implementation.
/// Uses the Volcengine binary WebSocket protocol with gzip compression.
///
/// Protocol reference:
/// wss://openspeech.bytedance.com/api/v2/asr

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';

import 'package:nudgee/core/voice/asr_engine.dart';
import 'package:nudgee/core/voice/voice_types.dart';

/// WebSocket header bytes for Volcengine ASR protocol.
const _fullClientHeader = [0x11, 0x10, 0x11, 0x00];
const _audioOnlyHeader = [0x11, 0x20, 0x11, 0x00];
const _lastAudioHeader = [0x11, 0x22, 0x11, 0x00];

const _successCode = 1000;

// Message types (upper nibble of byte 1)
const _msgFullResponse = 0x9; // 0b1001
const _msgAck = 0xB; // 0b1011
const _msgErrorResponse = 0xF; // 0b1111

class VolcengineAsrEngine extends AsrEngine {
  final AsrConfig _config;
  final Uuid _uuid = const Uuid();

  IOWebSocketChannel? _channel;
  StreamSubscription? _recvSub;
  AsrResultCallback? _onResult;
  AsrErrorCallback? _onError;
  bool _active = false;
  String _dialogId = '';
  String _sentence = '';

  VolcengineAsrEngine(this._config);

  @override
  AsrVendor get vendor => AsrVendor.volcengine;

  @override
  void init(AsrResultCallback onResult, AsrErrorCallback onError) {
    _onResult = onResult;
    _onError = onError;
  }

  @override
  Future<void> connect(String dialogId) async {
    _dialogId = dialogId;
    _sentence = '';

    final url = _config.url ??
        'wss://openspeech.bytedance.com/api/v2/asr';

    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer;${_config.token}'},
        pingInterval: const Duration(seconds: 10),
      );
      _active = true;

      // Send the initial full client message (config payload).
      await _sendFullClientMessage();

      // Start receiving.
      _recvSub = _channel!.stream.listen(
        _onMessage,
        onError: (e) {
          debugPrint('[VolcAsr] stream error: $e');
          _onError?.call(e, true);
          _active = false;
        },
        onDone: () {
          debugPrint('[VolcAsr] stream closed');
          if (_sentence.isNotEmpty) {
            _emitFinal(_sentence);
          }
          _active = false;
        },
      );
    } catch (e) {
      debugPrint('[VolcAsr] connect error: $e');
      _onError?.call(e, true);
      _active = false;
    }
  }

  @override
  bool get isActive => _active;

  @override
  Future<void> sendAudio(Uint8List data) async {
    if (!_active || _channel == null) return;
    await _sendAudioMessage(data, false);
  }

  @override
  Future<void> sendEnd() async {
    if (!_active || _channel == null) return;
    await _sendAudioMessage(Uint8List(0), true);
  }

  @override
  Future<void> stop() async {
    _active = false;
    await _recvSub?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  void dispose() {
    stop();
  }

  // ── Protocol ────────────────────────────────────────────────────────

  Future<void> _sendFullClientMessage() async {
    final req = _constructRequest();
    final payload = _gzipCompress(req);
    final payloadSize = _uint32BigEndian(payload.length);

    final msg = Uint8List.fromList([
      ..._fullClientHeader,
      ...payloadSize,
      ...payload,
    ]);

    _channel!.sink.add(msg);
  }

  Future<void> _sendAudioMessage(Uint8List audio, bool isLast) async {
    final header = isLast ? _lastAudioHeader : _audioOnlyHeader;
    final payload = _gzipCompress(audio);
    final payloadSize = _uint32BigEndian(payload.length);

    final msg = Uint8List.fromList([
      ...header,
      ...payloadSize,
      ...payload,
    ]);

    _channel!.sink.add(msg);
  }

  Uint8List _constructRequest() {
    final uid = _uuid.v4().replaceAll('-', '');
    final req = {
      'app': {
        'appid': _config.appId,
        'cluster': _config.cluster.isNotEmpty
            ? _config.cluster
            : 'volcengine_input_common',
        'token': _config.token,
      },
      'user': {'uid': uid},
      'request': {
        'reqid': _uuid.v4(),
        'nbest': 1,
        'workflow': 'audio_in,resample,partition,vad,fe,decode',
        'show_utterances': true,
        'result_type': 'signle',
        'sequence': 1,
        'end_window_size': 300,
      },
      'audio': {
        'format': _config.audioFormat.codec == 'pcm' ? 'raw' : _config.audioFormat.codec,
        'codec': 'raw',
      },
    };
    return utf8.encode(jsonEncode(req));
  }

  void _onMessage(dynamic message) {
    if (message is! List<int>) return;
    final bytes = Uint8List.fromList(message);

    try {
      final response = _parseResponse(bytes);
      if (response == null) return;

      if (response['code'] != _successCode) {
        debugPrint('[VolcAsr] error code: ${response['code']}, '
            'msg: ${response['message']}');
        _onError?.call(
          'Volcengine ASR error: ${response['message']}',
          false,
        );
        return;
      }

      final results = response['result'] as List?;
      if (results == null || results.isEmpty) return;

      final latest = results[0] as Map<String, dynamic>;
      final text = latest['text'] as String? ?? '';
      if (text.isNotEmpty) {
        _sentence = text;
        _emitPartial(text);
      }

      // Check for definite (final) utterance.
      final utterances = latest['utterances'] as List?;
      if (utterances != null && utterances.isNotEmpty) {
        final utt = utterances[0] as Map<String, dynamic>;
        if (utt['definite'] == true) {
          _emitFinal(text);
        }
      }
    } catch (e) {
      debugPrint('[VolcAsr] parse error: $e');
    }
  }

  Map<String, dynamic>? _parseResponse(Uint8List msg) {
    if (msg.length < 4) return null;

    final headerSize = msg[0] & 0x0f;
    final messageType = msg[1] >> 4;
    final serializationMethod = msg[2] >> 4;
    final messageCompression = msg[2] & 0x0f;

    final payload = msg.sublist(headerSize * 4);
    if (payload.length < 4) return null;

    Uint8List payloadMsg;
    int payloadSize;

    if (messageType == _msgFullResponse) {
      payloadSize = _readInt32(payload, 0);
      payloadMsg = payload.sublist(4);
    } else if (messageType == _msgAck) {
      // ACK — just sequence number, skip.
      return null;
    } else if (messageType == _msgErrorResponse) {
      payloadSize = _readInt32(payload, 4);
      payloadMsg = payload.sublist(8);
      if (messageCompression == 0x01) {
        payloadMsg = _gzipDecompress(payloadMsg);
      }
      final errResponse = jsonDecode(utf8.decode(payloadMsg)) as Map<String, dynamic>;
      debugPrint('[VolcAsr] server error: ${errResponse['message']}');
      _onError?.call(
        'Volcengine ASR: ${errResponse['message']}',
        false,
      );
      return null;
    } else {
      return null;
    }

    if (messageCompression == 0x01) {
      payloadMsg = _gzipDecompress(payloadMsg);
    }

    if (serializationMethod == 0x01) {
      return jsonDecode(utf8.decode(payloadMsg)) as Map<String, dynamic>;
    }

    return null;
  }

  void _emitPartial(String text) {
    text = text.trim();
    if (text.isEmpty) return;
    _onResult?.call(AsrResult(
      text: text,
      isFinal: false,
      dialogId: _dialogId,
    ));
  }

  void _emitFinal(String text) {
    text = text.trim();
    if (text.isEmpty) text = _sentence.trim();
    if (text.isEmpty) return;
    _sentence = '';
    _onResult?.call(AsrResult(
      text: text,
      isFinal: true,
      dialogId: _dialogId,
    ));
  }

  // ── Binary helpers ──────────────────────────────────────────────────

  List<int> _uint32BigEndian(int value) => [
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ];

  int _readInt32(Uint8List data, int offset) {
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  Uint8List _gzipCompress(List<int> data) {
    if (data.isEmpty) return Uint8List(0);
    final gzip = GZipCodec();
    return Uint8List.fromList(gzip.encode(data));
  }

  Uint8List _gzipDecompress(Uint8List data) {
    final gzip = GZipCodec();
    return Uint8List.fromList(gzip.decode(data));
  }
}
