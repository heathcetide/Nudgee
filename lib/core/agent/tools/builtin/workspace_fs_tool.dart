import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';
import 'package:nudgee/core/di/injector.dart' as di;
import 'package:nudgee/core/services/workspace_service.dart';

/// Tool: workspace.fs
///
/// File system operations within the user's local workspace.
///
/// Supports:
/// - **write**: Create or overwrite a file
/// - **read**: Read file contents
/// - **list**: List files in a directory
/// - **delete**: Delete a file or directory
/// - **exists**: Check if a file/directory exists
/// - **mkdir**: Create a directory
/// - **info**: Get file metadata (size, modified date)
///
/// All paths are relative to the workspace root.
/// Path traversal (`../`) is blocked for security.
///
/// This lets the AI agent create projects, write code files,
/// and manage the user's local workspace.
class WorkspaceFsTool extends AgentTool {
  @override
  String get name => 'workspace.fs';

  @override
  String get description =>
      'File system operations in the user\'s local workspace. '
      'Actions: write, read, list, delete, exists, mkdir, info. '
      'Paths are relative to the workspace root. '
      'Use this to create projects, write code files, and manage files.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'description': 'Operation: write, read, list, delete, exists, mkdir, info',
            'enum': ['write', 'read', 'list', 'delete', 'exists', 'mkdir', 'info'],
          },
          'path': {
            'type': 'string',
            'description': 'Relative path (e.g. "projects/hello.js")',
          },
          'content': {
            'type': 'string',
            'description': 'File content (only for "write" action)',
          },
          'offset': {
            'type': 'integer',
            'description': 'Read offset for large files (only for "read" action). '
                'Files >8000 chars are chunked. Use offset to read subsequent chunks.',
          },
        },
        'required': ['action', 'path'],
      };

  final WorkspaceService? _workspace;

  /// Creates a [WorkspaceFsTool].
  ///
  /// If [workspace] is not provided, it will be lazily fetched from DI
  /// on first [execute] call.
  WorkspaceFsTool([this._workspace]);

  @override
  bool get isMutation => true;

  /// Gets the workspace service, from constructor or DI.
  /// Ensures it is initialized before returning.
  Future<WorkspaceService> _getWorkspace() async {
    final ws = _workspace ?? di.sl<WorkspaceService>();
    if (!ws.isInitialized) {
      await ws.init();
    }
    return ws;
  }

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final action = args['action'] as String?;
    final path = args['path'] as String?;

    if (action == null || action.isEmpty) {
      return const ToolResult.error('Missing required field: action');
    }
    if (path == null || path.isEmpty) {
      return const ToolResult.error('Missing required field: path');
    }

    final workspace = await _getWorkspace();

    try {
      switch (action) {
        case 'write':
          final content = args['content'] as String? ?? '';
          await workspace.writeFile(path, content);
          return ToolResult.success('File written: $path (${content.length} bytes)');

        case 'read':
          final content = await workspace.readFile(path);
          if (content == null) {
            return ToolResult.error('File not found: $path');
          }
          // Chunked reading for large files — return first chunk + metadata
          final maxChars = 8000; // ~8000 chars per chunk
          if (content.length <= maxChars) {
            return ToolResult.success(content);
          }
          final offset = (args['offset'] as int?) ?? 0;
          final end = (offset + maxChars).clamp(0, content.length);
          final chunk = content.substring(offset, end);
          final hasMore = end < content.length;
          final totalLines = content.split('\n').length;
          final chunkLines = chunk.split('\n').length;
          return ToolResult.success(
            'File: $path (${content.length} bytes, $totalLines lines)\n'
            'Showing lines ${offset ~/ 1}–${end ~/ 1} (chunk $chunkLines lines)\n'
            '─── content ───\n'
            '$chunk\n'
            '─── end of chunk ───\n'
            '${hasMore ? 'NOTE: File has more content. '
                'Use offset=$end to read the next chunk.' : 'End of file.'}',
          );

        case 'list':
          final entries = await workspace.listDir(path);
          if (entries.isEmpty) {
            return ToolResult.success('Directory is empty or does not exist: $path');
          }
          final formatted = entries.map((e) {
            final type = e.isDirectory ? '[DIR] ' : '[FILE]';
            final size = e.size != null ? ' (${_formatSize(e.size!)})' : '';
            return '$type ${e.relativePath}$size';
          }).join('\n');
          return ToolResult.success(
              'Listing $path (${entries.length} entries):\n$formatted');

        case 'delete':
          if (!await workspace.exists(path)) {
            return ToolResult.error('Not found: $path');
          }
          await workspace.delete(path);
          return ToolResult.success('Deleted: $path');

        case 'exists':
          final exists = await workspace.exists(path);
          return ToolResult.success(exists ? 'exists' : 'not found');

        case 'mkdir':
          await workspace.createDir(path);
          return ToolResult.success('Directory created: $path');

        case 'info':
          final info = await workspace.info(path);
          if (info == null) {
            return ToolResult.error('Not found: $path');
          }
          return ToolResult.success(
              'Name: ${info.name}\n'
              'Type: ${info.isDirectory ? "directory" : "file"}\n'
              'Size: ${info.size != null ? _formatSize(info.size!) : "N/A"}\n'
              'Modified: ${info.modified.toIso8601String()}');

        default:
          return ToolResult.error('Unknown action: $action. '
              'Supported: write, read, list, delete, exists, mkdir, info');
      }
    } catch (e) {
      debugPrint('[WorkspaceFsTool] error: $e');
      return ToolResult.error('Workspace operation failed: $e');
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
