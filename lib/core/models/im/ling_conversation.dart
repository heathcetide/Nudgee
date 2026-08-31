import 'ling_chat_user.dart';
import 'ling_enums.dart';
import 'ling_message.dart';

/// A conversation / chat room.
class LingConversation {
  final String id;
  final String name;
  final LingConversationType type;
  final String? avatarUrl;
  final List<LingChatUser> members;
  final LingMessage? lastMessage;
  final int unreadCount;
  final LingMuteStatus muteStatus;
  final LingPinStatus pinStatus;
  final DateTime? pinnedAt;
  final String? draft;
  final Map<String, dynamic>? metadata;

  const LingConversation({
    required this.id,
    required this.name,
    this.type = LingConversationType.single,
    this.avatarUrl,
    this.members = const [],
    this.lastMessage,
    this.unreadCount = 0,
    this.muteStatus = LingMuteStatus.unmuted,
    this.pinStatus = LingPinStatus.unpinned,
    this.pinnedAt,
    this.draft,
    this.metadata,
  });

  bool get isGroup => type == LingConversationType.group;
  bool get isMuted => muteStatus == LingMuteStatus.muted;
  bool get isPinned => pinStatus == LingPinStatus.pinned;
  bool get hasUnread => unreadCount > 0;
  bool get hasDraft => draft != null && draft!.isNotEmpty;

  /// Other members (excluding [currentUserId]).
  List<LingChatUser> others(String currentUserId) =>
      members.where((u) => u.id != currentUserId).toList();

  /// Display subtitle: last message preview or member count.
  String subtitle(String currentUserId) {
    if (lastMessage != null) {
      final msg = lastMessage!;
      final author = members.firstWhere(
        (u) => u.id == msg.authorId,
        orElse: () => LingChatUser(id: msg.authorId, name: msg.authorId),
      );
      final prefix = msg.isFrom(currentUserId) ? '我: ' : '${author.name}: ';
      return '$prefix${msg.previewText}';
    }
    if (isGroup) return '${members.length} 人';
    return '';
  }

  LingConversation copyWith({
    String? name,
    String? avatarUrl,
    List<LingChatUser>? members,
    LingMessage? lastMessage,
    int? unreadCount,
    LingMuteStatus? muteStatus,
    LingPinStatus? pinStatus,
    DateTime? pinnedAt,
    Object? draft = _sentinel,
    Map<String, dynamic>? metadata,
  }) {
    return LingConversation(
      id: id,
      name: name ?? this.name,
      type: type,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      muteStatus: muteStatus ?? this.muteStatus,
      pinStatus: pinStatus ?? this.pinStatus,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      draft: identical(draft, _sentinel) ? this.draft : draft as String?,
      metadata: metadata ?? this.metadata,
    );
  }

  static const _sentinel = Object();
}

/// Extension on LingMessage for preview text.
extension LingMessagePreview on LingMessage {
  String get previewText {
    switch (type) {
      case LingMessageType.text:
        return text ?? '';
      case LingMessageType.image:
        return '[图片]';
      case LingMessageType.audio:
        return '[语音]';
      case LingMessageType.video:
        return '[视频]';
      case LingMessageType.file:
        return '[文件] ${mediaName ?? ''}';
      case LingMessageType.system:
        return text ?? '[系统消息]';
      case LingMessageType.custom:
        return text ?? '[自定义消息]';
    }
  }
}
