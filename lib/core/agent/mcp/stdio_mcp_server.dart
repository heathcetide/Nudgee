import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/mcp/mcp_models.dart';
import 'package:nudgee/core/agent/mcp/mcp_server_interface.dart';
import 'package:nudgee/core/agent/tools/agent_tool.dart';

/// stdio MCP Server — connects to an MCP server via a child process.
///
/// This transport is for desktop platforms (macOS, Linux, Windows) where
/// the app can spawn a child process and communicate via stdin/stdout
/// using JSON-RPC 2.0 over newline-delimited messages.
///
/// Configuration ([McpServerConfig.transportConfig]):
/// - `command`: The executable to run (e.g. "npx", "python", "node")
/// - `arguments`: List of command arguments
/// - `env`: Optional environment variables
/// - `workingDirectory`: Optional working directory
///
/// Example:
/// ```dart
/// final server = StdioMcpServer(
///   config: McpServerConfig(
///     id: 'filesystem',
///     name: 'Filesystem MCP',
///     transport: McpTransport.stdio,
///     transportConfig: {
///       'command': 'npx',
///       'arguments': ['-y', '@modelcontextprotocol/server-filesystem', '/tmp'],
///     },
///   ),
/// );
/// await server.connect();
/// final tools = server.listTools();
/// ```
class StdioMcpServer implements McpServerInterface {
  @override
  final McpServerConfig config;

  /// The child process.
  Process? _process;

  /// Whether the server is connected.
  bool _connected = false;

  /// Pending requests awaiting responses (keyed by request ID).
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  /// Request ID counter.
  int _nextId = 1;

  /// Tools discovered from the server.
  final List<ToolDefinition> _tools = [];

  /// Resources discovered from the server.
  final List<McpResource> _resources = [];

  /// Prompts discovered from the server.
  final List<McpPrompt> _prompts = [];

  /// Stream subscription for stdout.
  StreamSubscription<String>? _stdoutSub;

  /// Buffer for incomplete JSON lines.
  final StringBuffer _lineBuffer = StringBuffer();

  /// Creates a [StdioMcpServer].
  StdioMcpServer({required this.config});

  @override
  String get id => config.id;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    if (_connected) return;

