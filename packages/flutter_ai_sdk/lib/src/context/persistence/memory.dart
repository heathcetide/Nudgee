import 'package:flutter_ai_sdk/src/context/persistence/conversation_summary.dart';
import 'package:flutter_ai_sdk/src/models/conversation.dart';

/// Memory interface for persisting conversation data.
///
/// Implement this interface to provide custom storage backends
/// for conversation history and context — e.g. Hive, SQLite, or
/// `shared_preferences`. See the wiki's Persistence page for examples.
///
/// Example:
/// ```dart
/// class LocalStorageMemory implements Memory {
///   @override
///   Future<void> saveConversation(Conversation conversation) async {
///     final json = jsonEncode(conversation.toJson());
///     await localStorage.setString(conversation.id, json);
///   }
///   // ... other methods
/// }
/// ```
abstract interface class Memory {
  /// Saves a conversation.
  Future<void> saveConversation(Conversation conversation);

  /// Loads a conversation by ID.
  Future<Conversation?> loadConversation(String id);

  /// Deletes a conversation by ID.
  Future<bool> deleteConversation(String id);

  /// Lists all stored conversation IDs.
  Future<List<String>> listConversationIds();

  /// Lists lightweight summaries of all stored conversations, most
  /// recently updated first — convenient for building a conversation-list
  /// UI without loading every conversation's full history.
  Future<List<ConversationSummary>> listSummaries();

  /// Clears all stored conversations.
  Future<void> clearAll();
}
