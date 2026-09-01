import 'dart:async';

import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

/// Registry of tools available to Agents.
///
/// Manages tool registration, lookup, and execution. Tools are registered
/// once at startup and shared across all Agents.
///
/// Usage:
/// ```dart
/// final registry = ToolRegistry();
/// registry.register(ScheduleQueryTool(scheduleService));
/// registry.register(ScheduleAddTool(scheduleService));
///
/// // Get definitions for LLM
/// final defs = registry.definitionsFor(['schedule.query', 'schedule.add']);
///
/// // Execute a tool call
/// final result = await registry.execute('schedule.query', {'date': '2026-09-01'});
/// ```
class ToolRegistry {
  final Map<String, AgentTool> _tools = {};

  /// Registers a tool.
  ///
  /// If a tool with the same name already exists, it is replaced.
  void register(AgentTool tool) {
    _tools[tool.name] = tool;
  }

  /// Registers multiple tools at once.
  void registerAll(List<AgentTool> tools) {
    for (final tool in tools) {
      register(tool);
    }
  }

  /// Unregisters a tool by name.
  void unregister(String name) {
    _tools.remove(name);
  }

  /// Whether a tool with [name] is registered.
  bool contains(String name) => _tools.containsKey(name);

  /// Gets the tool with [name], or null if not found.
  AgentTool? get(String name) => _tools[name];

  /// All registered tool names.
  List<String> get names => _tools.keys.toList();

  /// All registered tools.
  List<AgentTool> get tools => _tools.values.toList();

  /// Gets tool definitions for the specified tool names.
  ///
  /// If [names] is null, returns all definitions.
  /// Unknown names are silently skipped.
  List<ToolDefinition> definitionsFor([List<String>? names]) {
    if (names == null) {
      return _tools.values.map(ToolDefinition.fromTool).toList();
    }
    return names
        .map((n) => _tools[n])
        .whereType<AgentTool>()
        .map(ToolDefinition.fromTool)
        .toList();
  }

  /// Whether the tool with [name] requires confirmation.
  bool needsConfirmation(String name) {
    return _tools[name]?.requiresConfirmation ?? false;
  }

  /// Whether the tool with [name] is a mutation.
  bool isMutation(String name) {
    return _tools[name]?.isMutation ?? false;
  }

  /// Executes the tool with [name] using [args].
  ///
  /// Throws [ToolNotFoundException] if the tool is not registered.
  /// Returns a [ToolResult] — never throws for tool execution errors
  /// (those are captured in the result).
  Future<ToolResult> execute(String name, Map<String, dynamic> args) async {
    final tool = _tools[name];
    if (tool == null) {
      return ToolResult.error('Tool "$name" not found');
    }

    final stopwatch = Stopwatch()..start();
    try {
      final result = await tool.execute(args);
      stopwatch.stop();
      // Attach duration if not already set
      if (result.duration == null) {
        return ToolResult(
          success: result.success,
          output: result.output,
          error: result.error,
          duration: stopwatch.elapsed,
        );
      }
      return result;
    } catch (e, st) {
      stopwatch.stop();
      return ToolResult(
        success: false,
        error: '$e\n$st',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Clears all registered tools.
  void clear() {
    _tools.clear();
  }

  /// Number of registered tools.
  int get length => _tools.length;
}

/// Exception thrown when a tool is not found.
class ToolNotFoundException implements Exception {
  final String toolName;

  /// Creates a [ToolNotFoundException].
  const ToolNotFoundException(this.toolName);

  @override
  String toString() => 'ToolNotFoundException: $toolName';
}