    final command = config.transportConfig['command'] as String?;
    final args = (config.transportConfig['arguments'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const <String>[];
    final env = config.transportConfig['env'] as Map<String, dynamic>?;
    final workingDir = config.transportConfig['workingDirectory'] as String?;

    if (command == null) {
      throw ArgumentError('stdio transport requires "command" in transportConfig');
    }

    try {
      _process = await Process.start(
        command,
        args,
        environment: env?.map((k, v) => MapEntry(k, v.toString())),
        workingDirectory: workingDir,
      );

      _connected = true;
      debugPrint('[StdioMcpServer] started: $command ${args.join(" ")} '
          '(pid=${_process!.pid})');

      // Listen to stdout (JSON-RPC responses)
      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleLine);

      // Log stderr for debugging
      _process!.stderr
          .transform(utf8.decoder)
          .listen((data) {
        debugPrint('[StdioMcpServer] stderr: $data');
      });

      // Initialize the MCP connection
      await _initialize();

      // Discover tools, resources, and prompts
      await _discoverCapabilities();

      debugPrint('[StdioMcpServer] connected: $id '
          '(${_tools.length} tools, ${_resources.length} resources, '
          '${_prompts.length} prompts)');
    } catch (e) {
      _connected = false;
      debugPrint('[StdioMcpServer] connect error: $e');
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _stdoutSub?.cancel();
    _stdoutSub = null;

    // Send shutdown notification
    if (_process != null) {
      try {
        _sendNotification('notifications/cancelled', {});
        _process!.stdin.close();
        await _process!.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            _process!.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      } catch (_) {
        _process?.kill(ProcessSignal.sigkill);
      }
    }

    _process = null;
    _connected = false;
    _tools.clear();
    _resources.clear();
    _prompts.clear();

    // Cancel any pending requests
    for (final completer in _pending.values) {
      completer.completeError('Server disconnected');
    }
    _pending.clear();

    debugPrint('[StdioMcpServer] disconnected: $id');
  }

  @override
  List<ToolDefinition> listTools() => List.unmodifiable(_tools);

  @override
  List<McpResource> listResources() => List.unmodifiable(_resources);

  @override
  List<McpPrompt> listPrompts() => List.unmodifiable(_prompts);

  @override
  Future<McpToolResult> callTool(
      String name, Map<String, dynamic> arguments) async {
    if (!_connected || _process == null) {
      return const McpToolResult.error('Server not connected');
    }

    try {
      final response = await _sendRequest('tools/call', {
        'name': name,
        'arguments': arguments,
      });

      final result = response['result'] as Map<String, dynamic>?;
      if (result == null) {
        return const McpToolResult.error('Empty result from server');
      }

      final isError = result['isError'] as bool? ?? false;
      final content = result['content'] as List<dynamic>?;

      if (isError) {
        final errorText = content
                ?.map((c) => (c as Map<String, dynamic>)['text'] as String?)
                .join('\n') ??
            'Unknown error';
        return McpToolResult.error(errorText);
      }

      final output = content
              ?.map((c) => (c as Map<String, dynamic>)['text'] as String?)
              .join('\n') ??
          '';
      return McpToolResult.success(output);
    } catch (e) {
      return McpToolResult.error('Tool call failed: $e');
    }
  }

  @override
  Future<String> readResource(String uri) async {
    if (!_connected || _process == null) {
      throw StateError('Server not connected');
    }

    final response = await _sendRequest('resources/read', {'uri': uri});
    final result = response['result'] as Map<String, dynamic>?;
    final contents = result?['contents'] as List<dynamic>?;

    if (contents == null || contents.isEmpty) {
      throw ArgumentError('Resource not found: $uri');
    }

    final text = (contents.first as Map<String, dynamic>)['text'] as String?;
    return text ?? '';
  }

  @override
  Future<String> applyPrompt(
      String name, Map<String, dynamic> arguments) async {
    if (!_connected || _process == null) {
      throw StateError('Server not connected');
    }

    final response = await _sendRequest('prompts/get', {
      'name': name,
      'arguments': arguments,
    });
    final result = response['result'] as Map<String, dynamic>?;
    final messages = result?['messages'] as List<dynamic>?;

    if (messages == null || messages.isEmpty) {
      throw ArgumentError('Prompt not found: $name');
    }

    final content = (messages.first as Map<String, dynamic>)['content']
        as Map<String, dynamic>?;
    return content?['text'] as String? ?? '';
  }

  // ── JSON-RPC protocol ──────────────────────────────────────────────────

  Future<void> _initialize() async {
    await _sendRequest('initialize', {
      'protocolVersion': '2024-11-05',
      'capabilities': {
        'roots': {'listChanged': true},
      },
      'clientInfo': {
        'name': 'nudgee-agent',
        'version': '1.0.0',
      },
    });

    // Send initialized notification
    _sendNotification('notifications/initialized', {});
  }

  Future<void> _discoverCapabilities() async {
    // Discover tools
    try {
      final toolsResponse = await _sendRequest('tools/list', {});
      final toolsResult = toolsResponse['result'] as Map<String, dynamic>?;
      final toolsList = toolsResult?['tools'] as List<dynamic>? ?? [];
      _tools.clear();
      for (final tool in toolsList) {
        final toolMap = tool as Map<String, dynamic>;
        _tools.add(ToolDefinition(
          name: toolMap['name'] as String,
          description: toolMap['description'] as String? ?? '',
          parametersSchema:
              toolMap['inputSchema'] as Map<String, dynamic>? ?? const {},
        ));
      }
    } catch (e) {
      debugPrint('[StdioMcpServer] tools/list error: $e');
    }

    // Discover resources
    try {
      final resourcesResponse = await _sendRequest('resources/list', {});
      final resourcesResult =
          resourcesResponse['result'] as Map<String, dynamic>?;
      final resourcesList =
          resourcesResult?['resources'] as List<dynamic>? ?? [];
      _resources.clear();
      for (final resource in resourcesList) {
        final resMap = resource as Map<String, dynamic>;
        _resources.add(McpResource(
          uri: resMap['uri'] as String,
          name: resMap['name'] as String? ?? '',
          description: resMap['description'] as String?,
          mimeType: resMap['mimeType'] as String?,
          serverId: id,
        ));
      }
    } catch (e) {
      // Resources may not be supported — that's fine
    }

    // Discover prompts
    try {
      final promptsResponse = await _sendRequest('prompts/list', {});
      final promptsResult = promptsResponse['result'] as Map<String, dynamic>?;
      final promptsList = promptsResult?['prompts'] as List<dynamic>? ?? [];
      _prompts.clear();
      for (final prompt in promptsList) {
        final promptMap = prompt as Map<String, dynamic>;
        final argsList = promptMap['arguments'] as List<dynamic>? ?? [];
        _prompts.add(McpPrompt(
          name: promptMap['name'] as String,
          description: promptMap['description'] as String? ?? '',
          arguments: argsList
              .map((a) => McpPromptArgument(
                    name: (a as Map<String, dynamic>)['name'] as String? ?? '',
                    description:
                        a['description'] as String? ?? '',
                    required: a['required'] as bool? ?? false,
                  ))
              .toList(),
          serverId: id,
        ));
      }
    } catch (e) {
      // Prompts may not be supported — that's fine
    }
  }

  /// Sends a JSON-RPC request and waits for the response.
  Future<Map<String, dynamic>> _sendRequest(
      String method, Map<String, dynamic> params) async {
    final requestIds = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[requestIds] = completer;

    final message = jsonEncode({
      'jsonrpc': '2.0',
      'id': requestIds,
      'method': method,
      'params': params,
    });

    _process!.stdin.writeln(message);

    // Timeout after 30 seconds
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pending.remove(requestIds);
        throw TimeoutException('Request "$method" timed out');
      },
    );
  }

  /// Sends a JSON-RPC notification (no response expected).
  void _sendNotification(String method, Map<String, dynamic> params) {
    final message = jsonEncode({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    });
    _process?.stdin.writeln(message);
  }

  /// Handles a line from stdout.
  void _handleLine(String line) {
    if (line.isEmpty) return;

    // Buffer incomplete lines
    _lineBuffer.write(line);
    final fullLine = _lineBuffer.toString();
    _lineBuffer.clear();

    try {
      final message = jsonDecode(fullLine) as Map<String, dynamic>;
      final id = message['id'];

      if (id != null && _pending.containsKey(id)) {
        final completer = _pending.remove(id)!;
        if (message.containsKey('error')) {
          completer.completeError(
              'RPC error: ${message['error']}');
        } else {
          completer.complete(message);
        }
      }
      // Notifications from server are ignored for now
    } catch (e) {
      // Not valid JSON — could be a partial line or server log
      debugPrint('[StdioMcpServer] parse error: $e (line: $fullLine)');
    }
  }
}
