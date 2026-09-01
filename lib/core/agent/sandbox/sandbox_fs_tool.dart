import 'dart:convert';
import 'dart:io';

import 'package:nudgee/core/agent/sandbox/sandbox.dart';
import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

/// Tool: sandbox.fs
///
/// File system operations within a sandboxed directory.
///
/// The agent can use this tool to:
/// - Read files (text)
/// - Write files (text)
/// - List directory contents
/// - Create directories
/// - Delete files
/// - Check if a file/directory exists
/// - Get file info (size, modified time)
///
/// All operations are restricted to a sandbox root directory to prevent
/// unauthorized access to the host file system.
///
/// Example agent usage:
/// ```json
/// {
///   "name": "sandbox.fs",
///   "arguments": {
///     "operation": "read",
///     "path": "data/test.txt"
///   }
/// }
/// ```
class SandboxFsTool extends AgentTool {
  /// The sandbox root directory. All paths are relative to this.
  final String sandboxRoot;

  /// Whether to allow write operations.
  final bool allowWrite;

  /// Whether to allow delete operations.
  final bool allowDelete;

  /// Creates a [SandboxFsTool].
  ///
  /// [sandboxRoot] is the base directory for all file operations.
  /// The directory will be created if it doesn't exist.
  SandboxFsTool({
    required this.sandboxRoot,
    this.allowWrite = true,
    this.allowDelete = false,
  }) {
    // Ensure sandbox root exists
    final dir = Directory(sandboxRoot);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  @override
  String get name => 'sandbox.fs';

  @override
  String get description =>
      'File system operations within a sandboxed directory. '
      'Supports: read, write, list, mkdir, delete, exists, info. '
      'All paths are relative to the sandbox root. '
      'Write operations require allowWrite permission. '
      'Delete operations require allowDelete permission.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'operation': {
            'type': 'string',
            'description': 'The file operation to perform',
            'enum': ['read', 'write', 'list', 'mkdir', 'delete', 'exists', 'info'],
          },
          'path': {
            'type': 'string',
            'description':
                'File/directory path (relative to sandbox root)',
          },
          'content': {
            'type': 'string',
            'description': 'Content to write (for write operation)',
          },
        },
        'required': ['operation', 'path'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final operation = args['operation'] as String?;
    if (operation == null) {
      return const ToolResult.error('Missing required field: operation');
    }

    final path = args['path'] as String?;
    if (path == null) {
      return const ToolResult.error('Missing required field: path');
    }

    // Resolve and validate path (prevent path traversal)
    final resolvedPath = _resolvePath(path);
    if (resolvedPath == null) {
      return ToolResult.error(
          'Invalid path: "$path" escapes sandbox root');
    }

    try {
      switch (operation) {
        case 'read':
          return _read(resolvedPath);
        case 'write':
          if (!allowWrite) {
            return const ToolResult.error(
                'Write operations are not allowed');
          }
          final content = args['content'] as String? ?? '';
          return _write(resolvedPath, content);
        case 'list':
          return _list(resolvedPath);
        case 'mkdir':
          if (!allowWrite) {
            return const ToolResult.error(
                'Write operations are not allowed');
          }
          return _mkdir(resolvedPath);
        case 'delete':
          if (!allowDelete) {
            return const ToolResult.error(
                'Delete operations are not allowed');
          }
          return _delete(resolvedPath);
        case 'exists':
          return _exists(resolvedPath);
        case 'info':
          return _info(resolvedPath);
        default:
          return ToolResult.error('Unknown operation: $operation');
      }
    } catch (e) {
      return ToolResult.error('File operation failed: $e');
    }
  }

  /// Resolves a relative path to an absolute path within the sandbox.
  ///
  /// Returns null if the path escapes the sandbox root (path traversal attack)
  /// or if an absolute path is provided.
  String? _resolvePath(String relativePath) {
    // Normalize the path — remove leading slashes, normalize backslashes
    var normalized = relativePath.replaceAll('\\', '/');
    // Reject absolute paths (they should be relative to sandbox root)
    if (normalized.startsWith('/')) {
      return null;
    }
    // Remove leading slashes (safety)
    normalized = normalized.replaceAll(RegExp(r'^/+'), '');

    // Build the full path
    final sandboxPath = Directory(sandboxRoot).absolute.path;
    final fullPath = '$sandboxPath/$normalized';

    // Canonicalize both paths for comparison
    // Use simple normalization: resolve . and .. segments
    final sandboxCanonical = _normalizePath(sandboxPath);
    final fullCanonical = _normalizePath(fullPath);

    // Check the full path is within the sandbox
    if (!fullCanonical.startsWith(sandboxCanonical)) {
      return null;
    }

    return fullCanonical;
  }

  /// Normalizes a path by resolving . and .. segments.
  String _normalizePath(String path) {
    final segments = <String>[];
    for (final seg in path.split('/')) {
      if (seg == '' || seg == '.') continue;
      if (seg == '..') {
        if (segments.isNotEmpty) {
          segments.removeLast();
        }
        continue;
      }
      segments.add(seg);
    }
    return '/' + segments.join('/');
  }

  ToolResult _read(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return ToolResult.error('File not found: $path');
    }
    final content = file.readAsStringSync();
    final truncated = content.length > 10000
        ? '${content.substring(0, 10000)}\n... (truncated, ${content.length} total chars)'
        : content;
    return ToolResult.success(truncated);
  }

  ToolResult _write(String path, String content) {
    final file = File(path);
    // Create parent directories if needed
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    return ToolResult.success(
        'Wrote ${content.length} chars to ${_relativePath(path)}');
  }

  ToolResult _list(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      return ToolResult.error('Directory not found: $path');
    }
    final entries = dir.listSync();
    if (entries.isEmpty) {
      return ToolResult.success('(empty directory)');
    }
    final lines = entries.map((e) {
      final name = e.path.split('/').last;
      final type = e is Directory ? 'dir ' : 'file';
      final size = e is File ? '${e.lengthSync()} bytes' : '';
      return '$type  $name${size.isNotEmpty ? "  ($size)" : ""}';
    }).join('\n');
    return ToolResult.success(lines);
  }

  ToolResult _mkdir(String path) {
    final dir = Directory(path);
    if (dir.existsSync()) {
      return ToolResult.success('Directory already exists: $path');
    }
    dir.createSync(recursive: true);
    return ToolResult.success('Created directory: ${_relativePath(path)}');
  }

  ToolResult _delete(String path) {
    final file = File(path);
    final dir = Directory(path);
    if (file.existsSync()) {
      file.deleteSync();
      return ToolResult.success('Deleted file: ${_relativePath(path)}');
    } else if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
      return ToolResult.success('Deleted directory: ${_relativePath(path)}');
    }
    return ToolResult.error('Not found: $path');
  }

  ToolResult _exists(String path) {
    final file = File(path);
    final dir = Directory(path);
    if (file.existsSync()) {
      return ToolResult.success('exists (file)');
    } else if (dir.existsSync()) {
      return ToolResult.success('exists (directory)');
    }
    return ToolResult.success('not found');
  }

  ToolResult _info(String path) {
    final file = File(path);
    final dir = Directory(path);
    if (file.existsSync()) {
      final stat = file.statSync();
      return ToolResult.success(
          'type: file\n'
          'size: ${stat.size} bytes\n'
          'modified: ${stat.modified}\n'
          'path: ${_relativePath(path)}');
    } else if (dir.existsSync()) {
      final stat = dir.statSync();
      final entries = dir.listSync().length;
      return ToolResult.success(
          'type: directory\n'
          'entries: $entries\n'
          'modified: ${stat.modified}\n'
          'path: ${_relativePath(path)}');
    }
    return ToolResult.error('Not found: $path');
  }

  String _relativePath(String absolutePath) {
    final root = Directory(sandboxRoot).absolute.path;
    if (absolutePath.startsWith(root)) {
      final rel = absolutePath.substring(root.length);
      return rel.replaceAll(RegExp(r'^/+'), '');
    }
    return absolutePath;
  }
}

