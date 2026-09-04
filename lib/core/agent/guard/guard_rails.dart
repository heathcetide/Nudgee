import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/agent_event.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

/// Guardrails — safety layer that sits between the LLM's decisions and
/// actual tool execution / output delivery.
///
/// Responsibilities:
/// 1. **Output filtering**: detect and redact sensitive content (PII,
///    secrets, harmful content) from agent replies and tool results.
/// 2. **Dangerous operation interception**: block or warn when the agent
///    attempts potentially harmful tool calls (e.g. mass deletion,
///    sending messages to all users).
/// 3. **Rate limiting**: prevent the agent from calling tools too
///    frequently within a time window, which could indicate a runaway
///    loop or resource exhaustion.
class GuardRails {
  /// Output filters applied to content and tool results.
  final List<OutputFilter> outputFilters;

  /// Tool call interceptors that can block or modify calls.
  final List<ToolCallInterceptor> interceptors;

  /// Rate limiter for tool calls.
  final RateLimiter? rateLimiter;

  /// Maximum total tool calls per agent run.
  final int maxToolCallsPerRun;

  /// Creates [GuardRails] with optional filters, interceptors, and limits.
  const GuardRails({
    this.outputFilters = const [],
    this.interceptors = const [],
    this.rateLimiter,
    this.maxToolCallsPerRun = 50,
  });

  /// Default guardrails with standard safety rules.
  factory GuardRails.defaultRails() => GuardRails(
        outputFilters: [
          SecretRedactionFilter(),
          PiiRedactionFilter(),
        ],
        interceptors: [
          DangerousToolInterceptor(),
        ],
        rateLimiter: SlidingWindowRateLimiter(
          maxCalls: 20,
          window: const Duration(seconds: 60),
        ),
        maxToolCallsPerRun: 50,
      );

  /// Checks a tool call before execution.
  ///
  /// Returns a [GuardDecision] indicating whether to allow, block, or
  /// modify the call.
  GuardDecision checkToolCall(ToolCall call, int currentCallCount) {
    // Check total call count
    if (currentCallCount >= maxToolCallsPerRun) {
      return GuardDecision.block(
        'Maximum tool calls per run ($maxToolCallsPerRun) exceeded. '
        'The agent is making too many tool calls.',
      );
    }

    // Check rate limit
    if (rateLimiter != null && !rateLimiter!.tryAcquire(call.name)) {
      return GuardDecision.block(
        'Rate limit exceeded for tool "${call.name}". '
        'Too many calls within the time window.',
      );
    }

    // Run interceptors
    for (final interceptor in interceptors) {
      final decision = interceptor.check(call);
      if (decision.isBlock) return decision;
    }

    return const GuardDecision.allow();
  }

  /// Filters agent output content before delivering to the UI.
  String filterOutput(String content) {
    var filtered = content;
    for (final filter in outputFilters) {
      filtered = filter.apply(filtered);
    }
    return filtered;
  }

  /// Filters a tool result before feeding it back to the LLM.
  ToolResult filterToolResult(ToolResult result) {
    if (result.output is String) {
      final filtered = filterOutput(result.output as String);
      if (filtered != result.output) {
        return ToolResult(
          success: result.success,
          output: filtered,
          error: result.error,
          duration: result.duration,
        );
      }
    }
    return result;
  }
}

/// Decision returned by guardrails.
class GuardDecision {
  final GuardAction action;
  final String? reason;
  final Map<String, dynamic>? modifiedArguments;

  const GuardDecision._(this.action, {this.reason, this.modifiedArguments});

  const GuardDecision.allow() : this._(GuardAction.allow);

  const GuardDecision.block(String reason)
      : this._(GuardAction.block, reason: reason);

  const GuardDecision.modify(Map<String, dynamic> newArgs, String reason)
      : this._(GuardAction.modify, reason: reason, modifiedArguments: newArgs);

  bool get isAllow => action == GuardAction.allow;
  bool get isBlock => action == GuardAction.block;
  bool get isModify => action == GuardAction.modify;
}

/// Actions the guard can take.
enum GuardAction { allow, block, modify }

/// Output filter — transforms content to remove or redact sensitive data.
abstract class OutputFilter {
  String apply(String content);
}

/// Tool call interceptor — inspects and potentially blocks tool calls.
abstract class ToolCallInterceptor {
  GuardDecision check(ToolCall call);
}

