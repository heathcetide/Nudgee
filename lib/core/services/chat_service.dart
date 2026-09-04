import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:nudgee/core/services/shared_prefs_service.dart';
import 'package:sqflite/sqflite.dart';

import 'package:nudgee/core/models/im/ling_chat_user.dart';
import 'package:nudgee/core/models/im/ling_conversation.dart';
import 'package:nudgee/core/models/im/ling_enums.dart';
import 'package:nudgee/core/models/im/ling_message.dart';
import 'package:nudgee/core/agent/agent_config.dart';
import 'package:nudgee/core/di/injector.dart' as di;
import 'package:nudgee/core/services/agent_service.dart';
import 'package:nudgee/core/services/qiniu_storage_service.dart';

/// 聊天服务 — SQLite 本地存储 + 七牛云同步。
///
/// 数据存储:
/// - 本地: SQLite 数据库 `nudgee_chat.db`
///   - conversations 表: 会话列表
///   - messages 表: 消息记录
/// - 云端: QiniuStorageService → chat/<userId>.json (会话+消息快照)
///
/// 每个用户登录后自动分配一个 AI 助手会话。
class ChatService extends ChangeNotifier {
  final QiniuStorageService _qiniu;
  final SharedPrefsService _prefs;

  static const String _prefsUserIdKey = 'chat_user_id';
  static const String _prefsLastSyncKey = 'chat_last_sync';
  static const String _dbName = 'nudgee_chat.db';

  /// 默认 AI 助手 ID 和名称。
  static const String aiAssistantId = 'ai_assistant';
  static const String aiAssistantName = 'Echo Agent';
  static const String aiAssistantAvatar = 'asset://assets/images/sprite-logo.png';
  static const String aiAssistantSystemPrompt =
      '你是 Echo Agent，Nudgee 应用的 AI 助手。你温暖、聪明、有同理心，'
      '擅长帮助用户规划日程、解答问题、提供生活建议。'
      '回复简洁自然，像朋友间的对话。使用用户的语言回复。';

  Database? _db;
  String? _userId;

  List<LingConversation> _conversations = [];
  Map<String, List<LingMessage>> _messages = {};
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _lastError;

  ChatService({
    required QiniuStorageService qiniu,
    required SharedPrefsService prefs,
  })  : _qiniu = qiniu,
        _prefs = prefs;

  // ── Getters ───────────────────────────────────────────────────────────

  List<LingConversation> get conversations => _conversations;
  Map<String, List<LingMessage>> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;

  String get _cloudKey => 'chat/$_userId.json';

  // ── 初始化 ────────────────────────────────────────────────────────────

  void setUserId(String userId) {
    _userId = userId;
    _prefs.setString(_prefsUserIdKey, userId);
    init();
  }

