import 'package:flutter_ai_sdk/src/models/conversation.dart';

/// A conversation with additional metadata for search and filtering.
///
/// Wraps a [Conversation] with tags, a summary, and other metadata
/// useful for organizing and finding conversations in a UI — for example
/// pinning important conversations or filtering by tag.
class IndexedConversation {
  /// Creates an [IndexedConversation].
  IndexedConversation({
    required this.conversation,
    this.tags = const [],
    this.summary,
    this.pinned = false,
    this.archived = false,
  });

  /// Creates from a JSON map.
  factory IndexedConversation.fromJson(Map<String, dynamic> json) =>
      IndexedConversation(
        conversation: Conversation.fromJson(
          json['conversation'] as Map<String, dynamic>,
        ),
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        summary: json['summary'] as String?,
        pinned: json['pinned'] as bool? ?? false,
        archived: json['archived'] as bool? ?? false,
      );

  /// The underlying conversation.
  final Conversation conversation;

  /// Tags for categorization.
  final List<String> tags;

  /// AI-generated summary of the conversation.
  final String? summary;

  /// Whether the conversation is pinned.
  final bool pinned;

  /// Whether the conversation is archived.
  final bool archived;

  /// Gets the conversation ID.
  String get id => conversation.id;

  /// Gets the conversation title.
  String? get title => conversation.title;

  /// Gets when the conversation was created.
  DateTime get createdAt => conversation.createdAt;

  /// Gets when the conversation was last updated.
  DateTime get updatedAt => conversation.updatedAt;

  /// Creates a copy with updated fields.
  IndexedConversation copyWith({
    Conversation? conversation,
    List<String>? tags,
    String? summary,
    bool? pinned,
    bool? archived,
  }) =>
      IndexedConversation(
        conversation: conversation ?? this.conversation,
        tags: tags ?? this.tags,
        summary: summary ?? this.summary,
        pinned: pinned ?? this.pinned,
        archived: archived ?? this.archived,
      );

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
        'conversation': conversation.toJson(),
        'tags': tags,
        if (summary != null) 'summary': summary,
        'pinned': pinned,
        'archived': archived,
      };
}
