/// Message type for IM messages.
enum LingMessageType {
  text,
  image,
  audio,
  video,
  file,
  system,
  custom,
}

/// Delivery status of a message.
enum LingMessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

/// Conversation / chat room type.
enum LingConversationType {
  single,
  group,
  channel,
}

/// User online status.
enum LingUserStatus {
  online,
  offline,
  away,
  busy,
  invisible,
}

/// Mute status for a conversation.
enum LingMuteStatus {
  muted,
  unmuted,
}

/// Pin status for a conversation.
enum LingPinStatus {
  pinned,
  unpinned,
}
