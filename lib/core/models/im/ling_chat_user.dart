import 'ling_enums.dart';

/// A chat user / contact.
///
/// Backend-agnostic model — fill from your IM SDK or API.
class LingChatUser {
  final String id;
  final String name;
  final String? avatarUrl;
  final LingUserStatus status;
  final Map<String, dynamic>? metadata;

  const LingChatUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.status = LingUserStatus.offline,
    this.metadata,
  });

  LingChatUser copyWith({
    String? name,
    String? avatarUrl,
    LingUserStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return LingChatUser(
      id: id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isOnline => status == LingUserStatus.online;

  @override
  String toString() => 'LingChatUser(id: $id, name: $name, status: $status)';
}
