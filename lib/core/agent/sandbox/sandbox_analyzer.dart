import 'package:nudgee/core/agent/sandbox/sandbox_models.dart';

/// Static analyzer for sandbox code.
///
/// Performs heuristic-based static analysis to detect potentially
/// dangerous patterns in Dart code before execution.
///
/// This is NOT a full Dart parser — it uses regex-based pattern matching
/// to catch common dangerous patterns. For production use, consider
/// integrating a proper Dart analyzer.
class SandboxStaticAnalyzer {
  /// Dangerous import patterns.
  static final _dangerousImports = <RegExp>[
    RegExp(r'''import\s+['"]dart:io['"]'''),
    RegExp(r'''import\s+['"]dart:isolate['"]'''),
    RegExp(r'''import\s+['"]dart:ffi['"]'''),
    RegExp(r'''import\s+['"]dart:cli['"]'''),
  ];

  /// File system access patterns.
  static final _filesystemPatterns = <RegExp>[
    RegExp(r'\bFile\b\s*\('),
    RegExp(r'\bDirectory\b\s*\('),
    RegExp(r'\bFile\b\s*\.'),
    RegExp(r'\bDirectory\b\s*\.'),
    RegExp(r'\bFileSystemEntity\b'),
    RegExp(r'\bRandomAccessFile\b'),
  ];

  /// Network access patterns.
  static final _networkPatterns = <RegExp>[
    RegExp(r'\bHttpClient\b'),
    RegExp(r'\bhttp\b\s*\.'),
    RegExp(r'\bWebSocket\b'),
    RegExp(r'\bSocket\b\s*\('),
    RegExp(r'\bUri\.parse\b'),
    RegExp(r'\bfetch\b\s*\('),
  ];

  /// Process execution patterns.
  static final _processPatterns = <RegExp>[
    RegExp(r'\bProcess\b\s*\.'),
    RegExp(r'\bProcess\.run\b'),
    RegExp(r'\bProcess\.start\b'),
    RegExp(r'\bPlatform\.executable\b'),
    RegExp(r'\bexit\b\s*\('),
    RegExp(r'\bSystemCommand\b'),
  ];

  /// Infinite loop risk patterns.
  static final _infiniteLoopPatterns = <RegExp>[
    RegExp(r'while\s*\(\s*true\s*\)'),
    RegExp(r'while\s*\(\s*1\s*\)'),
    RegExp(r'for\s*\(\s*;\s*;\s*\)'),
  ];

  /// Suspicious patterns (potential injection / obfuscation).
  static final _suspiciousPatterns = <RegExp>[
    RegExp(r'eval\s*\('),
    RegExp(r'Function\.apply\b'),
    RegExp(r'noSuchMethod\b'),
    RegExp(r'\\x[0-9a-fA-F]{2}'), // Hex escapes (obfuscation)
    RegExp(r'\\u00'), // Unicode escapes (obfuscation)
  ];

  /// Analyzes [code] and returns a safety report.
  ///
  /// If [permissions] are provided, issues are only flagged for
  /// accesses that aren't permitted.
  SandboxSafetyReport analyze(
    String code, {
    SandboxPermissions permissions = SandboxPermissions.safe,
  }) {
    final issues = <SandboxSafetyIssue>[];
    final lines = code.split('\n');

    // Check dangerous imports
    for (final pattern in _dangerousImports) {
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          issues.add(SandboxSafetyIssue(
            type: SandboxSafetyIssueType.dangerousImport,
            description: 'Dangerous import detected: ${lines[i].trim()}',
            line: i + 1,
            snippet: lines[i].trim(),
          ));
        }
      }
    }

    // Check filesystem access (if not permitted)
    if (!permissions.allowFilesystem) {
      for (final pattern in _filesystemPatterns) {
        for (var i = 0; i < lines.length; i++) {
          if (pattern.hasMatch(lines[i])) {
            issues.add(SandboxSafetyIssue(
              type: SandboxSafetyIssueType.filesystemAccess,
              description: 'File system access not permitted: ${lines[i].trim()}',
              line: i + 1,
              snippet: lines[i].trim(),
            ));
          }
        }
      }
    }

    // Check network access (if not permitted)
    if (!permissions.allowNetwork) {
      for (final pattern in _networkPatterns) {
        for (var i = 0; i < lines.length; i++) {
          if (pattern.hasMatch(lines[i])) {
            issues.add(SandboxSafetyIssue(
              type: SandboxSafetyIssueType.networkAccess,
              description: 'Network access not permitted: ${lines[i].trim()}',
              line: i + 1,
              snippet: lines[i].trim(),
            ));
          }
        }
      }
    }

    // Check process execution (if not permitted)
    if (!permissions.allowProcess) {
      for (final pattern in _processPatterns) {
        for (var i = 0; i < lines.length; i++) {
          if (pattern.hasMatch(lines[i])) {
            issues.add(SandboxSafetyIssue(
              type: SandboxSafetyIssueType.processExecution,
              description: 'Process execution not permitted: ${lines[i].trim()}',
              line: i + 1,
              snippet: lines[i].trim(),
            ));
          }
        }
      }
    }

    // Check infinite loop risk
    for (final pattern in _infiniteLoopPatterns) {
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          issues.add(SandboxSafetyIssue(
            type: SandboxSafetyIssueType.infiniteLoop,
            description: 'Potential infinite loop: ${lines[i].trim()}',
            line: i + 1,
            snippet: lines[i].trim(),
          ));
        }
      }
    }

    // Check suspicious patterns
    for (final pattern in _suspiciousPatterns) {
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          issues.add(SandboxSafetyIssue(
            type: SandboxSafetyIssueType.suspiciousPattern,
            description: 'Suspicious pattern: ${lines[i].trim()}',
            line: i + 1,
            snippet: lines[i].trim(),
          ));
        }
      }
    }

    // Determine risk level
    final riskLevel = _calculateRiskLevel(issues);

    return SandboxSafetyReport(
      isSafe: riskLevel != SandboxRiskLevel.critical &&
          (issues.isEmpty || riskLevel == SandboxRiskLevel.low),
      issues: issues,
      riskLevel: riskLevel,
    );
  }

  /// Calculates risk level from issues.
  SandboxRiskLevel _calculateRiskLevel(List<SandboxSafetyIssue> issues) {
    if (issues.isEmpty) return SandboxRiskLevel.low;

    final hasCritical = issues.any((i) =>
        i.type == SandboxSafetyIssueType.processExecution ||
        i.type == SandboxSafetyIssueType.dangerousImport);
    if (hasCritical) return SandboxRiskLevel.critical;

    final hasHigh = issues.any((i) =>
        i.type == SandboxSafetyIssueType.filesystemAccess ||
        i.type == SandboxSafetyIssueType.networkAccess);
    if (hasHigh) return SandboxRiskLevel.high;

    final hasMedium = issues.any((i) =>
        i.type == SandboxSafetyIssueType.infiniteLoop ||
        i.type == SandboxSafetyIssueType.suspiciousPattern);
    if (hasMedium) return SandboxRiskLevel.medium;

    return SandboxRiskLevel.low;
  }
}
