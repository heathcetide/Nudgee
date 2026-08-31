import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:nudgee/core/models/ling_log_entry.dart';

/// Persists [LingLogEntry] instances to daily-rotated log files on disk.
///
/// Each log file is named `log_YYYY_MM_DD.txt` and contains one log line per
/// entry. Files older than [maxDays] are automatically purged on init and on
/// each write cycle. Writes are buffered through an [IOSink] and flushed
/// periodically or on demand via [flush].
class LogFileService {
  LogFileService({this.maxDays = 7});

  /// Maximum number of days to retain log files.
  final int maxDays;

  Directory? _logDir;
  IOSink? _currentSink;
  String? _currentDateKey;

  /// Lazily resolve and cache the log directory.
  Future<Directory?> _getLogDir() async {
    if (_logDir != null) return _logDir;
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/logs');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _logDir = dir;
    } catch (_) {
      // path_provider may be unavailable on some platforms — degrade gracefully.
      _logDir = null;
    }
    return _logDir;
  }

  /// Append a single [entry] to today's log file.
  Future<void> write(LingLogEntry entry) async {
    final dir = await _getLogDir();
    if (dir == null) return;
    final dateKey = _dateKey(entry.timestamp);
    if (_currentDateKey != dateKey || _currentSink == null) {
      await _rotateSink(dateKey);
    }
    _currentSink?.writeln(entry.toLogLine());
  }

  /// Return all log file paths (oldest first).
  Future<List<String>> getLogFiles() async {
    final dir = await _getLogDir();
    if (dir == null) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.txt'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return files.map((f) => f.path).toList();
  }

  /// Read the full content of [filePath].
  Future<String> getLogContent(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return '';
    return file.readAsString();
  }

  /// Force-flush the current buffer to disk.
  Future<void> flush() async {
    await _currentSink?.flush();
  }

  /// Close the active sink (call on app shutdown).
  Future<void> dispose() async {
    await _currentSink?.flush();
    await _currentSink?.close();
    _currentSink = null;
    _currentDateKey = null;
  }

  /// Delete log files older than [maxDays].
  Future<void> cleanupOldLogs() async {
    final dir = await _getLogDir();
    if (dir == null) return;
    final cutoff = DateTime.now().subtract(Duration(days: maxDays));
    for (final entity in dir.listSync()) {
      if (entity is File) {
        final stat = entity.statSync();
        if (stat.modified.isBefore(cutoff)) {
          try {
            entity.deleteSync();
          } catch (_) {
            // best-effort cleanup
          }
        }
      }
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────

  Future<void> _rotateSink(String dateKey) async {
    if (_currentSink != null) {
      await _currentSink?.flush();
      await _currentSink?.close();
    }
    final dir = _logDir;
    if (dir == null) return;
    final file = File('${dir.path}/log_$dateKey.txt');
    _currentSink = file.openWrite(mode: FileMode.append);
    _currentDateKey = dateKey;
    // Opportunistic cleanup on rotation.
    cleanupOldLogs();
  }

  String _dateKey(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}_${two(dt.month)}_${two(dt.day)}';
  }
}
