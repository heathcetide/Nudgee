import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/mcp/mcp_models.dart';
import 'package:nudgee/core/agent/mcp/mcp_server_interface.dart';
import 'package:nudgee/core/agent/tools/agent_tool.dart' show ToolDefinition, ToolCategory;

/// Remote MCP Server via Streamable HTTP transport.
///
/// Connects to a remote MCP server using HTTP POST for requests
/// and SSE (Server-Sent Events) for streaming responses.
///
/// Mobile-friendly: works on iOS/Android (foreground), macOS, Web.
/// Note: HTTP long connections are cut by the OS when the app goes
/// to background. Use [reconnect] on app resume.
class RemoteHttpMcpServer implements McpServerInterface {
  @override
  final String id;

  @override
  final McpServerConfig config;

  final HttpClient _httpClient;

  bool _connected = false;
  final List<ToolDefinition> _tools = [];
  final List<McpResource> _resources = [];
  final List<McpPrompt> _prompts = [];

  /// JSON-RPC request ID counter.
  int _requestId = 0;

  /// Creates a [RemoteHttpMcpServer].
  RemoteHttpMcpServer({
    required this.config,
    String? id,
  })  : id = id ?? config.id,
        _httpClient = HttpClient() {
    if (config.transport != McpTransport.streamableHttp &&
        config.transport != McpTransport.sse) {
      throw ArgumentError(
          'RemoteHttpMcpServer requires streamableHttp or sse transport, '
          'got ${config.transport}');
    }
  }

  /// The server URL from transport config.
  String get _url {
    final url = config.transportConfig['url'] as String?;
    if (url == null) {
      throw StateError('No URL in transport config for server "$id"');
    }
    return url;
  }

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    if (_connected) return;

    try {
      // Initialize handshake (JSON-RPC 2.0)
      await _sendRequest('initialize', {
        'protocolVersion': '2024-11-05',
        'capabilities': {
          'tools': {},
          'resources': {},
          'prompts': {},
        },
        'clientInfo': {
          'name': 'nudgee',
          'version': '1.0.0',
        },
      });

      // Send initialized notification
      await _sendNotification('notifications/initialized', {});

      // Discover tools
      await _refreshTools();

      // Discover resources
      try {
        await _refreshResources();
      } catch (e) {
        debugPrint('[RemoteHttpMcpServer] resources not supported: $e');
      }

      // Discover prompts
      try {
        await _refreshPrompts();
      } catch (e) {
        debugPrint('[RemoteHttpMcpServer] prompts not supported: $e');
      }

      _connected = true;
      debugPrint('[RemoteHttpMcpServer] connected ($id, '
          '${_tools.length} tools, ${_resources.length} resources, '
          '${_prompts.length} prompts)');
    } catch (e) {
      _connected = false;
      debugPrint('[RemoteHttpMcpServer] connect error: $e');
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _tools.clear();
    _resources.clear();
    _prompts.clear();
    _httpClient.close();
    debugPrint('[RemoteHttpMcpServer] disconnected ($id)');
  }

  /// Reconnects after a disconnection (e.g. app resume from background).
  Future<void> reconnect() async {
    _connected = false;
    _tools.clear();
    _resources.clear();
    _prompts.clear();
    await connect();
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
    if (!_connected) {
      return const McpToolResult.error('Server not connected');
    }

    try {
      final response = await _sendRequest('tools/call', {
        'name': name,
        'arguments': arguments,
      });

      final result = response['result'] as Map<String, dynamic>?;
      if (result == null) {
        return const McpToolResult.error('No result in response');
      }

      final isError = result['isError'] as bool? ?? false;
      final content = result['content'] as List?;

      if (isError) {
        final errorText = content?.isNotEmpty == true
            ? (content!.first as Map)['text'] as String? ?? 'Unknown error'
            : 'Unknown error';
        return McpToolResult.error(errorText);
      }

      // Extract text from content array
      final textParts = <String>[];
      if (content != null) {
        for (final item in content) {
          if (item is Map) {
            final text = item['text'];
            if (text != null) textParts.add(text.toString());
          }
        }
      }

      return McpToolResult.success(textParts.join('\n'));
    } catch (e) {
      return McpToolResult.error(e.toString());
    }
  }

