/// A reaction (emoji) on a message.
class LingMessageReaction {
  final String emoji;
  final List<String> userIds;

  const LingMessageReaction({
    required this.emoji,
    required this.userIds,
  });

  int get count => userIds.length;

  bool reactedBy(String userId) => userIds.contains(userId);

  LingMessageReaction toggle(String userId) {
    final ids = List<String>.from(userIds);
    if (ids.contains(userId)) {
      ids.remove(userId);
    } else {
      ids.add(userId);
    }
    return LingMessageReaction(emoji: emoji, userIds: ids);
  }

  @override
  String toString() => 'LingMessageReaction(emoji: $emoji, count: $count)';

  Map<String, dynamic> toJson() => {'emoji': emoji, 'userIds': userIds};
}
