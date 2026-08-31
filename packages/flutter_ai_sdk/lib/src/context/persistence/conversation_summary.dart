import 'package:equatable/equatable.dart';

import 'package:flutter_ai_sdk/src/models/conversation.dart';

/// Lightweight metadata about a stored conversation.
///
/// Returned by `Memory.listSummaries` so a conversation-list UI can be
/// built without loading every conversation's full message history.
class ConversationSummary with Equatable {
  /// Creates a [ConversationSummary].
  const ConversationSummary({
    required this.id,
    required this.messageCount,
    required this.createdAt,
    required this.updatedAt,
    this.title,
  });

  /// Builds a summary from a full [Conversation].
  factory ConversationSummary.fromConversation(Conversation conversation) =>
      ConversationSummary(
        id: conversation.id,
        title: conversation.title,
        messageCount: conversation.length,
        createdAt: conversation.createdAt,
        updatedAt: conversation.updatedAt,
      );

  /// The conversation's unique identifier.
  final String id;

  /// The conversation's optional title.
  final String? title;

  /// Number of messages in the conversation.
  final int messageCount;

  /// When the conversation was created.
  final DateTime createdAt;

  /// When the conversation was last updated.
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, title, messageCount, createdAt, updatedAt];

  @override
  String toString() =>
      'ConversationSummary(id: $id, title: $title, messages: $messageCount)';
}
