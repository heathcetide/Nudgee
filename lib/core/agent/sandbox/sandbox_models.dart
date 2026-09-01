/// Sandbox permissions — controls what sandboxed code can access.
class SandboxPermissions {
  /// Whether file system access is allowed.
  final bool allowFilesystem;

  /// Whether network requests are allowed.
  final bool allowNetwork;

  /// Whether process execution is allowed.
  final bool allowProcess;

  /// Whether Isolate operations are allowed.
  final bool allowIsolate;

  /// File system root directory restriction (if [allowFilesystem] is true).
  final String? filesystemRoot;

  /// Network domain whitelist (if [allowNetwork] is true).
  /// Empty = all domains allowed.
  final List<String> networkWhitelist;

  /// Execution timeout.
  final Duration timeout;

  /// Memory limit in MB.
  final int memoryLimitMB;

  /// Whether to allow `print` / `stdout` output.
  final bool allowPrint;

  /// Creates [SandboxPermissions].
  const SandboxPermissions({
    this.allowFilesystem = false,
    this.allowNetwork = false,
    this.allowProcess = false,
    this.allowIsolate = false,
    this.filesystemRoot,
    this.networkWhitelist = const [],
    this.timeout = const Duration(seconds: 10),
    this.memoryLimitMB = 50,
    this.allowPrint = true,
  });

  /// Default safe config (minimum privileges — no IO, no network).
  static const safe = SandboxPermissions();

  /// Compute config (allows network, no filesystem).
  static const compute = SandboxPermissions(
    allowNetwork: true,
    timeout: Duration(seconds: 30),
  );

  /// Data processing config (allows filesystem within root, no network).
  static const dataProcessing = SandboxPermissions(
    allowFilesystem: true,
    filesystemRoot: '/tmp/sandbox',
    timeout: Duration(seconds: 30),
  );

  /// Full access config (use with caution — only for trusted code).
  static const full = SandboxPermissions(
    allowFilesystem: true,
    allowNetwork: true,
    allowProcess: true,
    allowIsolate: true,
    timeout: Duration(minutes: 5),
    memoryLimitMB: 200,
  );

  @override
  String toString() => 'SandboxPermissions(fs=$allowFilesystem, '
      'net=$allowNetwork, proc=$allowProcess, timeout=${timeout.inSeconds}s)';
}

/// Result of sandbox code execution.
class SandboxResult {
  /// Whether execution succeeded.
  final bool success;

  /// The return value of the executed code (if any).
  final dynamic output;

  /// Stdout output (print statements).
  final String? stdout;

  /// Stderr output (errors).
  final String? stderr;

  /// Execution duration.
  final Duration duration;

  /// Error message if [success] is false.
  final String? error;

  /// Error type (e.g. 'TimeoutException', 'RuntimeError', 'SyntaxError').
  final String? errorType;

  /// Creates a [SandboxResult].
  const SandboxResult({
    required this.success,
    this.output,
    this.stdout,
    this.stderr,
    required this.duration,
    this.error,
    this.errorType,
  });

  /// Creates a successful result.
  factory SandboxResult.ok({
    dynamic output,
    String? stdout,
    required Duration duration,
  }) =>
      SandboxResult(
        success: true,
        output: output,
        stdout: stdout,
        duration: duration,
      );

  /// Creates a failed result.
  factory SandboxResult.failed(
    String error, {
    String? errorType,
    String? stderr,
    required Duration duration,
  }) =>
      SandboxResult(
        success: false,
        error: error,
        errorType: errorType,
        stderr: stderr,
        duration: duration,
      );

  @override
  String toString() =>
      'SandboxResult(${success ? "ok" : "fail"}, ${duration.inMilliseconds}ms)';
}

/// Safety report from static analysis of code.
class SandboxSafetyReport {
  /// Whether the code is safe to execute.
  final bool isSafe;

  /// List of detected issues (empty if safe).
  final List<SandboxSafetyIssue> issues;

  /// Risk level (low, medium, high, critical).
  final SandboxRiskLevel riskLevel;

  /// Creates a [SandboxSafetyReport].
  const SandboxSafetyReport({
    required this.isSafe,
    required this.issues,
    required this.riskLevel,
  });

  /// Creates a safe report (no issues).
  factory SandboxSafetyReport.safe() =>
      const SandboxSafetyReport(
        isSafe: true,
        issues: [],
        riskLevel: SandboxRiskLevel.low,
      );

  @override
  String toString() => 'SandboxSafetyReport(safe=$isSafe, '
      'risk=$riskLevel, issues=${issues.length})';
}

/// A safety issue detected during static analysis.
class SandboxSafetyIssue {
  /// Issue type.
  final SandboxSafetyIssueType type;

  /// Human-readable description.
  final String description;

  /// Line number (1-based, if known).
  final int? line;

  /// The code snippet that triggered the issue.
  final String? snippet;

  /// Creates a [SandboxSafetyIssue].
  const SandboxSafetyIssue({
    required this.type,
    required this.description,
    this.line,
    this.snippet,
  });

  @override
  String toString() => 'SandboxSafetyIssue($type: $description)';
}

/// Types of safety issues.
enum SandboxSafetyIssueType {
  /// Dangerous import (dart:io, dart:isolate, etc.).
  dangerousImport,

  /// File system access without permission.
  filesystemAccess,

  /// Network access without permission.
  networkAccess,

  /// Process execution.
  processExecution,

  /// Infinite loop risk.
  infiniteLoop,

  /// Recursive depth risk.
  deepRecursion,

  /// Memory allocation risk.
  memoryAllocation,

  /// Potentially malicious pattern.
  suspiciousPattern,
}

/// Risk level of code.
enum SandboxRiskLevel {
  /// Safe to execute.
  low,

  /// Minor concerns, execute with caution.
  medium,

  /// Significant concerns, require confirmation.
  high,

  /// Dangerous, do not execute.
  critical,
}
