import 'package:flutter/foundation.dart';

import 'package:nudgee/core/models/im/im.dart';

/// Controller for a message list in a chat.
///
/// Manages messages, typing indicator, and pagination.
/// Use with [ChangeNotifier] / [ListenableBuilder].
class LingChatController extends ChangeNotifier {
  final String conversationId;
  final String currentUserId;
  final List<LingMessage> _messages = [];
  bool _isTyping = false;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  LingChatController({
    required this.conversationId,
    required this.currentUserId,
    List<LingMessage>? initialMessages,
  }) {
    if (initialMessages != null) {
      _messages.addAll(initialMessages);
    }
  }

  /// All messages, oldest first.
  List<LingMessage> get messages => List.unmodifiable(_messages);

  /// Whether the remote user is typing.
  bool get isTyping => _isTyping;
  set isTyping(bool value) {
    if (_isTyping != value) {
      _isTyping = value;
      notifyListeners();
    }
  }

  /// Whether more historical messages can be loaded.
  bool get hasMore => _hasMore;

  /// Whether currently loading older messages.
  bool get isLoadingMore => _isLoadingMore;

  /// Add a new message to the end (latest).
  void addMessage(LingMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  /// Insert messages at the top (older history).
  void prependMessages(List<LingMessage> older) {
    _messages.insertAll(0, older);
    notifyListeners();
  }

  /// Update a message by id.
  void updateMessage(String id, LingMessage Function(LingMessage) updater) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index != -1) {
      _messages[index] = updater(_messages[index]);
      notifyListeners();
    }
  }

  /// Remove a message by id.
  void removeMessage(String id) {
    _messages.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  /// Set the entire message list.
  void setMessages(List<LingMessage> messages) {
    _messages
      ..clear()
      ..addAll(messages);
    notifyListeners();
  }

  /// Mark all messages as read.
  void markAllRead() {
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].authorId != currentUserId &&
          _messages[i].status != LingMessageStatus.read) {
        _messages[i] = _messages[i].copyWith(status: LingMessageStatus.read);
      }
    }
    notifyListeners();
  }

  /// Add a reaction to a message.
  void toggleReaction(String messageId, String emoji) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final msg = _messages[index];
    final existing = msg.reactions.where((r) => r.emoji == emoji).toList();
    List<LingMessageReaction> newReactions;

    if (existing.isEmpty) {
      newReactions = [...msg.reactions, LingMessageReaction(emoji: emoji, userIds: [currentUserId])];
    } else {
      newReactions = msg.reactions.map((r) {
        if (r.emoji == emoji) return r.toggle(currentUserId);
        return r;
      }).where((r) => r.count > 0).toList();
    }

    _messages[index] = msg.copyWith(reactions: newReactions);
    notifyListeners();
  }

  /// Call when loading more history starts.
  void beginLoadMore() {
    _isLoadingMore = true;
    notifyListeners();
  }

  /// Call when loading more history finishes.
  void endLoadMore({bool hasMore = true}) {
    _isLoadingMore = false;
    _hasMore = hasMore;
    notifyListeners();
  }

  /// Clear all messages.
  void clear() {
    _messages.clear();
    notifyListeners();
  }
}
