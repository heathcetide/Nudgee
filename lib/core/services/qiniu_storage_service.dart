import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:qiniu_flutter_sdk/qiniu_flutter_sdk.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart' show Auth, PutPolicy;

import 'package:nudgee/core/config/app_config.dart';

/// Qiniu Cloud object storage service.
///
/// Wraps the qiniu_flutter_sdk to provide simple upload/download/delete
/// operations. Config is loaded from `config.yaml` (git-ignored).
///
/// Usage:
///   final url = await sl<QiniuStorageService>().uploadBytes(
///     'avatars/user123.jpg', bytes);
class QiniuStorageService {
  final Storage _storage;
  final Auth _auth;
  final StorageConfig _config;

  QiniuStorageService()
      : _config = AppConfig.storage ?? const StorageConfig(
          kind: 'qiniu',
          qiniuAccessKey: '',
          qiniuSecretKey: '',
          qiniuBucket: '',
          qiniuDomain: '',
          qiniuPrivate: false,
          qiniuRegion: 'huanan',
        ),
        _auth = Auth(
          accessKey: AppConfig.storage?.qiniuAccessKey ?? '',
          secretKey: AppConfig.storage?.qiniuSecretKey ?? '',
        ),
        _storage = Storage();

  /// Whether the service is properly configured.
  bool get isConfigured =>
      _config.qiniuAccessKey.isNotEmpty &&
      _config.qiniuSecretKey.isNotEmpty &&
      _config.qiniuBucket.isNotEmpty;

  /// Generate an upload token for the given [key].
  String _generateToken(String key) {
    final deadline = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    final putPolicy = PutPolicy(
      scope: '${_config.qiniuBucket}:$key',
      deadline: deadline,
    );
    return _auth.generateUploadToken(putPolicy: putPolicy);
  }

  /// Upload bytes to Qiniu with the given [key].
  ///
  /// Returns the full CDN URL on success, or `null` on failure.
  Future<String?> uploadBytes(String key, Uint8List bytes) async {
    if (!isConfigured) return null;
    try {
      final token = _generateToken(key);
      await _storage.putBytes(bytes, token);
      return '${_config.qiniuDomain}/$key';
    } catch (e) {
      debugPrint('[QiniuStorage] uploadBytes error: $e');
      return null;
    }
  }

  /// Upload a file to Qiniu with the given [key].
  ///
  /// Returns the full CDN URL on success, or `null` on failure.
  Future<String?> uploadFile(String key, File file) async {
    if (!isConfigured) return null;
    try {
      final token = _generateToken(key);
      await _storage.putFile(file, token);
      return '${_config.qiniuDomain}/$key';
    } catch (e) {
      debugPrint('[QiniuStorage] uploadFile error: $e');
      return null;
    }
  }

  /// Build the CDN URL for a given [key].
  String urlFor(String key) {
    return '${_config.qiniuDomain}/$key';
  }

  /// Build the CDN URL from a full key path, extracting just the key portion
  /// if a full URL is passed.
  String urlFromKey(String keyOrUrl) {
    if (keyOrUrl.startsWith('http')) return keyOrUrl;
    return urlFor(keyOrUrl);
  }

  /// Delete an object by [key]. (Requires server-side API in production;
  /// the SDK doesn't support direct delete from client for security.)
  ///
  /// For now this is a no-op placeholder — deletion should go through a
  /// serverless function or backend API.
  Future<bool> delete(String key) async {
    debugPrint('[QiniuStorage] delete not supported from client — use serverless API');
    return false;
  }
}
