import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/mcp/mcp_models.dart';
import 'package:nudgee/core/agent/mcp/mcp_server_interface.dart';
import 'package:nudgee/core/agent/mcp/in_process_mcp_server.dart';
import 'package:nudgee/core/agent/tools/tool_registry.dart';

/// MCP Manager — manages all MCP server connections.
///
/// Responsibilities:
/// 1. Register/connect/disconnect MCP servers
/// 2. Aggregate tools from all connected servers
/// 3. Route tool calls to the correct server
/// 4. Provide resource and prompt access
/// 5. Auto-register MCP tools into a [ToolRegistry] (via [McpToolAdapter])
/// 6. Reconnect remote servers on app resume
///
/// Server types:
/// - [InProcessMcpServer] — wraps built-in tools (no network)
/// - [RemoteHttpMcpServer] — connects to remote servers via HTTP
/// - (future) stdio MCP server for desktop
class McpManager {
  /// Registered servers by ID.
  final Map<String, McpServerInterface> _servers = {};

  /// Connection states by server ID.
  final Map<String, McpConnection> _connections = {};

  /// Tool registry to auto-register MCP tools into.
  final ToolRegistry? _toolRegistry;

  /// Whether to auto-register MCP tools into the tool registry.
  final bool autoRegisterTools;

  /// Creates an [McpManager].
  ///
  /// If [toolRegistry] is provided and [autoRegisterTools] is true,
  /// MCP tools are automatically registered as [McpToolAdapter]s.
  McpManager({
    ToolRegistry? toolRegistry,
    this.autoRegisterTools = true,
  }) : _toolRegistry = toolRegistry;

  /// Registers a server (does not connect yet).
  void register(McpServerInterface server) {
    _servers[server.id] = server;
    _connections[server.id] = McpConnection(server.config);
    debugPrint('[McpManager] registered server: ${server.id}');
  }

  /// Registers and connects to a server.
  Future<void> connect(McpServerInterface server) async {
    register(server);
    await _connectServer(server);
  }

  /// Connects to a registered server by ID.
  Future<void> connectById(String serverId) async {
    final server = _servers[serverId];
    if (server == null) {
      throw ArgumentError('Server not registered: $serverId');
    }
    await _connectServer(server);
  }

  Future<void> _connectServer(McpServerInterface server) async {
    final conn = _connections[server.id];
    if (conn == null) return;

    conn.setState(McpConnectionState.connecting);
    try {
      await server.connect();
      conn.setState(McpConnectionState.connected);

      // Auto-register tools
      if (autoRegisterTools && _toolRegistry != null) {
        _registerToolsIntoRegistry(server);
      }

      debugPrint('[McpManager] connected: ${server.id} '
          '(${server.listTools().length} tools)');
    } catch (e) {
      conn.setState(McpConnectionState.error);
      debugPrint('[McpManager] connect error for ${server.id}: $e');
      rethrow;
    }
  }

  /// Disconnects from a server.
  Future<void> disconnect(String serverId) async {
    final server = _servers[serverId];
    if (server == null) return;

    // Unregister tools
    if (autoRegisterTools && _toolRegistry != null) {
      _unregisterToolsFromRegistry(server);
    }

    await server.disconnect();
    _connections[serverId]?.setState(McpConnectionState.disconnected);
    debugPrint('[McpManager] disconnected: $serverId');
  }

  /// Unregisters a server.
  Future<void> unregister(String serverId) async {
    await disconnect(serverId);
    _servers.remove(serverId);
    _connections.remove(serverId);
  }

  /// Gets a server by ID.
  McpServerInterface? getServer(String serverId) => _servers[serverId];

  /// All registered server IDs.
  List<String> get serverIds => _servers.keys.toList();

  /// All connected servers.
  List<McpServerInterface> get connectedServers =>
      _servers.values.where((s) => s.isConnected).toList();

  /// All connections with their states.
  Map<String, McpConnection> get connections =>
      Map.unmodifiable(_connections);

  /// Number of registered servers.
  int get length => _servers.length;

  /// Whether a server is registered.
  bool contains(String serverId) => _servers.containsKey(serverId);

  /// Aggregates tools from all connected servers.
  ///
  /// Returns a list of [McpTool] with the source server ID.
  List<McpTool> allTools() {
    final tools = <McpTool>[];
    for (final server in _servers.values) {
      if (!server.isConnected) continue;
      for (final def in server.listTools()) {
        // Apply whitelist
        final config = server.config;
        if (config.allowedTools != null &&
            !config.allowedTools!.contains(def.name)) {
          continue;
        }
        tools.add(McpTool(definition: def, serverId: server.id));
      }
    }
    return tools;
  }

