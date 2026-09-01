import 'dart:convert';

import 'package:nudgee/core/agent/agent_event.dart';
import 'package:nudgee/core/agent/agent_stats.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';

/// A single trace entry — one atomic event in the agent's execution.
///
/// Each entry has a timestamp, a type, and structured data. Entries are
/// appended to an [AgentTrace] during a run and can be serialized to JSON
/// for persistence or debugging.
class TraceEntry {
  /// Monotonic sequence number within the trace.
  final int seq;

  /// Wall-clock timestamp.
  final DateTime timestamp;

  /// Elapsed time since the trace started.
  final Duration elapsed;

  /// Type of entry (see [TraceEntryType]).
  final TraceEntryType type;

  /// Human-readable summary.
  final String summary;

  /// Structured payload (type-specific).
  final Map<String, dynamic> data;

  const TraceEntry({
    required this.seq,
    required this.timestamp,
    required this.elapsed,
    required this.type,
    required this.summary,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'timestamp': timestamp.toIso8601String(),
        'elapsed_ms': elapsed.inMilliseconds,
        'type': type.name,
        'summary': summary,
        'data': data,
      };

  @override
  String toString() {
    final ms = elapsed.inMilliseconds.toString().padLeft(6, '0');
    return '[$ms] #${seq.toString().padLeft(3, '0')} ${type.icon} ${type.name.padRight(14)} $summary';
  }
}

/// Types of trace entries.
enum TraceEntryType {
  runStart('🚀'),
  runEnd('✅'),
  stepStart('📍'),
  stepEnd('📍'),
  llmRequest('📤'),
  llmResponse('📥'),
  llmStreamChunk('💧'),
  toolCall('🔧'),
  toolResult('📦'),
  permissionCheck('🔒'),
  permissionDenied('⛔'),
  permissionAsked('❓'),
  contextCompacted('🗜️'),
  contextSanitized('🧹'),
  error('❌'),
  warning('⚠️'),
  info('ℹ️');

  final String icon;
  const TraceEntryType(this.icon);
}

/// A trace of an agent run — a structured log of everything that happened.
///
/// Usage:
/// ```dart
/// final trace = AgentTrace();
/// trace.recordRunStart(input: 'What is 2+2?');
/// // ... during execution, call trace.record* methods ...
/// trace.recordRunEnd(stats: stats, finalReply: '4');
///
/// // Inspect
/// print(trace.format());
/// final json = trace.toJson();
/// ```
class AgentTrace {
  final List<TraceEntry> _entries = [];
  final DateTime _startTime = DateTime.now();
  int _seq = 0;

  List<TraceEntry> get entries => List.unmodifiable(_entries);
  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;

  /// Records the start of an agent run.
  void recordRunStart({
    required String input,
    String? agentId,
    String? model,
    List<String>? toolNames,
    int? maxSteps,
  }) {
    _add(
      TraceEntryType.runStart,
      'Agent run started',
      {
        'input': input,
        if (agentId != null) 'agentId': agentId,
        if (model != null) 'model': model,
        if (toolNames != null) 'toolNames': toolNames,
        if (maxSteps != null) 'maxSteps': maxSteps,
      },
    );
  }

  /// Records the end of an agent run.
  void recordRunEnd({
    required AgentRunStats stats,
    required String finalReply,
    String? finishReason,
  }) {
    _add(
      TraceEntryType.runEnd,
      'Agent run completed',
      {
        'stats': stats.toJson(),
        'finalReply': finalReply,
        if (finishReason != null) 'finishReason': finishReason,
      },
    );
  }

  /// Records the start of a ReAct step.
  void recordStepStart({required int step}) {
    _add(TraceEntryType.stepStart, 'Step $step started', {'step': step});
  }

  /// Records the end of a ReAct step.
  void recordStepEnd({required int step, required int tokenCount}) {
    _add(
      TraceEntryType.stepEnd,
      'Step $step ended (tokens so far: $tokenCount)',
      {'step': step, 'tokenCount': tokenCount},
    );
  }

