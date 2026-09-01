import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';
import 'package:nudgee/core/di/injector.dart' as di;
import 'package:nudgee/core/services/cloud_sandbox_service.dart';

/// Tool: cloud.exec
///
/// Executes code on a remote cloud sandbox server.
/// Supports Node.js, Python, Go, Ruby, and other languages
/// that the sandbox server has configured.
///
/// Use this tool when:
/// - The code needs npm packages (Node.js ecosystem)
/// - The code needs Python libraries (numpy, pandas, etc.)
/// - The task requires a full runtime environment
/// - Local JS execution (workspace.js.exec) is insufficient
///
/// The sandbox server must be configured in config.yaml:
/// ```yaml
/// sandbox:
///   apiBaseUrl: https://your-sandbox-server.com
/// ```
class CloudSandboxTool extends AgentTool {
  CloudSandboxTool();

  @override
  String get name => 'cloud.exec';

  @override
  String get description =>
      'Execute code on a remote cloud sandbox server. '
      'Supports Node.js (with npm packages), Python, Go, Ruby, etc. '
      'Use this when the code needs a full runtime environment or '
      'external packages that local JS execution cannot provide. '
      'The sandbox runs in an isolated Docker container with network access. '
      'Languages: "node" (Node.js 20), "python" (Python 3.12), '
      '"go" (Go 1.22), "ruby" (Ruby 3.3).';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'language': {
            'type': 'string',
            'description': 'Programming language: "node", "python", "go", "ruby"',
            'enum': ['node', 'python', 'go', 'ruby'],
          },
          'code': {
            'type': 'string',
            'description': 'The code to execute',
          },
          'timeout': {
            'type': 'integer',
            'description': 'Execution timeout in seconds (default 10, max 60)',
          },
        },
        'required': ['language', 'code'],
      };

  @override
  bool get isMutation => false;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final language = args['language'] as String?;
    final code = args['code'] as String?;

    if (language == null || language.isEmpty) {
      return const ToolResult.error('Missing required field: language');
    }
    if (code == null || code.isEmpty) {
      return const ToolResult.error('Missing required field: code');
    }

    final timeout = (args['timeout'] as int?) ?? 10;

    try {
      final sandbox = di.sl<CloudSandboxService>();
      final result = await sandbox.execute(
        language: language,
        code: code,
        timeout: timeout,
      );

      if (!result.success && result.stderr.contains('未配置')) {
        return ToolResult.error(
            '云端沙箱未配置。这是一个可选功能，需要部署沙箱服务器。'
            '本地可以用 workspace.js.exec 执行 JavaScript 代码。');
      }

      final output = StringBuffer();
      if (result.stdout.isNotEmpty) {
        output.writeln('── stdout ──');
        output.writeln(result.stdout);
      }
      if (result.stderr.isNotEmpty) {
        output.writeln('── stderr ──');
        output.writeln(result.stderr);
      }
      output.writeln('── exit code: ${result.exitCode} (${result.duration}ms) ──');

      if (result.success) {
        return ToolResult.success(output.toString().trim());
      } else {
        return ToolResult.error(output.toString().trim());
      }
    } catch (e) {
      debugPrint('[CloudSandboxTool] error: $e');
      return ToolResult.error('Cloud execution failed: $e');
    }
  }
}
