import 'package:flutter_ai_sdk/src/context/persistence/conversation_summary.dart';
import 'package:flutter_ai_sdk/src/context/persistence/memory.dart';
import 'package:flutter_ai_sdk/src/models/conversation.dart';

/// Web stub for [JsonFileMemory].
///
/// `dart:io` — and therefore file-based storage — is not available on the
/// web. Any attempt to construct this class throws immediately. Use
/// `InMemoryMemory` or implement [Memory] with a web storage API
/// (IndexedDB, `localStorage`) instead.
class JsonFileMemory implements Memory {
  /// Always throws: [JsonFileMemory] is not supported on the web.
  JsonFileMemory({required String directoryPath}) {
    throw UnsupportedError(
      'JsonFileMemory is not supported on the web (requested directory: '
      '$directoryPath). Use InMemoryMemory, or implement Memory with a web '
      'storage API such as IndexedDB or localStorage.',
    );
  }

  @override
  Future<void> saveConversation(Conversation conversation) =>
      throw UnimplementedError();

  @override
  Future<Conversation?> loadConversation(String id) =>
      throw UnimplementedError();

  @override
  Future<bool> deleteConversation(String id) => throw UnimplementedError();

  @override
  Future<List<String>> listConversationIds() => throw UnimplementedError();

  @override
  Future<List<ConversationSummary>> listSummaries() =>
      throw UnimplementedError();

  @override
  Future<void> clearAll() => throw UnimplementedError();
}
