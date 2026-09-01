import 'package:nudgee/core/agent/tools/tool_result.dart';

/// Tool category — used for filtering and UI display.
enum ToolCategory {
  /// Built-in tools (schedule, post, notification, etc.)
  builtin,

  /// Tools provided by MCP servers.
  mcp,

  /// Tools derived from skills.
  skill,

  /// Sandbox code execution tool.
  sandbox,
}

/// Abstract tool that an Agent can call.
///
/// Implementations:
/// - [ScheduleQueryTool], [ScheduleAddTool], etc. — built-in tools
/// - [SandboxExecTool] — sandbox code execution
/// - MCP tools — dynamically registered from MCP servers
///
/// Each tool has:
/// - A unique [name] (used by the LLM to call it)
/// - A [description] (shown to the LLM)
/// - A [parametersSchema] (JSON Schema for arguments)
/// - An [execute] method that performs the action
abstract class AgentTool {
  /// Tool name — must be unique across the registry.
  ///
  /// Use dot notation for namespacing: 'schedule.query', 'post.create'.
  String get name;

  /// Description shown to the LLM so it knows when to use this tool.
  String get description;

  /// JSON Schema for the tool's parameters.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Map<String, dynamic> get parametersSchema => {
  ///   'type': 'object',
  ///   'properties': {
  ///     'date': {'type': 'string', 'description': 'Date in YYYY-MM-DD format'},
  ///   },
  ///   'required': ['date'],
  /// };
  /// ```
  Map<String, dynamic> get parametersSchema;

  /// Tool category.
  ToolCategory get category => ToolCategory.builtin;

  /// Whether this tool requires human confirmation before executing.
  ///
  /// Override to `true` for sensitive operations (delete, publish, send).
  bool get requiresConfirmation => false;

  /// Whether this tool modifies state (vs read-only).
  ///
  /// Used by [PermissionMode.plan] to block mutations.
  bool get isMutation => false;

  /// Executes the tool with the given [args].
  ///
  /// [args] is the parsed JSON object from the LLM's tool call.
  /// Returns a [ToolResult] indicating success or failure.
  Future<ToolResult> execute(Map<String, dynamic> args);
}

/// A tool definition suitable for sending to the LLM.
///
/// Created from [AgentTool] and converted to [LlmToolDefinition].
class ToolDefinition {
  /// Tool name.
  final String name;

  /// Tool description.
  final String description;

  /// JSON Schema for parameters.
  final Map<String, dynamic> parametersSchema;

  /// Whether this tool requires confirmation.
  final bool requiresConfirmation;

  /// Tool category.
  final ToolCategory category;

  /// Whether this tool is a mutation.
  final bool isMutation;

  /// Creates a [ToolDefinition].
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parametersSchema,
    this.requiresConfirmation = false,
    this.category = ToolCategory.builtin,
    this.isMutation = false,
  });

  /// Creates from an [AgentTool].
  factory ToolDefinition.fromTool(AgentTool tool) => ToolDefinition(
        name: tool.name,
        description: tool.description,
        parametersSchema: tool.parametersSchema,
        requiresConfirmation: tool.requiresConfirmation,
        category: tool.category,
        isMutation: tool.isMutation,
      );

  @override
  String toString() => 'ToolDefinition($name)';
}