  Future<void> init() async {
    _userId = _prefs.getString(_prefsUserIdKey) ?? 'default';
    _isLoading = true;
    notifyListeners();

    try {
      await _openDb();
      await _loadFromDb();
      await _ensureAiAssistant();
      await _ensureAgentConversations();
      debugPrint('[ChatService] loaded ${_conversations.length} conversations from SQLite');
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[ChatService] init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _openDb() async {
    if (_db != null && _db!.isOpen) return;
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, _dbName);
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            avatar_url TEXT,
            members TEXT,
            unread_count INTEGER DEFAULT 0,
            mute_status TEXT DEFAULT 'unmuted',
            pin_status TEXT DEFAULT 'unpinned',
            pinned_at TEXT,
            draft TEXT,
            metadata TEXT,
            last_message_id TEXT,
            last_message_text TEXT,
            last_message_author TEXT,
            last_message_type TEXT,
            last_message_created_at TEXT,
            updated_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            author_id TEXT NOT NULL,
            type TEXT NOT NULL,
            text TEXT,
            media_url TEXT,
            media_name TEXT,
            media_size INTEGER,
            duration INTEGER,
            width REAL,
            height REAL,
            waveform TEXT,
            status TEXT NOT NULL,
            reactions TEXT,
            reply_id TEXT,
            reply_author_id TEXT,
            reply_author_name TEXT,
            reply_type TEXT,
            reply_preview TEXT,
            pinned INTEGER DEFAULT 0,
            metadata TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT,
            FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_conv ON messages(conversation_id, created_at)',
        );
      },
    );
  }

  Future<void> _loadFromDb() async {
    if (_db == null) return;

    // Load conversations.
    final convRows = await _db!.query('conversations', orderBy: 'updated_at DESC');
    final convs = <LingConversation>[];
    for (final row in convRows) {
      final convId = row['id'] as String;
      final msgRows = await _db!.query(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [convId],
        orderBy: 'created_at ASC',
      );
      final msgs = msgRows.map(_rowToMessage).toList();
      _messages[convId] = msgs;

      final lastMsg = msgs.isNotEmpty ? msgs.last : null;
      convs.add(_rowToConversation(row, lastMsg));
    }
    _conversations = convs;
  }

  /// 确保每个用户都有一个默认 AI 助手会话。
  /// 如果已存在但名称/头像过期，会自动更新。
  Future<void> _ensureAiAssistant() async {
    final existing = _conversations.where((c) => c.id == aiAssistantId).firstOrNull;

    if (existing != null) {
      // Migrate: update name and avatar if they're outdated.
      bool needsUpdate = false;
      if (existing.name != aiAssistantName) needsUpdate = true;
      if (existing.avatarUrl != aiAssistantAvatar) needsUpdate = true;

      // Also update member info.
      final aiMember = existing.members.where((m) => m.id == aiAssistantId).firstOrNull;
      if (aiMember != null) {
        if (aiMember.name != aiAssistantName || aiMember.avatarUrl != aiAssistantAvatar) {
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        final updatedMembers = existing.members.map((m) {
          if (m.id == aiAssistantId) {
            return LingChatUser(
              id: aiAssistantId,
              name: aiAssistantName,
              avatarUrl: aiAssistantAvatar,
              status: LingUserStatus.online,
            );
          }
          return m;
        }).toList();

        final updated = existing.copyWith(
          name: aiAssistantName,
          avatarUrl: aiAssistantAvatar,
          members: updatedMembers,
        );

        // Update in-memory list.
        final idx = _conversations.indexWhere((c) => c.id == aiAssistantId);
        if (idx >= 0) _conversations[idx] = updated;

        // Persist to DB.
        await _saveConversation(updated);
        notifyListeners();
      }
      return;
    }

    final me = LingChatUser(
      id: _userId ?? 'me',
      name: '我',
      status: LingUserStatus.online,
    );
    final ai = LingChatUser(
      id: aiAssistantId,
      name: aiAssistantName,
      avatarUrl: aiAssistantAvatar,
      status: LingUserStatus.online,
    );

    final welcomeMsg = LingMessage(
      id: '${aiAssistantId}_welcome',
      conversationId: aiAssistantId,
      authorId: aiAssistantId,
      type: LingMessageType.text,
      text: '你好呀！我是 Echo Agent ✨ 你的专属 AI 助手。有什么想聊的随时找我～',
      createdAt: DateTime.now(),
      status: LingMessageStatus.read,
    );

    final conv = LingConversation(
      id: aiAssistantId,
      name: aiAssistantName,
      type: LingConversationType.single,
      avatarUrl: aiAssistantAvatar,
      members: [me, ai],
      lastMessage: welcomeMsg,
      unreadCount: 0,
    );

    await _saveConversation(conv);
    await _saveMessage(welcomeMsg);
    _conversations.insert(0, conv);
    _messages[aiAssistantId] = [welcomeMsg];
    notifyListeners();
  }

  /// Ensures conversations exist for all registered agents.
  ///
  /// Called from [init] after [_ensureAiAssistant]. Fetches the agent list
  /// from [AgentService] (which loads from JSON) and creates a conversation
  /// for each agent that doesn't already have one.
  Future<void> _ensureAgentConversations() async {
    try {
      final agentService = di.sl<AgentService>();
      // Give AgentService time to load agents from JSON (async).
      // If agents aren't loaded yet, retry shortly.
      int retries = 0;
      while (agentService.agents.length <= 1 && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        retries++;
      }
      final agents = agentService.agents;
      if (agents.length <= 1) {
        debugPrint('[ChatService] AgentService has ${agents.length} agent(s), '
            'skipping ensureAgentConversations');
        return;
      }
      await ensureAgentConversations(agents);
    } catch (e) {
      debugPrint('[ChatService] _ensureAgentConversations error: $e');
    }
  }

  /// Ensures conversations exist for all registered agents.
  ///
  /// Called after agents are loaded from JSON. Creates a conversation
  /// for each agent if it doesn't already exist. The default agent
  /// (nudgee-assistant) maps to the legacy `ai_assistant` conversation.
  Future<void> ensureAgentConversations(List<AgentConfig> agents) async {
    if (_db == null) return;

    final me = LingChatUser(
      id: _userId ?? 'me',
      name: '我',
      status: LingUserStatus.online,
    );

    bool changed = false;

    for (final agent in agents) {
      // Skip the default agent — it maps to the legacy ai_assistant conversation
      // which is already created by _ensureAiAssistant().
      if (agent.id == 'nudgee-assistant') continue;

      final existing = _conversations.where((c) => c.id == agent.id).firstOrNull;
      if (existing != null) {
        // Update name/avatar if agent config changed.
        bool needsUpdate = false;
        if (existing.name != agent.name) needsUpdate = true;
        if (existing.avatarUrl != (agent.icon ?? '')) needsUpdate = true;

        if (needsUpdate) {
          final aiMember = LingChatUser(
            id: agent.id,
            name: agent.name,
            avatarUrl: agent.icon ?? '',
            status: LingUserStatus.online,
          );
          final updatedMembers = existing.members.map((m) {
            return m.id == agent.id ? aiMember : m;
          }).toList();
          final updated = existing.copyWith(
            name: agent.name,
            avatarUrl: agent.icon ?? '',
            members: updatedMembers,
          );
          final idx = _conversations.indexWhere((c) => c.id == agent.id);
          if (idx >= 0) _conversations[idx] = updated;
          await _saveConversation(updated);
          changed = true;
        }
        continue;
      }

      // Create new conversation for this agent.
      final ai = LingChatUser(
        id: agent.id,
        name: agent.name,
        avatarUrl: agent.icon ?? '',
        status: LingUserStatus.online,
      );

      final welcomeText = agent.description != null
          ? '你好！我是${agent.name}。\n${agent.description}'
          : '你好！我是${agent.name}。有什么可以帮你的吗？';

      final welcomeMsg = LingMessage(
        id: '${agent.id}_welcome',
        conversationId: agent.id,
        authorId: agent.id,
        type: LingMessageType.text,
        text: welcomeText,
        createdAt: DateTime.now(),
        status: LingMessageStatus.read,
      );

      final conv = LingConversation(
        id: agent.id,
        name: agent.name,
        type: LingConversationType.single,
        avatarUrl: agent.icon ?? '',
        members: [me, ai],
        lastMessage: welcomeMsg,
        unreadCount: 0,
      );

      await _saveConversation(conv);
      await _saveMessage(welcomeMsg);
      _conversations.add(conv);
      _messages[agent.id] = [welcomeMsg];
      changed = true;
      debugPrint('[ChatService] Created conversation for agent: ${agent.id}');
    }

    if (changed) {
      // Sort: default agent (ai_assistant) first, then others by name.
      _conversations.sort((a, b) {
        if (a.id == aiAssistantId) return -1;
        if (b.id == aiAssistantId) return 1;
        return a.name.compareTo(b.name);
      });
      notifyListeners();
    }
  }

  // ── CRUD: 消息 ────────────────────────────────────────────────────────

  /// 发送消息（保存到 SQLite + 更新会话 + 同步云端）。
  Future<LingMessage> sendMessage({
    required String conversationId,
    required String authorId,
    required String text,
    LingMessageType type = LingMessageType.text,
    String? mediaUrl,
  }) async {
    final msg = LingMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_${authorId.hashCode.abs()}',
      conversationId: conversationId,
      authorId: authorId,
      type: type,
      text: text,
      mediaUrl: mediaUrl,
      createdAt: DateTime.now(),
      status: LingMessageStatus.sent,
    );

    await _saveMessage(msg);
    await _updateConversationLastMessage(conversationId, msg);
    _messages[conversationId] = [...?_messages[conversationId], msg];
    notifyListeners();
    _syncToCloud();
    return msg;
  }

  /// AI 回复消息（流式完成后调用）。
  Future<LingMessage> addAiMessage({
    required String conversationId,
    required String text,
  }) async {
    final msg = LingMessage(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      authorId: aiAssistantId,
      type: LingMessageType.text,
      text: text,
      createdAt: DateTime.now(),
      status: LingMessageStatus.read,
    );

    await _saveMessage(msg);
    await _updateConversationLastMessage(conversationId, msg);
    _messages[conversationId] = [...?_messages[conversationId], msg];
    notifyListeners();
    _syncToCloud();
    return msg;
  }

  /// Persist an existing AI message (already created in the controller)
  /// to the database and cloud, without creating a duplicate.
  Future<void> persistAiMessage(LingMessage msg) async {
    await _saveMessage(msg);
    await _updateConversationLastMessage(msg.conversationId, msg);
    // Only add to ChatService's in-memory list if not already present.
    final msgs = _messages[msg.conversationId];
    if (msgs == null || !msgs.any((m) => m.id == msg.id)) {
      _messages[msg.conversationId] = [...?msgs, msg];
      notifyListeners();
    }
    _syncToCloud();
  }

  /// 获取某会话的消息列表。
  List<LingMessage> getMessages(String conversationId) =>
      _messages[conversationId] ?? [];

  /// 删除单条消息（同步内存 + 数据库）。
  Future<void> deleteMessage(String conversationId, String messageId) async {
    final msgs = _messages[conversationId];
    if (msgs == null) return;
    _messages[conversationId] = msgs.where((m) => m.id != messageId).toList();
    await _db?.delete('messages',
        where: 'id = ?', whereArgs: [messageId]);
    notifyListeners();
    _syncToCloud();
  }

  /// 批量删除消息。
  Future<void> deleteMessages(String conversationId, List<String> messageIds) async {
    final msgs = _messages[conversationId];
    if (msgs == null) return;
    final idSet = messageIds.toSet();
    _messages[conversationId] = msgs.where((m) => !idSet.contains(m.id)).toList();
    if (_db != null) {
      for (final id in messageIds) {
        await _db!.delete('messages', where: 'id = ?', whereArgs: [id]);
      }
    }
    notifyListeners();
    _syncToCloud();
  }

  /// 标记会话已读。
  Future<void> markAsRead(String conversationId) async {
    final conv = _conversations.where((c) => c.id == conversationId).firstOrNull;
    if (conv == null || conv.unreadCount == 0) return;

    final updated = conv.copyWith(unreadCount: 0);
    await _db?.update('conversations', {'unread_count': 0},
        where: 'id = ?', whereArgs: [conversationId]);
    _conversations = _conversations.map((c) => c.id == conversationId ? updated : c).toList();
    notifyListeners();
  }

  // ── CRUD: 会话 ────────────────────────────────────────────────────────

  /// 创建新会话（如添加好友）。
  Future<LingConversation> createConversation({
    required String id,
    required String name,
    String? avatarUrl,
    LingConversationType type = LingConversationType.single,
    List<LingChatUser> members = const [],
  }) async {
    final conv = LingConversation(
      id: id,
      name: name,
      type: type,
      avatarUrl: avatarUrl,
      members: members,
    );
    await _saveConversation(conv);
    _conversations.insert(0, conv);
    _messages[id] = [];
    notifyListeners();
    _syncToCloud();
    return conv;
  }

  /// 删除会话。
  Future<void> deleteConversation(String conversationId) async {
    await _db?.delete('messages',
        where: 'conversation_id = ?', whereArgs: [conversationId]);
    await _db?.delete('conversations',
        where: 'id = ?', whereArgs: [conversationId]);
    _conversations = _conversations.where((c) => c.id != conversationId).toList();
    _messages.remove(conversationId);
    notifyListeners();
    _syncToCloud();
  }

  /// 置顶/取消置顶。
  Future<void> togglePin(String conversationId) async {
    final conv = _conversations.where((c) => c.id == conversationId).firstOrNull;
    if (conv == null) return;
    final updated = conv.copyWith(
      pinStatus: conv.isPinned ? LingPinStatus.unpinned : LingPinStatus.pinned,
      pinnedAt: conv.isPinned ? null : DateTime.now(),
    );
    await _saveConversation(updated);
    _conversations = _conversations.map((c) => c.id == conversationId ? updated : c).toList();
    notifyListeners();
  }

  /// 免打扰。
  Future<void> toggleMute(String conversationId) async {
    final conv = _conversations.where((c) => c.id == conversationId).firstOrNull;
    if (conv == null) return;
    final updated = conv.copyWith(
      muteStatus: conv.isMuted ? LingMuteStatus.unmuted : LingMuteStatus.muted,
    );
    await _saveConversation(updated);
    _conversations = _conversations.map((c) => c.id == conversationId ? updated : c).toList();
    notifyListeners();
  }

  /// 保存草稿。
  Future<void> saveDraft(String conversationId, String? draft) async {
    final conv = _conversations.where((c) => c.id == conversationId).firstOrNull;
    if (conv == null) return;
    final updated = conv.copyWith(draft: draft);
    await _db?.update('conversations', {'draft': draft},
        where: 'id = ?', whereArgs: [conversationId]);
    _conversations = _conversations.map((c) => c.id == conversationId ? updated : c).toList();
    notifyListeners();
  }

  // ── 云端同步 ──────────────────────────────────────────────────────────

  Future<void> syncFromCloud() async {
    if (!_qiniu.isConfigured) return;
    _isSyncing = true;
    notifyListeners();
    try {
      final bytes = await _qiniu.downloadBytes(_cloudKey);
      if (bytes != null) {
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        await _importFromJson(json);
        await _loadFromDb();
        debugPrint('[ChatService] synced from cloud');
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[ChatService] syncFromCloud error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncToCloud() async {
    if (!_qiniu.isConfigured) return;
    try {
      final json = await _exportToJson();
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));
      await _qiniu.uploadBytes(_cloudKey, bytes);
      await _prefs.setString(_prefsLastSyncKey, DateTime.now().toIso8601String());
      debugPrint('[ChatService] synced to cloud');
    } catch (e) {
      debugPrint('[ChatService] syncToCloud error: $e');
    }
  }

  Future<Map<String, dynamic>> _exportToJson() async {
    final convsJson = <Map<String, dynamic>>[];
    for (final conv in _conversations) {
      final msgs = _messages[conv.id] ?? [];
      convsJson.add({
        'conversation': _conversationToJson(conv),
        'messages': msgs.map(_messageToJson).toList(),
      });
    }
    return {'conversations': convsJson, 'exportedAt': DateTime.now().toIso8601String()};
  }

  Future<void> _importFromJson(Map<String, dynamic> json) async {
    final convsJson = json['conversations'] as List? ?? [];
    for (final convData in convsJson) {
      final convMap = convData['conversation'] as Map<String, dynamic>;
      final msgsMap = convData['messages'] as List? ?? [];
      await _saveConversation(_jsonToConversation(convMap));
      for (final msgMap in msgsMap) {
        await _saveMessage(_jsonToMessage(msgMap as Map<String, dynamic>));
      }
    }
  }

  // ── SQLite 持久化 ─────────────────────────────────────────────────────

  Future<void> _saveConversation(LingConversation conv) async {
    if (_db == null) return;
    await _db!.insert('conversations', _conversationToRow(conv),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _saveMessage(LingMessage msg) async {
    if (_db == null) return;
    await _db!.insert('messages', _messageToRow(msg),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _updateConversationLastMessage(
      String convId, LingMessage msg) async {
    if (_db == null) return;
    await _db!.update(
      'conversations',
      {
        'last_message_id': msg.id,
        'last_message_text': msg.text,
        'last_message_author': msg.authorId,
        'last_message_type': msg.type.name,
        'last_message_created_at': msg.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [convId],
    );
  }

  // ── 转换方法 ──────────────────────────────────────────────────────────

  Map<String, dynamic> _conversationToRow(LingConversation c) => {
        'id': c.id,
        'name': c.name,
        'type': c.type.name,
        'avatar_url': c.avatarUrl,
        'members': jsonEncode(c.members.map((u) => {
          'id': u.id, 'name': u.name, 'avatarUrl': u.avatarUrl,
          'status': u.status.name,
        }).toList()),
        'unread_count': c.unreadCount,
        'mute_status': c.muteStatus.name,
        'pin_status': c.pinStatus.name,
        'pinned_at': c.pinnedAt?.toIso8601String(),
        'draft': c.draft,
        'metadata': c.metadata != null ? jsonEncode(c.metadata) : null,
        'updated_at': DateTime.now().toIso8601String(),
      };

  LingConversation _rowToConversation(Map<String, dynamic> row, LingMessage? lastMsg) {
    final membersJson = row['members'] as String? ?? '[]';
    final members = (jsonDecode(membersJson) as List)
        .map((m) => LingChatUser(
              id: m['id'] as String? ?? '',
              name: m['name'] as String? ?? '',
              avatarUrl: m['avatarUrl'] as String?,
              status: LingUserStatus.values.firstWhere(
                (e) => e.name == m['status'],
                orElse: () => LingUserStatus.offline,
              ),
            ))
        .toList();

    return LingConversation(
      id: row['id'] as String,
      name: row['name'] as String,
      type: LingConversationType.values.firstWhere(
        (e) => e.name == row['type'],
        orElse: () => LingConversationType.single,
      ),
      avatarUrl: row['avatar_url'] as String?,
      members: members,
      lastMessage: lastMsg,
      unreadCount: row['unread_count'] as int? ?? 0,
      muteStatus: LingMuteStatus.values.firstWhere(
        (e) => e.name == row['mute_status'],
        orElse: () => LingMuteStatus.unmuted,
      ),
      pinStatus: LingPinStatus.values.firstWhere(
        (e) => e.name == row['pin_status'],
        orElse: () => LingPinStatus.unpinned,
      ),
      pinnedAt: row['pinned_at'] != null
          ? DateTime.tryParse(row['pinned_at'] as String)
          : null,
      draft: row['draft'] as String?,
    );
  }

  Map<String, dynamic> _messageToRow(LingMessage m) => {
        'id': m.id,
        'conversation_id': m.conversationId,
        'author_id': m.authorId,
        'type': m.type.name,
        'text': m.text,
        'media_url': m.mediaUrl,
        'media_name': m.mediaName,
        'media_size': m.mediaSize,
        'duration': m.duration?.inSeconds,
        'width': m.width,
        'height': m.height,
        'waveform': m.waveform != null ? jsonEncode(m.waveform) : null,
        'status': m.status.name,
        'reactions': m.reactions.isNotEmpty ? jsonEncode(m.reactions.map((r) => r.toJson()).toList()) : null,
        'reply_id': m.replyTo?.messageId,
        'reply_author_id': m.replyTo?.authorId,
        'reply_author_name': m.replyTo?.authorName,
        'reply_type': m.replyTo?.messageType.name,
        'reply_preview': m.replyTo?.preview,
        'pinned': m.pinned ? 1 : 0,
        'metadata': m.metadata != null ? jsonEncode(m.metadata) : null,
        'created_at': m.createdAt.toIso8601String(),
        'updated_at': m.updatedAt?.toIso8601String(),
      };

  LingMessage _rowToMessage(Map<String, dynamic> row) {
    LingReplyQuote? reply;
    if (row['reply_id'] != null) {
      reply = LingReplyQuote(
        messageId: row['reply_id'] as String,
        authorId: row['reply_author_id'] as String? ?? '',
        authorName: row['reply_author_name'] as String? ?? '',
        messageType: LingMessageType.values.firstWhere(
          (e) => e.name == row['reply_type'],
          orElse: () => LingMessageType.text,
        ),
        preview: row['reply_preview'] as String? ?? '',
      );
    }

    return LingMessage(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      authorId: row['author_id'] as String,
      type: LingMessageType.values.firstWhere(
        (e) => e.name == row['type'],
        orElse: () => LingMessageType.text,
      ),
      text: row['text'] as String?,
      mediaUrl: row['media_url'] as String?,
      mediaName: row['media_name'] as String?,
      mediaSize: row['media_size'] as int?,
      duration: row['duration'] != null
          ? Duration(seconds: row['duration'] as int)
          : null,
      width: row['width'] as double?,
      height: row['height'] as double?,
      waveform: row['waveform'] != null
          ? (jsonDecode(row['waveform'] as String) as List).cast<double>().toList()
          : null,
      status: LingMessageStatus.values.firstWhere(
        (e) => e.name == row['status'],
        orElse: () => LingMessageStatus.sent,
      ),
      replyTo: reply,
      pinned: (row['pinned'] as int?) == 1,
      createdAt: DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> _conversationToJson(LingConversation c) => {
        'id': c.id, 'name': c.name, 'type': c.type.name,
        'avatar_url': c.avatarUrl, 'unread_count': c.unreadCount,
        'mute_status': c.muteStatus.name, 'pin_status': c.pinStatus.name,
        'members': c.members.map((u) => {
          'id': u.id, 'name': u.name, 'avatarUrl': u.avatarUrl, 'status': u.status.name,
        }).toList(),
      };

  LingConversation _jsonToConversation(Map<String, dynamic> j) {
    final members = (j['members'] as List? ?? []).map((m) => LingChatUser(
      id: m['id'] as String? ?? '', name: m['name'] as String? ?? '',
      avatarUrl: m['avatarUrl'] as String?,
      status: LingUserStatus.values.firstWhere((e) => e.name == m['status'], orElse: () => LingUserStatus.offline),
    )).toList();
    return LingConversation(
      id: j['id'] as String, name: j['name'] as String? ?? '',
      type: LingConversationType.values.firstWhere((e) => e.name == j['type'], orElse: () => LingConversationType.single),
      avatarUrl: j['avatar_url'] as String?, members: members,
      unreadCount: j['unread_count'] as int? ?? 0,
      muteStatus: LingMuteStatus.values.firstWhere((e) => e.name == j['mute_status'], orElse: () => LingMuteStatus.unmuted),
      pinStatus: LingPinStatus.values.firstWhere((e) => e.name == j['pin_status'], orElse: () => LingPinStatus.unpinned),
    );
  }

  Map<String, dynamic> _messageToJson(LingMessage m) => {
        'id': m.id, 'conversation_id': m.conversationId, 'author_id': m.authorId,
        'type': m.type.name, 'text': m.text, 'media_url': m.mediaUrl,
        'status': m.status.name, 'created_at': m.createdAt.toIso8601String(),
      };

  LingMessage _jsonToMessage(Map<String, dynamic> j) => LingMessage(
        id: j['id'] as String, conversationId: j['conversation_id'] as String,
        authorId: j['author_id'] as String,
        type: LingMessageType.values.firstWhere((e) => e.name == j['type'], orElse: () => LingMessageType.text),
        text: j['text'] as String?, mediaUrl: j['media_url'] as String?,
        status: LingMessageStatus.values.firstWhere((e) => e.name == j['status'], orElse: () => LingMessageStatus.sent),
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  /// Searches messages across all conversations by keyword.
  /// Returns results sorted by created_at descending.
  Future<List<LingMessage>> searchMessages(String query) async {
    if (query.trim().isEmpty) return [];
    if (_db == null) return [];

    try {
      final rows = await _db!.query(
        'messages',
        where: 'text LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'created_at DESC',
        limit: 100,
      );
      return rows.map(_rowToMessage).toList();
    } catch (e) {
      debugPrint('[ChatService] searchMessages error: $e');
      return [];
    }
  }

  /// Searches messages within a specific conversation.
  Future<List<LingMessage>> searchMessagesInConversation(
    String conversationId,
    String query,
  ) async {
    if (query.trim().isEmpty) return [];
    if (_db == null) {
      // Fallback to in-memory search.
      return _messages[conversationId]
              ?.where((m) => (m.text ?? '').toLowerCase().contains(query.toLowerCase()))
              .toList() ??
          [];
    }

    try {
      final rows = await _db!.query(
        'messages',
        where: 'conversation_id = ? AND text LIKE ?',
        whereArgs: [conversationId, '%$query%'],
        orderBy: 'created_at DESC',
        limit: 100,
      );
      return rows.map(_rowToMessage).toList();
    } catch (e) {
      debugPrint('[ChatService] searchMessagesInConversation error: $e');
      return [];
    }
  }
}