  @override
  Future<String> readResource(String uri) async {
    if (!_connected) {
      throw StateError('Server not connected');
    }

    final response = await _sendRequest('resources/read', {
      'uri': uri,
    });

    final result = response['result'] as Map<String, dynamic>?;
    if (result == null) {
      throw StateError('No result in response');
    }

    final contents = result['contents'] as List?;
    if (contents == null || contents.isEmpty) {
      throw StateError('Resource "$uri" returned no content');
    }

    final firstContent = contents.first as Map;
    return firstContent['text'] as String? ?? '';
  }

  @override
  Future<String> applyPrompt(
      String name, Map<String, dynamic> arguments) async {
    if (!_connected) {
      throw StateError('Server not connected');
    }

    final response = await _sendRequest('prompts/get', {
      'name': name,
      'arguments': arguments,
    });

    final result = response['result'] as Map<String, dynamic>?;
    if (result == null) {
      throw StateError('No result in response');
    }

    final messages = result['messages'] as List?;
    if (messages == null || messages.isEmpty) {
      throw StateError('Prompt "$name" returned no messages');
    }

    final textParts = <String>[];
    for (final msg in messages) {
      if (msg is Map) {
        final content = msg['content'];
        if (content is Map) {
          final text = content['text'];
          if (text != null) textParts.add(text.toString());
        }
      }
    }

    return textParts.join('\n');
  }

  // ── JSON-RPC helpers ──────────────────────────────────────────────────

  Future<void> _refreshTools() async {
    final response = await _sendRequest('tools/list', {});
    final result = response['result'] as Map<String, dynamic>?;
    final tools = result?['tools'] as List?;
    _tools.clear();
    if (tools != null) {
      for (final tool in tools) {
        if (tool is Map) {
          _tools.add(ToolDefinition(
            name: tool['name'] as String,
            description: tool['description'] as String? ?? '',
            parametersSchema: tool['inputSchema'] as Map<String, dynamic>? ?? {},
            category: ToolCategory.mcp,
          ));
        }
      }
    }
  }

  Future<void> _refreshResources() async {
    final response = await _sendRequest('resources/list', {});
    final result = response['result'] as Map<String, dynamic>?;
    final resources = result?['resources'] as List?;
    _resources.clear();
    if (resources != null) {
      for (final res in resources) {
        if (res is Map) {
          _resources.add(McpResource(
            uri: res['uri'] as String,
            name: res['name'] as String? ?? res['uri'] as String,
            description: res['description'] as String?,
            mimeType: res['mimeType'] as String?,
            serverId: id,
          ));
        }
      }
    }
  }

  Future<void> _refreshPrompts() async {
    final response = await _sendRequest('prompts/list', {});
    final result = response['result'] as Map<String, dynamic>?;
    final prompts = result?['prompts'] as List?;
    _prompts.clear();
    if (prompts != null) {
      for (final p in prompts) {
        if (p is Map) {
          final args = p['arguments'] as List? ?? [];
          _prompts.add(McpPrompt(
            name: p['name'] as String,
            description: p['description'] as String? ?? '',
            arguments: args
                .map((a) => McpPromptArgument(
                      name: (a as Map)['name'] as String? ?? '',
                      description: a['description'] as String? ?? '',
                      required: a['required'] as bool? ?? false,
                    ))
                .toList(),
            serverId: id,
          ));
        }
      }
    }
  }

  Future<Map<String, dynamic>> _sendRequest(
      String method, Map<String, dynamic> params) async {
    final requestId = ++_requestId;
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': requestId,
      'method': method,
      'params': params,
    });

    final response = await _httpPost(body);
    return _parseResponse(response);
  }

  Future<void> _sendNotification(
      String method, Map<String, dynamic> params) async {
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    });
    await _httpPost(body);
  }

  Future<String> _httpPost(String body) async {
    final uri = Uri.parse(_url);
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(body);
    final response = await request.close();
    return await response.transform(utf8.decoder).join();
  }

  Map<String, dynamic> _parseResponse(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Invalid JSON-RPC response: $decoded');
    }

    // Check for error
    final error = decoded['error'];
    if (error != null) {
      final message = (error as Map)['message'] as String? ?? 'Unknown error';
      final code = error['code'];
      throw McpRpcException(message, code: code);
    }

    return decoded;
  }
}

/// JSON-RPC error from an MCP server.
class McpRpcException implements Exception {
  final String message;
  final dynamic code;

  const McpRpcException(this.message, {this.code});

  @override
  String toString() => 'McpRpcException($code): $message';
}
