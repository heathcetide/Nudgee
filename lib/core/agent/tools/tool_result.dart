/// The result of executing a tool.
///
/// Returned by [AgentTool.execute] and emitted in [AgentEvent.toolResult].
class ToolResult {
  /// Whether the tool executed successfully.
  final bool success;

  /// The tool's output (string or JSON-serializable object).
  final dynamic output;

  /// Error message if [success] is false.
  final String? error;

  /// Execution duration.
  final Duration? duration;

  /// Creates a successful result.
  const ToolResult.success(this.output, {this.duration})
      : success = true,
        error = null;

  /// Creates an error result.
  const ToolResult.error(this.error, {this.duration})
      : success = false,
        output = null;

  /// Creates a [ToolResult] with explicit fields.
  const ToolResult({
    required this.success,
    this.output,
    this.error,
    this.duration,
  });

  /// Converts to a string for the LLM (tool result message content).
  ///
  /// The LLM sees this as the tool's response. Errors are clearly marked
  /// so the LLM can adjust its approach.
  String toLlmContent() {
    if (!success) {
      return 'Error: $error';
    }
    if (output == null) return 'Success (no output)';
    if (output is String) return output as String;
    return output.toString();
  }

  @override
  String toString() =>
      success ? 'ToolResult(ok, $output)' : 'ToolResult(error: $error)';
}