/// Registers file system bridge functions into a [SandboxExecutor].
///
/// These bridge functions allow sandboxed code to perform file operations
/// through the bridge API (instead of direct dart:io access).
///
/// The bridge functions are:
/// - `fs.read(path)` — read a text file
/// - `fs.write(path, content)` — write a text file
/// - `fs.list(path)` — list directory contents
/// - `fs.exists(path)` — check if a file/directory exists
/// - `fs.mkdir(path)` — create a directory
/// - `fs.delete(path)` — delete a file or directory
void registerFsBridgeFunctions(
  SandboxExecutor executor, {
  required String sandboxRoot,
  bool allowWrite = true,
  bool allowDelete = false,
}) {
  String resolvePath(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    return '$sandboxRoot/$normalized'.replaceAll(RegExp(r'/+'), '/');
  }

  executor.registerBridgeFunction('fs.read', (args, kwargs) async {
    final path = resolvePath(args[0] as String);
    final file = File(path);
    if (!file.existsSync()) {
      throw SandboxEvalException('File not found: ${args[0]}');
    }
    return file.readAsStringSync();
  });

  if (allowWrite) {
    executor.registerBridgeFunction('fs.write', (args, kwargs) async {
      final path = resolvePath(args[0] as String);
      final content = args[1] as String;
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
      return 'wrote ${content.length} chars';
    });

    executor.registerBridgeFunction('fs.mkdir', (args, kwargs) async {
      final path = resolvePath(args[0] as String);
      Directory(path).createSync(recursive: true);
      return 'created';
    });
  }

  executor.registerBridgeFunction('fs.exists', (args, kwargs) async {
    final path = resolvePath(args[0] as String);
    return File(path).existsSync() || Directory(path).existsSync();
  });

  executor.registerBridgeFunction('fs.list', (args, kwargs) async {
    final path = resolvePath(args[0] as String);
    final dir = Directory(path);
    if (!dir.existsSync()) {
      throw SandboxEvalException('Directory not found: ${args[0]}');
    }
    final entries = dir.listSync().map((e) => e.path.split('/').last).toList();
    return jsonEncode(entries);
  });

  if (allowDelete) {
    executor.registerBridgeFunction('fs.delete', (args, kwargs) async {
      final path = resolvePath(args[0] as String);
      final file = File(path);
      final dir = Directory(path);
      if (file.existsSync()) {
        file.deleteSync();
      } else if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
      return 'deleted';
    });
  }
}
