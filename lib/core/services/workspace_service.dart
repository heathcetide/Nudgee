import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages the local user workspace — a sandboxed directory where the AI
/// agent can create, read, edit, and delete files.
///
/// The workspace lives in the app's documents directory:
/// - iOS: `<Documents>/workspace/`
/// - Android: `<Files>/workspace/`
///
/// This is the "user space" where the AI writes code, creates projects,
/// and stores output. Files persist across app restarts.
///
/// Usage:
/// ```dart
/// final ws = sl<WorkspaceService>();
/// await ws.init();
///
/// // Create a file
/// await ws.writeFile('projects/hello.js', 'console.log("Hello!");');
///
/// // Read a file
/// final content = await ws.readFile('projects/hello.js');
///
/// // List files
/// final files = await ws.listDir('projects');
/// ```
class WorkspaceService {
  Directory? _workspaceDir;
  bool _initialized = false;

  /// Whether the workspace is initialized.
  bool get isInitialized => _initialized;

  /// The workspace directory path.
  String? get workspacePath => _workspaceDir?.path;

  /// Initializes the workspace directory.
  ///
  /// Creates the directory if it doesn't exist.
  Future<void> init() async {
    if (_initialized) return;

    try {
      final baseDir = await getApplicationDocumentsDirectory();
      _workspaceDir = Directory(p.join(baseDir.path, 'workspace'));
      if (!_workspaceDir!.existsSync()) {
        await _workspaceDir!.create(recursive: true);
      }
      _initialized = true;
      debugPrint('[WorkspaceService] initialized at ${_workspaceDir!.path}');
    } catch (e) {
      debugPrint('[WorkspaceService] init failed: $e');
    }
  }

  /// Resolves a relative path to an absolute path within the workspace.
  ///
  /// Security: rejects paths that try to escape the workspace via `../`.
  String resolvePath(String relativePath) {
    if (!_initialized) throw StateError('Workspace not initialized');

    // Normalize and check for path traversal
    final normalized = p.normalize(relativePath);
    if (p.isAbsolute(normalized)) {
      throw ArgumentError('Absolute paths not allowed: $relativePath');
    }
    if (normalized.startsWith('..') || normalized.contains('../')) {
      throw ArgumentError('Path traversal not allowed: $relativePath');
    }

    return p.join(_workspaceDir!.path, normalized);
  }

  /// Writes content to a file in the workspace.
  ///
  /// Creates parent directories if needed.
  Future<void> writeFile(String relativePath, String content) async {
    final absPath = resolvePath(relativePath);
    final file = File(absPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// Reads a file from the workspace.
  ///
  /// Returns null if the file doesn't exist.
  Future<String?> readFile(String relativePath) async {
    final absPath = resolvePath(relativePath);
    final file = File(absPath);
    if (!file.existsSync()) return null;
    return file.readAsString();
  }

  /// Checks if a file exists.
  Future<bool> exists(String relativePath) async {
    final absPath = resolvePath(relativePath);
    return File(absPath).existsSync() || Directory(absPath).existsSync();
  }

  /// Lists files in a directory.
  ///
  /// Returns a list of relative paths (relative to the workspace root).
  Future<List<WorkspaceEntry>> listDir(String relativePath) async {
    final absPath = resolvePath(relativePath);
    final dir = Directory(absPath);
    if (!dir.existsSync()) return [];

    final entries = <WorkspaceEntry>[];
    for (final entity in dir.listSync()) {
      final name = p.basename(entity.path);
      final relPath = p.relative(entity.path, from: _workspaceDir!.path);
      entries.add(WorkspaceEntry(
        name: name,
        relativePath: relPath,
        isDirectory: entity is Directory,
        size: entity is File ? entity.lengthSync() : null,
        modified: entity.statSync().modified,
      ));
    }

    // Sort: directories first, then files, alphabetically
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });

    return entries;
  }

  /// Creates a directory in the workspace.
  Future<void> createDir(String relativePath) async {
    final absPath = resolvePath(relativePath);
    await Directory(absPath).create(recursive: true);
  }

  /// Deletes a file or directory.
  Future<void> delete(String relativePath) async {
    final absPath = resolvePath(relativePath);
    final file = File(absPath);
    final dir = Directory(absPath);
    if (file.existsSync()) {
      await file.delete();
    } else if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  /// Gets file info.
  Future<WorkspaceEntry?> info(String relativePath) async {
    final absPath = resolvePath(relativePath);
    final file = File(absPath);
    final dir = Directory(absPath);

    if (file.existsSync()) {
      final stat = file.statSync();
      return WorkspaceEntry(
        name: p.basename(absPath),
        relativePath: relativePath,
        isDirectory: false,
        size: stat.size,
        modified: stat.modified,
      );
    } else if (dir.existsSync()) {
      final stat = dir.statSync();
      return WorkspaceEntry(
        name: p.basename(absPath),
        relativePath: relativePath,
        isDirectory: true,
        size: null,
        modified: stat.modified,
      );
    }
    return null;
  }

  /// Lists all files in the workspace (recursive).
  Future<List<WorkspaceEntry>> listAll() async {
    if (!_initialized) return [];
    return listDir('.');
  }

  /// Clears the entire workspace.
  Future<void> clear() async {
    if (!_initialized) return;
    await _workspaceDir!.delete(recursive: true);
    await _workspaceDir!.create(recursive: true);
  }
}

/// A file or directory entry in the workspace.
class WorkspaceEntry {
  final String name;
  final String relativePath;
  final bool isDirectory;
  final int? size;
  final DateTime modified;

  const WorkspaceEntry({
    required this.name,
    required this.relativePath,
    required this.isDirectory,
    this.size,
    required this.modified,
  });

  @override
  String toString() =>
      'WorkspaceEntry($relativePath, ${isDirectory ? "dir" : "file"}${size != null ? ", ${size}B" : ""})';
}