  /// Records an LLM request.
  void recordLlmRequest({
    required int messageCount,
    required int toolCount,
    String? model,
    double? temperature,
    int? maxTokens,
    bool streaming = false,
  }) {
    _add(
      TraceEntryType.llmRequest,
      'LLM ${streaming ? "stream" : "chat"} request '
      '($messageCount messages, $toolCount tools)',
      {
        'messageCount': messageCount,
        'toolCount': toolCount,
        'streaming': streaming,
        if (model != null) 'model': model,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'maxTokens': maxTokens,
      },
    );
  }

  /// Records an LLM response (non-streaming).
  void recordLlmResponse({
    required LlmCompleteResponse response,
    int durationMs = 0,
  }) {
    final hasTools = response.hasToolCalls;
    _add(
      TraceEntryType.llmResponse,
      'LLM response: ${response.finishReason}'
      '${hasTools ? " (${response.toolCalls.length} tool calls)" : ""}'
      '${response.content.isNotEmpty ? " [${response.content.length} chars]" : ""}',
      {
        'finishReason': response.finishReason,
        'contentLength': response.content.length,
        'hasToolCalls': hasTools,
        'toolCallCount': response.toolCalls.length,
        if (response.usage != null) 'usage': response.usage!.toJson(),
        'durationMs': durationMs,
      },
    );
  }

  /// Records a streaming chunk.
  void recordLlmStreamChunk({
    String? contentDelta,
    String? thinkingDelta,
    bool isDone = false,
  }) {
    if (contentDelta == null && thinkingDelta == null && !isDone) return;
    _add(
      TraceEntryType.llmStreamChunk,
      isDone
          ? 'Stream done'
          : contentDelta != null
              ? 'Content: "${_truncate(contentDelta, 40)}"'
              : 'Thinking: "${_truncate(thinkingDelta!, 40)}"',
      {
        if (contentDelta != null) 'contentDelta': contentDelta,
        if (thinkingDelta != null) 'thinkingDelta': thinkingDelta,
        'isDone': isDone,
      },
    );
  }

  /// Records a tool call.
  void recordToolCall(ToolCall call) {
    _add(
      TraceEntryType.toolCall,
      'Tool: ${call.name}(${_formatArgs(call.arguments)})',
      {
        'toolCallId': call.id,
        'toolName': call.name,
        'arguments': call.arguments,
      },
    );
  }

  /// Records a tool result.
  void recordToolResult({
    required String toolName,
    required String toolCallId,
    required bool success,
    String? output,
    String? error,
    int durationMs = 0,
  }) {
    _add(
      TraceEntryType.toolResult,
      'Result: $toolName → ${success ? "✅" : "❌"} '
      '${_truncate(output ?? error ?? "", 60)}',
      {
        'toolName': toolName,
        'toolCallId': toolCallId,
        'success': success,
        if (output != null) 'output': output,
        if (error != null) 'error': error,
        'durationMs': durationMs,
      },
    );
  }

  /// Records a permission check.
  void recordPermissionCheck({
    required String toolName,
    required String decision,
    required String mode,
  }) {
    _add(
      TraceEntryType.permissionCheck,
      'Permission: $toolName → $decision (mode=$mode)',
      {
        'toolName': toolName,
        'decision': decision,
        'mode': mode,
      },
    );
  }

  /// Records a permission denial.
  void recordPermissionDenied({required String toolName, required String reason}) {
    _add(
      TraceEntryType.permissionDenied,
      'Denied: $toolName — $reason',
      {'toolName': toolName, 'reason': reason},
    );
  }

  /// Records a context compaction event.
  void recordContextCompacted({
    required int beforeTokens,
    required int afterTokens,
    required String strategy,
  }) {
    _add(
      TraceEntryType.contextCompacted,
      'Compacted: $beforeTokens → $afterTokens tokens ($strategy)',
      {
        'beforeTokens': beforeTokens,
        'afterTokens': afterTokens,
        'strategy': strategy,
      },
    );
  }

  /// Records a context sanitization event.
  void recordContextSanitized({required int issues, required int messageCount}) {
    _add(
      TraceEntryType.contextSanitized,
      'Sanitized: $issues issues in $messageCount messages',
      {'issues': issues, 'messageCount': messageCount},
    );
  }

  /// Records an error.
  void recordError(String message, {Map<String, dynamic>? data}) {
    _add(TraceEntryType.error, message, data ?? {});
  }