/// Redacts common secret patterns (API keys, tokens, passwords).
class SecretRedactionFilter implements OutputFilter {
  static final _patterns = <(RegExp, String)>[
    (RegExp(r'(?:api[_-]?key|apikey)["\s:=]+([A-Za-z0-9_\-]{20,})', caseSensitive: false), '[REDACTED_API_KEY]'),
    (RegExp(r'(?:token|access[_-]?token|refresh[_-]?token)["\s:=]+([A-Za-z0-9_\-\.]{20,})', caseSensitive: false), '[REDACTED_TOKEN]'),
    (RegExp(r'(?:password|passwd|pwd)["\s:=]+(\S+)', caseSensitive: false), '[REDACTED_PASSWORD]'),
    (RegExp(r'(?:secret)["\s:=]+([A-Za-z0-9_\-]{16,})', caseSensitive: false), '[REDACTED_SECRET]'),
    (RegExp(r'Bearer\s+([A-Za-z0-9_\-\.]{20,})', caseSensitive: false), 'Bearer [REDACTED]'),
    (RegExp(r'-----BEGIN [A-Z ]+PRIVATE KEY-----[\s\S]*?-----END [A-Z ]+PRIVATE KEY-----'), '[REDACTED_PRIVATE_KEY]'),
  ];

  @override
  String apply(String content) {
    var result = content;
    for (final (pattern, replacement) in _patterns) {
      result = result.replaceAllMapped(pattern, (m) {
        return m.group(0)!.replaceFirst(m.group(1)!, replacement);
      });
    }
    return result;
  }
}

/// Redacts common PII patterns (email, phone, ID card numbers).
class PiiRedactionFilter implements OutputFilter {
  static final _emailPattern = RegExp(r'\b([A-Za-z0-9._%+-]+)@([A-Za-z0-9.-]+\.[A-Z|a-z]{2,})\b');
  static final _phonePattern = RegExp(r'\b1[3-9]\d{9}\b');
  static final _idCardPattern = RegExp(r'\b\d{17}[\dXx]\b');

  @override
  String apply(String content) {
    var result = content;
    result = result.replaceAllMapped(_emailPattern, (m) => '[REDACTED_EMAIL]@${m.group(2)}');
    result = result.replaceAll(_phonePattern, '[REDACTED_PHONE]');
    result = result.replaceAll(_idCardPattern, '[REDACTED_ID]');
    return result;
  }
}

/// Intercepts dangerous tool calls — operations that could cause
/// irreversible damage if executed incorrectly.
class DangerousToolInterceptor implements ToolCallInterceptor {
  /// Tool names that are always blocked.
  static const _blockedTools = <String>{
    'system.shutdown',
    'system.factory_reset',
    'device.wipe',
  };

  @override
  GuardDecision check(ToolCall call) {
    if (_blockedTools.contains(call.name)) {
      return GuardDecision.block(
        'Tool "${call.name}" is blocked by guardrails — '
        'this operation is too dangerous for autonomous execution.',
      );
    }

    // Check for dangerous argument patterns
    if (call.name == 'workspace.fs.delete' || call.name == 'git.delete') {
      final path = call.arguments['path'] as String? ?? '';
      if (path == '/' || path.isEmpty || path == '.') {
        return GuardDecision.block(
          'Refusing to delete root path "$path" — '
          'this would cause irreversible damage.',
        );
      }
    }

    return const GuardDecision.allow();
  }
}

/// Rate limiter — limits how many tool calls can be made within a time window.
abstract class RateLimiter {
  /// Tries to acquire a permit for [toolName].
  ///
  /// Returns `true` if the call is allowed, `false` if rate limited.
  bool tryAcquire(String toolName);
}

/// Sliding window rate limiter — tracks calls per tool within a time window.
class SlidingWindowRateLimiter implements RateLimiter {
  final int maxCalls;
  final Duration window;
  final Map<String, List<DateTime>> _callHistory = {};

  SlidingWindowRateLimiter({required this.maxCalls, required this.window});

  @override
  bool tryAcquire(String toolName) {
    final now = DateTime.now();
    final cutoff = now.subtract(window);

    _callHistory[toolName] ??= <DateTime>[];
    final history = _callHistory[toolName]!;

    // Remove expired entries
    history.removeWhere((t) => t.isBefore(cutoff));

    if (history.length >= maxCalls) {
      debugPrint('[GuardRails] rate limit hit for "$toolName": '
          '${history.length} calls in last ${window.inSeconds}s');
      return false;
    }

    history.add(now);
    return true;
  }
}
