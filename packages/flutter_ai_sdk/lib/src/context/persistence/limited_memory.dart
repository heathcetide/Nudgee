import 'package:flutter_ai_sdk/src/context/persistence/conversation_summary.dart';
import 'package:flutter_ai_sdk/src/context/persistence/memory.dart';
import 'package:flutter_ai_sdk/src/models/conversation.dart';

/// Memory decorator that limits the number of stored conversations.
///
/// Automatically removes the oldest conversation (by save order) when the
/// limit is exceeded.
///
/// Example:
/// ```dart
/// final memory = LimitedMemory(
///   delegate: InMemoryMemory(),
///   maxConversations: 100,
/// );
/// ```
class LimitedMemory implements Memory {
  /// Creates a [LimitedMemory].
  LimitedMemory({
    required this.delegate,
    this.maxConversations = 100,
  });

  /// The underlying memory implementation.
  final Memory delegate;

  /// Maximum number of conversations to store.
  final int maxConversations;

  /// Tracks conversation order (oldest first).
  final List<String> _order = [];

  @override
  Future<void> saveConversation(Conversation conversation) async {
    // Remove oldest if at capacity
    while (_order.length >= maxConversations) {
      final oldest = _order.removeAt(0);
      await delegate.deleteConversation(oldest);
    }

    // Update order tracking
    _order
      ..remove(conversation.id)
      ..add(conversation.id);

    await delegate.saveConversation(conversation);
  }

  @override
  Future<Conversation?> loadConversation(String id) async {
    final conversation = await delegate.loadConversation(id);
    if (conversation != null) {
      // Move to end (most recent)
      _order
        ..remove(id)
        ..add(id);
    }
    return conversation;
  }

  @override
  Future<bool> deleteConversation(String id) async {
    _order.remove(id);
    return delegate.deleteConversation(id);
  }

  @override
  Future<List<String>> listConversationIds() => delegate.listConversationIds();

  @override
  Future<List<ConversationSummary>> listSummaries() => delegate.listSummaries();

  @override
  Future<void> clearAll() async {
    _order.clear();
    await delegate.clearAll();
  }
}
