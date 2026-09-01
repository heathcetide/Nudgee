import 'package:nudgee/core/agent/mcp/mcp_models.dart';
import 'package:nudgee/core/agent/tools/agent_tool.dart';

/// Interface that all MCP servers must implement.
///
/// This is the contract for both:
/// - [InProcessMcpServer] — wraps built-in services (no network)
/// - [RemoteHttpMcpServer] — connects to remote MCP server via HTTP
/// - (future) stdio MCP server for desktop
///
/// The [McpManager] interacts with all servers through this interface,
/// so in-process and remote servers are treated uniformly.
abstract class McpServerInterface {
  /// Server ID (matches [McpServerConfig.id]).
  String get id;

  /// Server config.
  McpServerConfig get config;

  /// Whether the server is connected and ready.
  bool get isConnected;

  /// Connects to the server (no-op for in-process).
  Future<void> connect();

  /// Disconnects from the server.
  Future<void> disconnect();

  /// Lists tools provided by this server.
  List<ToolDefinition> listTools();

  /// Calls a tool by name with arguments.
  ///
  /// Returns the tool's output (string or JSON-serializable object).
  /// Throws if the tool doesn't exist or execution fails.
  Future<McpToolResult> callTool(
      String name, Map<String, dynamic> arguments);

  /// Lists resources provided by this server.
  List<McpResource> listResources() => [];

  /// Reads a resource by URI.
  ///
  /// Returns the resource content as a string.
  /// Throws if the resource doesn't exist.
  Future<String> readResource(String uri) async {
    throw UnsupportedError('Server "$id" does not support resources');
  }

  /// Lists prompt templates provided by this server.
  List<McpPrompt> listPrompts() => [];

  /// Applies a prompt template with arguments.
  ///
  /// Returns the rendered prompt text.
  /// Throws if the prompt doesn't exist.
  Future<String> applyPrompt(
      String name, Map<String, dynamic> arguments) async {
    throw UnsupportedError('Server "$id" does not support prompts');
  }
}

/// Result of an MCP tool call.
class McpToolResult {
  /// Whether the call succeeded.
  final bool success;

  /// The tool's output (string or JSON-serializable object).
  final dynamic output;

  /// Error message if [success] is false.
  final String? error;

  /// Whether the result is an error.
  const McpToolResult.success(this.output)
      : success = true,
        error = null;

  /// Creates an error result.
  const McpToolResult.error(this.error)
      : success = false,
        output = null;

  /// Creates a [McpToolResult] with explicit fields.
  const McpToolResult({
    required this.success,
    this.output,
    this.error,
  });

  @override
  String toString() =>
      success ? 'McpToolResult(ok, $output)' : 'McpToolResult(error: $error)';
}
