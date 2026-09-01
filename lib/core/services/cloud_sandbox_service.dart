import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 云端代码执行沙箱服务。
///
/// 将代码发送到云端服务器执行，支持 Node.js / Python / Go 等语言。
/// 云端使用 Docker 容器隔离执行，返回 stdout/stderr/exit code。
///
/// 服务器 API 约定:
/// ```
/// POST /api/sandbox/execute
/// Body: { "language": "node", "code": "...", "timeout": 10 }
/// Response: { "stdout": "...", "stderr": "...", "exitCode": 0, "duration": 1234 }
/// ```
///
/// 配置: 在 config.yaml 中设置 `sandbox.apiBaseUrl`
class CloudSandboxService {
  final Dio _dio;
  final String? _apiBaseUrl;

  CloudSandboxService(this._dio, {String? apiBaseUrl})
      : _apiBaseUrl = apiBaseUrl;

  /// 执行代码。
  ///
  /// [language] - 编程语言: "node", "python", "go", "ruby", etc.
  /// [code] - 要执行的代码
  /// [timeout] - 超时秒数 (默认 10, 最大 60)
  ///
  /// 返回 [SandboxResult]，包含 stdout/stderr/exitCode。
  Future<SandboxResult> execute({
    required String language,
    required String code,
    int timeout = 10,
  }) async {
    if (_apiBaseUrl == null || _apiBaseUrl.isEmpty) {
      return SandboxResult(
        stdout: '',
        stderr: '云端沙箱未配置。请在 config.yaml 中设置 sandbox.apiBaseUrl。',
        exitCode: -1,
        duration: 0,
        success: false,
      );
    }

    final clampedTimeout = timeout.clamp(1, 60);

    try {
      final response = await _dio.post(
        '$_apiBaseUrl/api/sandbox/execute',
        data: jsonEncode({
          'language': language,
          'code': code,
          'timeout': clampedTimeout,
        }),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: Duration(seconds: clampedTimeout + 5),
          receiveTimeout: Duration(seconds: clampedTimeout + 10),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      return SandboxResult(
        stdout: data['stdout'] as String? ?? '',
        stderr: data['stderr'] as String? ?? '',
        exitCode: data['exitCode'] as int? ?? -1,
        duration: data['duration'] as int? ?? 0,
        success: (data['exitCode'] as int? ?? -1) == 0,
      );
    } on DioException catch (e) {
      debugPrint('[CloudSandbox] DioException: ${e.message}');
      final errorMsg = e.response?.data?['error'] as String? ?? e.message ?? '网络错误';
      return SandboxResult(
        stdout: '',
        stderr: '云端执行请求失败: $errorMsg',
        exitCode: -1,
        duration: 0,
        success: false,
      );
    } catch (e) {
      debugPrint('[CloudSandbox] error: $e');
      return SandboxResult(
        stdout: '',
        stderr: '云端执行异常: $e',
        exitCode: -1,
        duration: 0,
        success: false,
      );
    }
  }

  /// 检查沙箱是否可用。
  Future<bool> isAvailable() async {
    if (_apiBaseUrl == null || _apiBaseUrl.isEmpty) return false;
    try {
      final response = await _dio.get(
        '$_apiBaseUrl/api/sandbox/health',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// 云端沙箱执行结果。
class SandboxResult {
  final String stdout;
  final String stderr;
  final int exitCode;
  final int duration;
  final bool success;

  const SandboxResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.duration,
    required this.success,
  });

  @override
  String toString() =>
      'SandboxResult(exitCode: $exitCode, duration: ${duration}ms, stdout: ${stdout.length}B, stderr: ${stderr.length}B)';
}
