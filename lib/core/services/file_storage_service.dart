import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Local file storage service.
///
/// Manages categorized local file storage under the app's documents directory:
/// - `avatars/`  — locally cached avatar images
/// - `cache/`    — generic cached files (images, media previews)
/// - `downloads/ — user-downloaded files
/// - `logs/`     — log files
class FileStorageService {
  FileStorageService();

  static const String dirAvatars = 'avatars';
  static const String dirCache = 'cache';
  static const String dirDownloads = 'downloads';
  static const String dirLogs = 'logs';

  static const List<String> categories = [
    dirAvatars,
    dirCache,
    dirDownloads,
    dirLogs,
  ];

  Directory? _baseDir;

  Future<Directory?> _base() async {
    if (_baseDir != null) return _baseDir;
    try {
      final base = await getApplicationDocumentsDirectory();
      _baseDir = base;
      return base;
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> directory(String category) async {
    final base = await _base();
    if (base == null) return null;
    final dir = Directory('${base.path}/$category');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<String?> pathFor(String category, String fileName) async {
    final dir = await directory(category);
    return dir == null ? null : '${dir.path}/$fileName';
  }

  Future<String?> saveBytes(
    String category,
    String fileName,
    List<int> bytes,
  ) async {
    final path = await pathFor(category, fileName);
    if (path == null) return null;
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<List<int>?> readBytes(String category, String fileName) async {
    final path = await pathFor(category, fileName);
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return await file.readAsBytes();
  }

  Future<bool> deleteFile(String category, String fileName) async {
    final path = await pathFor(category, fileName);
    if (path == null) return false;
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
      return true;
    }
    return false;
  }

  Future<int> categorySize(String category) async {
    final dir = await directory(category);
    if (dir == null || !dir.existsSync()) return 0;
    return _dirSize(dir);
  }

  Future<int> totalSize() async {
    var total = 0;
    for (final c in categories) {
      total += await categorySize(c);
    }
    return total;
  }

  Future<Map<String, int>> categorySizes() async {
    final result = <String, int>{};
    for (final c in categories) {
      result[c] = await categorySize(c);
    }
    return result;
  }

  Future<int> clearCategory(String category) async {
    final dir = await directory(category);
    if (dir == null || !dir.existsSync()) return 0;
    final size = await _dirSize(dir);
    await _wipeContents(dir);
    return size;
  }

  Future<int> clearAll() async {
    var freed = 0;
    for (final c in categories) {
      freed += await clearCategory(c);
    }
    return freed;
  }

  int _dirSize(Directory dir) {
    var total = 0;
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          total += entity.lengthSync();
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _wipeContents(Directory dir) async {
    try {
      for (final entity in dir.listSync()) {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      }
    } catch (_) {}
  }
}