  /// Records a warning.
  void recordWarning(String message, {Map<String, dynamic>? data}) {
    _add(TraceEntryType.warning, message, data ?? {});
  }

  /// Records an info entry.
  void recordInfo(String message, {Map<String, dynamic>? data}) {
    _add(TraceEntryType.info, message, data ?? {});
  }

  /// Converts an [AgentEvent] to a trace entry.
  void recordEvent(AgentEvent event) {
    switch (event) {
      case ThinkingEvent(:final delta):
        recordLlmStreamChunk(thinkingDelta: delta);
      case ContentEvent(:final delta):
        recordLlmStreamChunk(contentDelta: delta);
      case ToolCallEvent(:final call):
        recordToolCall(call);
      case ToolResultEvent(:final toolName, :final result):
        recordToolResult(
          toolName: toolName,
          toolCallId: '',
          success: result.success,
          output: result.output?.toString(),
          error: result.error,
        );
      case PlanEvent(:final steps):
        recordInfo('Plan: ${steps.length} steps',
            data: {'steps': steps.map((s) => s.description).toList()});
      case HumanConfirmationEvent(:final call, :final reason):
        recordPermissionDenied(toolName: call.name, reason: reason);
      case LoopWarningEvent(:final stepCount):
        recordWarning('Loop detected at step $stepCount',
            data: {'stepCount': stepCount});
      case DoneEvent(:final finalReply, :final stats):
        recordRunEnd(stats: stats, finalReply: finalReply);
      case ErrorEvent(:final message, :final severity):
        recordError(message, data: {'severity': severity.name});
    }
  }

  // ── Internal helpers ──

  TraceEntry _add(TraceEntryType type, String summary, Map<String, dynamic> data) {
    final entry = TraceEntry(
      seq: _seq++,
      timestamp: DateTime.now(),
      elapsed: DateTime.now().difference(_startTime),
      type: type,
      summary: summary,
      data: data,
    );
    _entries.add(entry);
    return entry;
  }

  String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...';
  }

  String _formatArgs(Map<String, dynamic> args) {
    if (args.isEmpty) return '';
    final s = jsonEncode(args);
    return _truncate(s, 60);
  }

  // ── Output formats ──

  /// Formats the trace as a readable multi-line string for console output.
  String format({bool includeData = false}) {
    final buf = StringBuffer();
    buf.writeln('═══════════════════════════════════════════════════════════');
    buf.writeln('  Agent Trace — ${_entries.length} entries, '
        'started ${_startTime.toIso8601String()}');
    buf.writeln('═══════════════════════════════════════════════════════════');
    for (final e in _entries) {
      buf.writeln('  $e');
      if (includeData && e.data.isNotEmpty) {
        buf.writeln('    data: ${const JsonEncoder.withIndent('    ').convert(e.data)}');
      }
    }
    final totalMs = _entries.lastOrNull?.elapsed.inMilliseconds ?? 0;
    buf.writeln('───────────────────────────────────────────────────────────');
    buf.writeln('  Total: ${totalMs}ms, ${_entries.length} entries');
    buf.writeln('═══════════════════════════════════════════════════════════');
    return buf.toString();
  }

  /// Serializes the trace to a JSON string.
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Serializes the trace to a JSON map.
  Map<String, dynamic> toJson() => {
        'startTime': _startTime.toIso8601String(),
        'entryCount': _entries.length,
        'entries': _entries.map((e) => e.toJson()).toList(),
      };

  /// Clears all entries (for reuse).
  void clear() {
    _entries.clear();
    _seq = 0;
  }

  /// Filters entries by type.
  List<TraceEntry> findByType(TraceEntryType type) =>
      _entries.where((e) => e.type == type).toList();

  /// Gets all tool calls in order.
  List<TraceEntry> get toolCalls => findByType(TraceEntryType.toolCall);

  /// Gets all tool results in order.
  List<TraceEntry> get toolResults => findByType(TraceEntryType.toolResult);

  /// Gets all errors.
  List<TraceEntry> get errors => findByType(TraceEntryType.error);

  /// Gets all warnings.
  List<TraceEntry> get warnings => findByType(TraceEntryType.warning);
}
