import 'dart:convert';
import 'dart:io';

import 'package:flutter_ai_sdk/src/context/persistence/conversation_summary.dart';
import 'package:flutter_ai_sdk/src/context/persistence/memory.dart';
import 'package:flutter_ai_sdk/src/models/conversation.dart';

/// A [Memory] that persists each conversation as one JSON file on disk.
///
/// Suitable for mobile and desktop apps. The directory is created if it
/// doesn't exist yet. Not available on the web — see the platform-gated
/// export in `persistence.dart`, which falls back to a stub there.
///
/// Example:
/// ```dart
/// final dir = await getApplicationDocumentsDirectory(); // path_provider
/// final memory = JsonFileMemory(directoryPath: '${dir.path}/conversations');
/// ```
class JsonFileMemory implements Memory {
  /// Creates a [JsonFileMemory] that stores conversations under
  /// [directoryPath].
  JsonFileMemory({required this.directoryPath});

  /// The directory conversations are stored in, one JSON file per
  /// conversation named `<id>.json`.
  final String directoryPath;

  File _fileFor(String id) => File('$directoryPath/$id.json');

  Future<Directory> _ensureDirectory() async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<void> saveConversation(Conversation conversation) async {
    await _ensureDirectory();
    await _fileFor(
      conversation.id,
    ).writeAsString(jsonEncode(conversation.toJson()));
  }

  @override
  Future<Conversation?> loadConversation(String id) async {
    final file = _fileFor(id);
    if (!file.existsSync()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return Conversation.fromJson(json);
  }

  @override
  Future<bool> deleteConversation(String id) async {
    final file = _fileFor(id);
    if (!file.existsSync()) return false;
    await file.delete();
    return true;
  }

  @override
  Future<List<String>> listConversationIds() async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return [];
    return [
      for (final entity in dir.listSync())
        if (entity is File && entity.path.endsWith('.json')) _idOf(entity),
    ];
  }

  @override
  Future<List<ConversationSummary>> listSummaries() async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return [];

    final summaries = <ConversationSummary>[];
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final json =
          jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
      summaries.add(
        ConversationSummary.fromConversation(Conversation.fromJson(json)),
      );
    }
    return summaries..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> clearAll() async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync()) {
      if (entity is File && entity.path.endsWith('.json')) {
        await entity.delete();
      }
    }
  }

  /// Extracts the conversation ID from a `<id>.json` file's name.
  String _idOf(File file) {
    final fileName = file.uri.pathSegments.last;
    return fileName.substring(0, fileName.length - '.json'.length);
  }
}
