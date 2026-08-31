import 'package:flutter_ai_sdk/src/context/persistence/conversation_summary.dart';
import 'package:flutter_ai_sdk/src/context/persistence/memory.dart';
import 'package:flutter_ai_sdk/src/models/conversation.dart';

/// In-memory implementation of [Memory].
///
/// Stores conversations as JSON snapshots in memory, so a saved
/// conversation is unaffected by later mutations to the original
/// [Conversation] object. Data is lost when the app closes — useful for
/// testing or temporary conversations.
///
/// Example:
/// ```dart
/// final memory = InMemoryMemory();
/// await memory.saveConversation(conversation);
/// ```
class InMemoryMemory implements Memory {
  /// Creates an [InMemoryMemory].
  InMemoryMemory();

  /// Internal storage: conversation ID -> JSON snapshot.
  final Map<String, Map<String, dynamic>> _storage = {};

  @override
  Future<void> saveConversation(Conversation conversation) async {
    _storage[conversation.id] = conversation.toJson();
  }

  @override
  Future<Conversation?> loadConversation(String id) async {
    final json = _storage[id];
    return json != null ? Conversation.fromJson(json) : null;
  }

  @override
  Future<bool> deleteConversation(String id) async {
    final existed = _storage.containsKey(id);
    _storage.remove(id);
    return existed;
  }

  @override
  Future<List<String>> listConversationIds() async => _storage.keys.toList();

  @override
  Future<List<ConversationSummary>> listSummaries() async => [
        for (final json in _storage.values)
          ConversationSummary.fromConversation(Conversation.fromJson(json)),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<void> clearAll() async {
    _storage.clear();
  }

  /// Gets all stored conversations.
  List<Conversation> get conversations =>
      [for (final json in _storage.values) Conversation.fromJson(json)];

  /// Gets the number of stored conversations.
  int get length => _storage.length;
}
