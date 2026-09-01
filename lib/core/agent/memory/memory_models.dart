/// Memory system data models for the Nudgee Agent Framework.
///
/// Three-layer memory architecture:
/// - **Working memory**: current session messages (managed by ContextGovernor)
/// - **Episodic memory**: session summaries (generated at session end)
/// - **Semantic memory**: long-term user preferences, facts, skills
library;

/// Category of a semantic memory item.
///
/// Determines how the item is merged during multi-device sync.
enum MemoryCategory {
  /// User preference (e.g. "prefers concise replies").
  ///
  /// Merge strategy: last-write-wins by timestamp.
  preference,

  /// Factual knowledge about the user (e.g. "is a frontend engineer").
  ///
  /// Merge strategy: most specific wins (longer value preferred).
  fact,

  /// Skill mastery level (e.g. "proficient in React").
  ///
  /// Merge strategy: highest level wins.
  skillMastery,

  /// General context (e.g. "currently planning a trip to Japan").
  ///
  /// Merge strategy: last-write-wins by timestamp.
  context;

  String get name => toString().split('.').last;
}

/// A single long-term memory item (semantic memory).
///
/// Stored in Hive and synced to Qiniu cloud. Each item has a unique key,
/// a category, a value, a confidence score, and version metadata for
/// conflict resolution during sync.
class MemoryItem {
  /// Unique key (e.g. "preference.reply_style", "fact.occupation").
  final String key;

  /// Category of this memory item.
  final MemoryCategory category;

  /// The memory value (text).
  final String value;

  /// Confidence score (0.0 to 1.0). Higher = more confident.
  final double confidence;

  /// Source of this memory: "llm_extract", "user_explicit", "inferred".
  final String source;

  /// Version number for sync conflict resolution.
  final int version;

  /// When this item was created (ISO 8601).
  final String createdAt;

  /// When this item was last updated (ISO 8601).
  final String updatedAt;

  /// User ID that owns this memory.
  final String userId;

  /// Creates a [MemoryItem].
  const MemoryItem({
    required this.key,
    required this.category,
    required this.value,
    this.confidence = 0.5,
    this.source = 'inferred',
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.userId = 'default',
  });

  /// Creates a new memory item with the current timestamp.
  factory MemoryItem.now({
    required String key,
    required MemoryCategory category,
    required String value,
    double confidence = 0.5,
    String source = 'inferred',
    int version = 1,
    String userId = 'default',
  }) {
    final now = DateTime.now().toIso8601String();
    return MemoryItem(
      key: key,
      category: category,
      value: value,
      confidence: confidence,
      source: source,
      version: version,
      createdAt: now,
      updatedAt: now,
      userId: userId,
    );
  }

  /// Serializes to JSON.
  Map<String, dynamic> toJson() => {
        'key': key,
        'category': category.name,
        'value': value,
        'confidence': confidence,
        'source': source,
        'version': version,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'userId': userId,
      };

  /// Deserializes from JSON.
  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      key: json['key'] as String? ?? '',
      category: _parseCategory(json['category'] as String? ?? 'context'),
      value: json['value'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      source: json['source'] as String? ?? 'inferred',
      version: json['version'] as int? ?? 1,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      userId: json['userId'] as String? ?? 'default',
    );
  }

  /// Creates a copy with updated fields.
  MemoryItem copyWith({
    String? key,
    MemoryCategory? category,
    String? value,
    double? confidence,
    String? source,
    int? version,
    String? createdAt,
    String? updatedAt,
    String? userId,
  }) =>
      MemoryItem(
        key: key ?? this.key,
        category: category ?? this.category,
        value: value ?? this.value,
        confidence: confidence ?? this.confidence,
        source: source ?? this.source,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        userId: userId ?? this.userId,
      );

  @override
  String toString() =>
      'MemoryItem($key, $category, v$version, conf=$confidence)';

  @override
  bool operator ==(Object other) =>
      other is MemoryItem && other.key == key && other.userId == userId;

  @override
  int get hashCode => Object.hash(key, userId);

  static MemoryCategory _parseCategory(String name) {
    return MemoryCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => MemoryCategory.context,
    );
  }
}

/// A session summary (episodic memory).
///
/// Generated at the end of a conversation session by calling the LLM
/// to summarize the key topics, decisions, and outcomes.
class EpisodeSummary {
  /// Unique ID for this episode.
  final String id;

  /// User ID.
  final String userId;

  /// When the session started (ISO 8601).
  final String sessionStart;

  /// When the session ended (ISO 8601).
  final String sessionEnd;

  /// LLM-generated summary of the conversation.
  final String summary;

  /// Key topics discussed (extracted by LLM).
  final List<String> topics;

  /// Tools used during the session.
  final List<String> toolsUsed;

  /// Number of messages in the session.
  final int messageCount;

  /// Number of LLM steps taken.
  final int stepCount;

  /// Version number for sync.
  final int version;

  /// Creates an [EpisodeSummary].
  const EpisodeSummary({
    required this.id,
    this.userId = 'default',
    required this.sessionStart,
    required this.sessionEnd,
    required this.summary,
    this.topics = const [],
    this.toolsUsed = const [],
    this.messageCount = 0,
    this.stepCount = 0,
    this.version = 1,
  });

  /// Serializes to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'sessionStart': sessionStart,
        'sessionEnd': sessionEnd,
        'summary': summary,
        'topics': topics,
        'toolsUsed': toolsUsed,
        'messageCount': messageCount,
        'stepCount': stepCount,
        'version': version,
      };

  /// Deserializes from JSON.
  factory EpisodeSummary.fromJson(Map<String, dynamic> json) {
    return EpisodeSummary(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? 'default',
      sessionStart: json['sessionStart'] as String? ?? '',
      sessionEnd: json['sessionEnd'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      topics: (json['topics'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      toolsUsed: (json['toolsUsed'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      messageCount: json['messageCount'] as int? ?? 0,
      stepCount: json['stepCount'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
    );
  }

  @override
  String toString() =>
      'EpisodeSummary($id, ${topics.length} topics, $messageCount msgs)';
}
