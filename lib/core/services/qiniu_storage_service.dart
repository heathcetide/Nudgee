import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
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
    debugPrint('[QiniuStorage] uploadBytes: key=$key, bytes=${bytes.length}B, configured=$isConfigured');
    if (!isConfigured) {
      debugPrint('[QiniuStorage] uploadBytes FAILED — not configured');
      return null;
    }
    try {
      final token = _generateToken(key);
      debugPrint('[QiniuStorage] token generated, uploading...');
      final response = await _storage.putBytes(
        bytes,
        token,
        options: PutOptions(key: key),
      );
      debugPrint('[QiniuStorage] upload success: key=${response.key}, hash=${response.hash}');
      return '${_config.qiniuDomain}/$key';
    } catch (e, st) {
      debugPrint('[QiniuStorage] uploadBytes error: $e');
      debugPrint('[QiniuStorage] stacktrace: $st');
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
      await _storage.putFile(file, token, options: PutOptions(key: key));
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

  // ── Download ──────────────────────────────────────────────────────────

  final Dio _downloadDio = Dio(BaseOptions(
    connectTimeout: Duration(seconds: 15),
    receiveTimeout: Duration(seconds: 30),
    responseType: ResponseType.bytes,
  ));

  /// Download bytes from Qiniu CDN by [key].
  ///
  /// Returns the raw bytes on success, or `null` on failure.
  Future<Uint8List?> downloadBytes(String key) async {
    final url = urlFor(key);
    debugPrint('[QiniuStorage] downloadBytes: $url');
    try {
      final response = await _downloadDio.get<List<int>>(url);
      if (response.statusCode != 200 || response.data == null) {
        debugPrint('[QiniuStorage] downloadBytes failed — status ${response.statusCode}');
        return null;
      }
      return Uint8List.fromList(response.data!);
    } on DioException catch (e) {
      debugPrint('[QiniuStorage] downloadBytes error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[QiniuStorage] downloadBytes error: $e');
      return null;
    }
  }

  /// Download a file from Qiniu CDN by [key] and save it to [localPath].
  ///
  /// Returns the saved [File] on success, or `null` on failure.
  Future<File?> downloadFile(String key, String localPath) async {
    final url = urlFor(key);
    debugPrint('[QiniuStorage] downloadFile: $url → $localPath');
    try {
      await _downloadDio.download(url, localPath);
      return File(localPath);
    } on DioException catch (e) {
      debugPrint('[QiniuStorage] downloadFile error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[QiniuStorage] downloadFile error: $e');
      return null;
    }
  }

  /// Download text content from Qiniu CDN by [key].
  ///
  /// Returns the decoded string on success, or `null` on failure.
  Future<String?> downloadText(String key) async {
    final url = urlFor(key);
    debugPrint('[QiniuStorage] downloadText: $url');
    try {
      final response = await _downloadDio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      if (response.statusCode != 200 || response.data == null) {
        debugPrint('[QiniuStorage] downloadText failed — status ${response.statusCode}');
        return null;
      }
      return response.data;
    } on DioException catch (e) {
      debugPrint('[QiniuStorage] downloadText error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[QiniuStorage] downloadText error: $e');
      return null;
    }
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
