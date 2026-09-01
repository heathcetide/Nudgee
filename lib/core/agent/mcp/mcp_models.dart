import 'package:nudgee/core/agent/tools/agent_tool.dart';

/// MCP transport type.
enum McpTransport {
  /// In-process (no network, direct call).
  inProcess,

  /// Streamable HTTP (remote, mobile-friendly).
  streamableHttp,

  /// Server-Sent Events (remote, legacy).
  sse,

  /// stdio (desktop only, spawns child process).
  stdio,
}

/// MCP server connection configuration.
class McpServerConfig {
  /// Unique server ID (e.g. "web-search", "nudgee-builtin").
  final String id;

  /// Human-readable name.
  final String name;

  /// Transport type.
  final McpTransport transport;

  /// Transport-specific config (e.g. {"url": "..."} for HTTP,
  /// {"command": "...", "arguments": [...]} for stdio).
  final Map<String, dynamic> transportConfig;

  /// Whether to auto-connect on startup.
  final bool autoConnect;

  /// Tool whitelist. null = allow all tools from this server.
  final List<String>? allowedTools;

  /// Whether tool calls require user confirmation.
  final bool requireConfirmation;

  /// Server description.
  final String? description;

  /// Creates an [McpServerConfig].
  const McpServerConfig({
    required this.id,
    required this.name,
    required this.transport,
    this.transportConfig = const {},
    this.autoConnect = true,
    this.allowedTools,
    this.requireConfirmation = false,
    this.description,
  });

  /// Creates an in-process config.
  factory McpServerConfig.inProcess({
    required String id,
    required String name,
    String? description,
  }) =>
      McpServerConfig(
        id: id,
        name: name,
        transport: McpTransport.inProcess,
        description: description,
      );

  /// Creates a streamable HTTP config.
  factory McpServerConfig.streamableHttp({
    required String id,
    required String name,
    required String url,
    String? description,
    List<String>? allowedTools,
    bool requireConfirmation = false,
  }) =>
      McpServerConfig(
        id: id,
        name: name,
        transport: McpTransport.streamableHttp,
        transportConfig: {'url': url},
        allowedTools: allowedTools,
        requireConfirmation: requireConfirmation,
        description: description,
      );

  @override
  String toString() => 'McpServerConfig($id, $transport)';
}

/// An MCP resource (readable data, identified by URI).
class McpResource {
  /// Resource URI (e.g. "file:///path", "config://app").
  final String uri;

  /// Human-readable name.
  final String name;

  /// Resource description.
  final String? description;

  /// MIME type (e.g. "text/plain", "application/json").
  final String? mimeType;

  /// The server ID that provides this resource.
  final String serverId;

  /// Creates an [McpResource].
  const McpResource({
    required this.uri,
    required this.name,
    this.description,
    this.mimeType,
    required this.serverId,
  });

  @override
  String toString() => 'McpResource($uri)';
}

/// An MCP prompt template.
class McpPrompt {
  /// Prompt name (unique within a server).
  final String name;

  /// Human-readable description.
  final String description;

  /// Argument definitions.
  final List<McpPromptArgument> arguments;

  /// The server ID that provides this prompt.
  final String serverId;

  /// Creates an [McpPrompt].
  const McpPrompt({
    required this.name,
    required this.description,
    this.arguments = const [],
    required this.serverId,
  });

  @override
  String toString() => 'McpPrompt($name)';
}

/// A prompt template argument.
class McpPromptArgument {
  final String name;
  final String description;
  final bool required;

  const McpPromptArgument({
    required this.name,
    required this.description,
    this.required = false,
  });
}

/// Connection state of an MCP server.
enum McpConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// A connection to an MCP server.
class McpConnection {
  final McpServerConfig config;
  McpConnectionState _state;

  /// Creates an [McpConnection].
  McpConnection(this.config) : _state = McpConnectionState.disconnected;

  /// Current connection state.
  McpConnectionState get state => _state;

  /// Whether the connection is active.
  bool get isConnected => _state == McpConnectionState.connected;

  /// Server ID.
  String get id => config.id;

  /// Transport type.
  McpTransport get transport => config.transport;

  /// Updates the connection state (internal use).
  void setState(McpConnectionState newState) {
    _state = newState;
  }

  @override
  String toString() => 'McpConnection($id, $_state)';
}

/// A tool provided by an MCP server.
///
/// Wraps [ToolDefinition] with the source server ID.
class McpTool {
  /// The tool definition.
  final ToolDefinition definition;

  /// The server ID that provides this tool.
  final String serverId;

  /// Creates an [McpTool].
  const McpTool({
    required this.definition,
    required this.serverId,
  });

  /// Tool name.
  String get name => definition.name;

  @override
  String toString() => 'McpTool($serverId:${definition.name})';
}
