import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/mcp/mcp_models.dart';
import 'package:nudgee/core/agent/mcp/mcp_server_interface.dart';
import 'package:nudgee/core/agent/tools/agent_tool.dart' show AgentTool, ToolDefinition, ToolCategory;
import 'package:nudgee/core/agent/tools/tool_registry.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

/// In-Process MCP Server — wraps built-in [ToolRegistry] as an MCP server.
///
/// This is the mobile-friendly MCP adapter: no network, no child process.
/// It exposes the app's existing tools (schedule, post, notification, etc.)
/// through the standard MCP interface, so the [McpManager] can treat them
/// identically to remote MCP servers.
///
/// Usage:
/// ```dart
/// final inProcess = InProcessMcpServer(toolRegistry: registry);
/// await mcpManager.register(inProcess);
/// ```
class InProcessMcpServer implements McpServerInterface {
  @override
  final String id;

  /// The tool registry to wrap.
  final ToolRegistry toolRegistry;

  /// Optional resource provider (for custom resources).
  final Map<String, String Function()> _resourceProviders;

  /// Optional prompt providers.
  final Map<String, String Function(Map<String, dynamic>)> _promptProviders;

  bool _connected = false;

  /// Creates an [InProcessMcpServer].
  ///
  /// [id] defaults to "nudgee-builtin".
  /// [resourceProviders] maps URI -> content provider function.
  /// [promptProviders] maps prompt name -> template renderer.
  InProcessMcpServer({
    required this.toolRegistry,
    this.id = 'nudgee-builtin',
    Map<String, String Function()>? resourceProviders,
    Map<String, String Function(Map<String, dynamic>)>? promptProviders,
  })  : _resourceProviders = resourceProviders ?? {},
        _promptProviders = promptProviders ?? {};

  @override
  McpServerConfig get config => McpServerConfig.inProcess(
        id: id,
        name: 'Nudgee Builtin',
        description: 'In-process MCP server wrapping built-in tools',
      );

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _connected = true;
    debugPrint('[InProcessMcpServer] connected ($id, '
        '${toolRegistry.length} tools)');
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    debugPrint('[InProcessMcpServer] disconnected ($id)');
  }

  @override
  List<ToolDefinition> listTools() {
    return toolRegistry.definitionsFor();
  }

  @override
  Future<McpToolResult> callTool(
      String name, Map<String, dynamic> arguments) async {
    if (!_connected) {
      return const McpToolResult.error('Server not connected');
    }

    try {
      final result = await toolRegistry.execute(name, arguments);
      if (result.success) {
        return McpToolResult.success(result.output);
      } else {
        return McpToolResult.error(result.error ?? 'Tool execution failed');
      }
    } catch (e) {
      return McpToolResult.error(e.toString());
    }
  }

  @override
  List<McpResource> listResources() {
    return _resourceProviders.keys.map((uri) {
      return McpResource(
        uri: uri,
        name: uri,
        serverId: id,
      );
    }).toList();
  }

  @override
  Future<String> readResource(String uri) async {
    final provider = _resourceProviders[uri];
    if (provider == null) {
      throw ArgumentError('Resource not found: $uri');
    }
    return provider();
  }

  @override
  List<McpPrompt> listPrompts() {
    return _promptProviders.keys.map((name) {
      return McpPrompt(
        name: name,
        description: 'Prompt template: $name',
        serverId: id,
      );
    }).toList();
  }

  @override
  Future<String> applyPrompt(
      String name, Map<String, dynamic> arguments) async {
    final provider = _promptProviders[name];
    if (provider == null) {
      throw ArgumentError('Prompt not found: $name');
    }
    return provider(arguments);
  }

  /// Registers a custom resource provider.
  void registerResource(String uri, String Function() provider) {
    _resourceProviders[uri] = provider;
  }

  /// Registers a custom prompt template.
  void registerPrompt(
      String name, String Function(Map<String, dynamic>) provider) {
    _promptProviders[name] = provider;
  }
}

/// Adapter that wraps an MCP tool as an [AgentTool], so it can be
/// registered in a [ToolRegistry] and used by the agent.
///
/// When the agent calls this tool, it delegates to the MCP server.
class McpToolAdapter extends AgentTool {
  /// The MCP server to delegate to.
  final McpServerInterface server;

  /// The tool definition from the MCP server.
  final ToolDefinition definition;

  /// Creates an [McpToolAdapter].
  McpToolAdapter({
    required this.server,
    required this.definition,
  });

  @override
  String get name => definition.name;

  @override
  String get description => definition.description;

  @override
  Map<String, dynamic> get parametersSchema => definition.parametersSchema;

  @override
  ToolCategory get category => ToolCategory.mcp;

  @override
  bool get requiresConfirmation => server.config.requireConfirmation;

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    try {
      final result = await server.callTool(name, arguments);
      if (result.success) {
        return ToolResult.success(result.output);
      } else {
        return ToolResult.error(result.error);
      }
    } catch (e) {
      return ToolResult.error(e.toString());
    }
  }
}
