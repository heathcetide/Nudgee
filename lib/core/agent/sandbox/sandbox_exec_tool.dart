import 'dart:async';

import 'package:nudgee/core/agent/sandbox/sandbox.dart';
import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

/// Agent tool for executing Dart code in a sandbox.
///
/// This tool allows the AI agent to write and execute Dart code
/// safely. The code is statically analyzed before execution, and
/// runs with restricted permissions (no filesystem, no network by default).
///
/// The agent can use this tool to:
/// - Perform complex calculations
/// - Process data structures (lists, maps)
/// - Format/transform text
/// - Test algorithms
///
/// Example agent usage:
/// ```json
/// {
///   "name": "sandbox.exec",
///   "arguments": {
///     "code": "print(1 + 2 * 3);",
///     "language": "dart"
///   }
/// }
/// ```
class SandboxExecTool extends AgentTool {
  /// The sandbox executor instance.
  final SandboxExecutor executor;

  /// Default permissions for code execution.
  final SandboxPermissions defaultPermissions;

  /// Whether to require user confirmation for high-risk code.
  final bool requireConfirmationForHighRisk;

  /// Creates a [SandboxExecTool].
  SandboxExecTool({
    SandboxExecutor? executor,
    this.defaultPermissions = SandboxPermissions.safe,
    this.requireConfirmationForHighRisk = true,
  }) : executor = executor ?? SandboxExecutor();

  @override
  String get name => 'sandbox.exec';

  @override
  String get description =>
      'Execute Dart code in a secure sandbox. Supports arithmetic, '
      'string operations, list/map operations, and bridge functions. '
      'Code is statically analyzed before execution. '
      'No filesystem or network access by default.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'code': {
            'type': 'string',
            'description': 'The Dart code to execute',
          },
          'language': {
            'type': 'string',
            'description': 'Programming language (default: dart)',
            'default': 'dart',
          },
          'permissions': {
            'type': 'string',
            'description': 'Permission preset: safe, compute, data, full',
            'default': 'safe',
            'enum': ['safe', 'compute', 'data', 'full'],
          },
        },
        'required': ['code'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final code = args['code'] as String?;
    if (code == null || code.isEmpty) {
      return ToolResult.error('Missing required parameter: code');
    }

    final language = args['language'] as String? ?? 'dart';
    if (language != 'dart') {
      return ToolResult.error(
          'Unsupported language: $language. Only "dart" is supported.');
    }

    // Determine permissions from preset
    final permPreset = args['permissions'] as String? ?? 'safe';
    final permissions = _parsePermissions(permPreset);

    // Static analysis
    final report = executor.analyze(code, permissions: permissions);

    // Check for critical risk
    if (report.riskLevel == SandboxRiskLevel.critical) {
      final issues = report.issues.map((i) => '  - ${i.description}').join('\n');
      return ToolResult.error(
        'Code rejected by safety analysis (critical risk):\n$issues\n\n'
        'Please remove dangerous operations (imports, process execution, etc.)',
      );
    }

    // Execute
    final result = await executor.execute(
      code,
      permissions: permissions,
    );

    if (!result.success) {
      return ToolResult.error(
        'Execution failed (${result.errorType}): ${result.error}',
      );
    }

    // Format output
    final parts = <String>[];
    if (result.stdout != null && result.stdout!.isNotEmpty) {
      parts.add('stdout:\n${result.stdout}');
    }
    if (result.output != null) {
      parts.add('result: ${result.output}');
    }
    parts.add('duration: ${result.duration.inMilliseconds}ms');

    return ToolResult.success(parts.join('\n'));
  }

  /// Parses permissions from a preset name.
  SandboxPermissions _parsePermissions(String preset) {
    switch (preset) {
      case 'safe':
        return SandboxPermissions.safe;
      case 'compute':
        return SandboxPermissions.compute;
      case 'data':
        return SandboxPermissions.dataProcessing;
      case 'full':
        return SandboxPermissions.full;
      default:
        return SandboxPermissions.safe;
    }
  }

  /// Registers a bridge function that sandboxed code can call.
  void registerBridgeFunction(
    String name,
    SandboxBridgeFunction fn,
  ) {
    executor.registerBridgeFunction(name, fn);
  }
}
