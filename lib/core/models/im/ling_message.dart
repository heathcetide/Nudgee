import 'ling_enums.dart';
import 'ling_message_reaction.dart';

/// A reply reference to another message.
class LingReplyQuote {
  final String messageId;
  final String authorId;
  final String authorName;
  final LingMessageType messageType;
  final String preview; // text snippet or file name

  const LingReplyQuote({
    required this.messageId,
    required this.authorId,
    required this.authorName,
    required this.messageType,
    required this.preview,
  });
}

/// An IM message — backend-agnostic.
///
/// Supports text, image, audio, video, file, system, and custom types.
class LingMessage {
  final String id;
  final String conversationId;
  final String authorId;
  final LingMessageType type;
  final String? text;
  final String? mediaUrl; // image/audio/video/file URL
  final String? mediaName;
  final int? mediaSize;
  final Duration? duration; // for audio/video
  final double? width; // for image/video
  final double? height;
  final List<double>? waveform; // for audio
  final DateTime createdAt;
  final DateTime? updatedAt;
  final LingMessageStatus status;
  final List<LingMessageReaction> reactions;
  final LingReplyQuote? replyTo;
  final bool pinned;
  final Map<String, dynamic>? metadata;

  const LingMessage({
    required this.id,
    required this.conversationId,
    required this.authorId,
    required this.type,
    required this.createdAt,
    this.text,
    this.mediaUrl,
    this.mediaName,
    this.mediaSize,
    this.duration,
    this.width,
    this.height,
    this.waveform,
    this.updatedAt,
    this.status = LingMessageStatus.sent,
    this.reactions = const [],
    this.replyTo,
    this.pinned = false,
    this.metadata,
  });

  /// Convenience: is this message from [userId]?
  bool isFrom(String userId) => authorId == userId;

  /// Has any reactions?
  bool get hasReactions => reactions.isNotEmpty;

  /// Total reaction count.
  int get totalReactions => reactions.fold(0, (sum, r) => sum + r.count);

  LingMessage copyWith({
    String? text,
    String? mediaUrl,
    LingMessageStatus? status,
    DateTime? updatedAt,
    List<LingMessageReaction>? reactions,
    LingReplyQuote? replyTo,
    bool? pinned,
    Map<String, dynamic>? metadata,
  }) {
    return LingMessage(
      id: id,
      conversationId: conversationId,
      authorId: authorId,
      type: type,
      createdAt: createdAt,
      text: text ?? this.text,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaName: mediaName,
      mediaSize: mediaSize,
      duration: duration,
      width: width,
      height: height,
      waveform: waveform,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      reactions: reactions ?? this.reactions,
      replyTo: replyTo ?? this.replyTo,
      pinned: pinned ?? this.pinned,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() => 'LingMessage(id: $id, type: $type, status: $status)';
}
