import 'package:flutter/foundation.dart';

import 'package:nudgee/core/models/im/im.dart';

/// Controller for the conversation list.
///
/// Manages conversations, search, and unread count.
class LingConversationController extends ChangeNotifier {
  final List<LingConversation> _conversations = [];
  final List<LingConversation> _filtered = [];
  String _searchQuery = '';

  LingConversationController({List<LingConversation>? initialConversations}) {
    if (initialConversations != null) {
      _conversations.addAll(initialConversations);
      _filtered.addAll(initialConversations);
    }
  }

  /// All conversations (unfiltered).
  List<LingConversation> get conversations => List.unmodifiable(_conversations);

  /// Filtered by search query, sorted: pinned first, then by last message time.
  List<LingConversation> get visible {
    final list = _searchQuery.isEmpty ? _conversations : _filtered;
    final sorted = List<LingConversation>.from(list);
    sorted.sort((a, b) {
      // Pinned first
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      // Then by last message time (newer first)
      final aTime = a.lastMessage?.createdAt ?? a.pinnedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessage?.createdAt ?? b.pinnedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  /// Current search query.
  String get searchQuery => _searchQuery;

  /// Total unread count across all conversations.
  int get totalUnread => _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  /// Search conversations by name.
  void search(String query) {
    _searchQuery = query;
    _filtered
      ..clear()
      ..addAll(_conversations.where((c) =>
          c.name.toLowerCase().contains(query.toLowerCase())));
    notifyListeners();
  }

  /// Clear search.
  void clearSearch() {
    _searchQuery = '';
    _filtered.clear();
    notifyListeners();
  }

  /// Add or update a conversation.
  void upsertConversation(LingConversation conversation) {
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      _conversations[index] = conversation;
    } else {
      _conversations.add(conversation);
    }
    notifyListeners();
  }

  /// Remove a conversation by id.
  void removeConversation(String id) {
    _conversations.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  /// Update unread count for a conversation.
  void setUnreadCount(String conversationId, int count) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(unreadCount: count);
      notifyListeners();
    }
  }

  /// Mark a conversation as read.
  void markAsRead(String conversationId) {
    setUnreadCount(conversationId, 0);
  }

  /// Pin / unpin a conversation.
  void togglePin(String conversationId) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final conv = _conversations[index];
      _conversations[index] = conv.copyWith(
        pinStatus: conv.isPinned ? LingPinStatus.unpinned : LingPinStatus.pinned,
        pinnedAt: conv.isPinned ? null : DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// Mute / unmute a conversation.
  void toggleMute(String conversationId) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final conv = _conversations[index];
      _conversations[index] = conv.copyWith(
        muteStatus: conv.isMuted ? LingMuteStatus.unmuted : LingMuteStatus.muted,
      );
      notifyListeners();
    }
  }
}