  /// Aggregates resources from all connected servers.
  List<McpResource> allResources() {
    final resources = <McpResource>[];
    for (final server in _servers.values) {
      if (!server.isConnected) continue;
      resources.addAll(server.listResources());
    }
    return resources;
  }

  /// Aggregates prompts from all connected servers.
  List<McpPrompt> allPrompts() {
    final prompts = <McpPrompt>[];
    for (final server in _servers.values) {
      if (!server.isConnected) continue;
      prompts.addAll(server.listPrompts());
    }
    return prompts;
  }

  /// Calls a tool on the specified server.
  Future<McpToolResult> callTool(
      String serverId, String toolName, Map<String, dynamic> args) async {
    final server = _servers[serverId];
    if (server == null) {
      return McpToolResult.error('Server not found: $serverId');
    }
    if (!server.isConnected) {
      return McpToolResult.error('Server not connected: $serverId');
    }
    return server.callTool(toolName, args);
  }

  /// Calls a tool by its global name (searches all connected servers).
  ///
  /// Returns the result from the first server that has the tool.
  Future<McpToolResult> callToolByName(
      String toolName, Map<String, dynamic> args) async {
    for (final server in _servers.values) {
      if (!server.isConnected) continue;
      final tools = server.listTools();
      if (tools.any((t) => t.name == toolName)) {
        // Check whitelist
        final config = server.config;
        if (config.allowedTools != null &&
            !config.allowedTools!.contains(toolName)) {
          continue;
        }
        return server.callTool(toolName, args);
      }
    }
    return McpToolResult.error('Tool not found on any connected server: $toolName');
  }

  /// Reads a resource from the specified server.
  Future<String> readResource(String serverId, String uri) async {
    final server = _servers[serverId];
    if (server == null) {
      throw ArgumentError('Server not found: $serverId');
    }
    return server.readResource(uri);
  }

  /// Applies a prompt template from the specified server.
  Future<String> applyPrompt(
      String serverId, String name, Map<String, dynamic> args) async {
    final server = _servers[serverId];
    if (server == null) {
      throw ArgumentError('Server not found: $serverId');
    }
    return server.applyPrompt(name, args);
  }

  /// Reconnects all disconnected remote servers.
  ///
  /// Called on app resume (from background) to restore HTTP connections.
  Future<void> onAppResume() async {
    for (final entry in _connections.entries) {
      final conn = entry.value;
      if (conn.transport == McpTransport.streamableHttp ||
          conn.transport == McpTransport.sse) {
        if (!conn.isConnected) {
          try {
            await connectById(entry.key);
            debugPrint('[McpManager] reconnected on resume: ${entry.key}');
          } catch (e) {
            debugPrint('[McpManager] reconnect failed for ${entry.key}: $e');
          }
        }
      }
    }
  }

  /// Disconnects all servers.
  Future<void> disconnectAll() async {
    for (final id in _servers.keys.toList()) {
      await disconnect(id);
    }
  }

  // ── Tool registry integration ──────────────────────────────────────────

  void _registerToolsIntoRegistry(McpServerInterface server) {
    if (_toolRegistry == null) return;

    for (final def in server.listTools()) {
      // Check whitelist
      final config = server.config;
      if (config.allowedTools != null &&
          !config.allowedTools!.contains(def.name)) {
        continue;
      }

      // Skip if already registered (avoid duplicates)
      if (_toolRegistry.contains(def.name)) {
        // If it's already an McpToolAdapter for this server, skip
        final existing = _toolRegistry.get(def.name);
        if (existing is McpToolAdapter && existing.server.id == server.id) {
          continue;
        }
        // Don't override existing non-MCP tools
        if (existing is! McpToolAdapter) {
          debugPrint('[McpManager] tool ${def.name} already registered, '
              'skipping MCP registration');
          continue;
        }
      }

      _toolRegistry.register(McpToolAdapter(
        server: server,
        definition: def,
      ));
    }
  }

  void _unregisterToolsFromRegistry(McpServerInterface server) {
    if (_toolRegistry == null) return;

    // Find and remove tools that are McpToolAdapters for this server
    final toRemove = <String>[];
    for (final name in _toolRegistry.names) {
      final tool = _toolRegistry.get(name);
      if (tool is McpToolAdapter && tool.server.id == server.id) {
        toRemove.add(name);
      }
    }
    for (final name in toRemove) {
      _toolRegistry.unregister(name);
    }
  }
}
