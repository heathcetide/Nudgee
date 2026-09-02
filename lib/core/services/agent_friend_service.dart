import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/di/injector.dart' as di;
import 'package:nudgee/core/models/agent_friend.dart';
import 'package:nudgee/core/models/im/ling_chat_user.dart';
import 'package:nudgee/core/models/im/ling_enums.dart';
import 'package:nudgee/core/services/chat_service.dart';
import 'package:nudgee/core/services/shared_prefs_service.dart';

/// Agent 好友管理服务。
///
/// 负责：
/// - Agent 好友的 CRUD（创建、读取、更新、删除）
/// - 持久化到 SharedPreferences
/// - 创建好友时自动创建对应的 IM 会话
/// - 提供内置 Agent 好友模板
class AgentFriendService extends ChangeNotifier {
  static const _storageKey = 'agent_friends';

  final SharedPrefsService _prefs;
  List<AgentFriend> _friends = [];
  bool _initialized = false;

  AgentFriendService(this._prefs);

  /// 所有 Agent 好友列表。
  List<AgentFriend> get friends => List.unmodifiable(_friends);

  /// 是否已初始化。
  bool get isInitialized => _initialized;

  /// 初始化：从本地存储加载 + 注册内置好友。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. 加载用户创建的好友
    await _loadFromStorage();

    // 2. 注册内置好友（如果不存在）
    _registerBuiltinFriends();

    notifyListeners();
  }

  /// 从本地存储加载好友列表。
  Future<void> _loadFromStorage() async {
    try {
      final json = _prefs.getString(_storageKey);
      if (json != null && json.isNotEmpty) {
        final list = jsonDecode(json) as List;
        _friends = list
            .map((e) => AgentFriend.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[AgentFriendService] load error: $e');
    }
  }

  /// 保存好友列表到本地存储。
  Future<void> _saveToStorage() async {
    try {
      final json = jsonEncode(_friends.map((e) => e.toJson()).toList());
      await _prefs.setString(_storageKey, json);
    } catch (e) {
      debugPrint('[AgentFriendService] save error: $e');
    }
  }

  /// 注册内置 Agent 好友模板。
  void _registerBuiltinFriends() {
    final builtins = _builtinTemplates();
    for (final b in builtins) {
      if (!_friends.any((f) => f.id == b.id)) {
        _friends.add(b);
      }
    }
  }

  /// 内置 Agent 好友模板。
  List<AgentFriend> _builtinTemplates() => [
        AgentFriend(
          id: 'agent_friend_campus_recruit',
          name: '秋招助手',
          icon: '🎯',
          description: '追踪秋招投递进度，提醒面试时间，分析岗位匹配度',
          systemPrompt: '你是一位专业的秋招求职助手。你的职责：\n'
              '1. 帮用户追踪已投递的企业、岗位、链接和状态\n'
              '2. 提醒用户面试时间、截止日期\n'
              '3. 分析岗位要求与用户背景的匹配度\n'
              '4. 提供面试建议和准备方向\n\n'
              '当用户告诉你投递了某个企业时，记住企业名、岗位、链接、投递时间。\n'
              '当用户告诉你面试时间时，用 notification.schedule 设置提醒。\n'
              '用 memory.save 保存投递记录，方便后续查询。\n'
              '使用用户的语言回复。',
          toolNames: const [
            'memory.save', 'memory.query', 'user.profile',
            'notification.schedule',
            'schedule.add', 'schedule.query',
            'web.search', 'web.news',
            'datetime', 'tool.search', 'ask_user', 'todo.write',
          ],
          maxSteps: 15,
          temperature: 0.5,
          createdAt: DateTime(2025, 1, 1),
          isBuiltin: true,
          welcomeMessage: '你好！我是你的秋招助手 🎯\n\n'
              '你可以告诉我：\n'
              '• 投递了哪些企业、岗位、链接\n'
              '• 面试时间安排\n'
              '• 想了解的岗位信息\n\n'
              '我会帮你追踪进度、提醒面试、分析匹配度！',
        ),
        AgentFriend(
          id: 'agent_friend_fitness_coach',
          name: '健身教练',
          icon: '💪',
          description: '记录运动数据，制定训练计划，督促坚持',
          systemPrompt: '你是一位专业的健身教练。你的职责：\n'
              '1. 记录用户的运动数据（类型、时长、强度）\n'
              '2. 制定个性化训练计划\n'
              '3. 督促用户坚持，提供鼓励\n'
              '4. 解答健身相关问题\n\n'
              '用 memory.save 保存用户的运动记录和目标。\n'
              '用 schedule.add 安排训练计划。\n'
              '用 web.search 搜索健身相关知识。\n'
              '语气要积极、有感染力，像真正的教练一样。使用用户的语言回复。',
          toolNames: const [
            'memory.save', 'memory.query', 'user.profile',
            'schedule.add', 'schedule.query', 'schedule.remove',
            'web.search',
            'datetime', 'tool.search', 'ask_user', 'todo.write',
          ],
          maxSteps: 10,
          temperature: 0.8,
          createdAt: DateTime(2025, 1, 1),
          isBuiltin: true,
          welcomeMessage: '嘿！我是你的健身教练 💪\n\n'
              '告诉我你的健身目标，我来帮你制定计划！\n'
              '也可以记录每次运动数据，我会帮你追踪进度。',
        ),
        AgentFriend(
          id: 'agent_friend_reading_buddy',
          name: '读书伙伴',
          icon: '📚',
          description: '推荐书籍，记录阅读进度，讨论读后感',
          systemPrompt: '你是一位热爱阅读的读书伙伴。你的职责：\n'
              '1. 根据用户兴趣推荐书籍\n'
              '2. 记录用户的阅读清单和进度\n'
              '3. 讨论书中的观点和读后感\n'
              '4. 分享阅读方法和技巧\n\n'
              '用 memory.save 保存用户的阅读记录和偏好。\n'
              '用 web.search 搜索书籍信息和书评。\n'
              '语气要温和、有深度，像真正的书友一样。使用用户的语言回复。',
          toolNames: const [
            'memory.save', 'memory.query', 'user.profile',
            'web.search',
            'datetime', 'tool.search', 'ask_user', 'todo.write',
          ],
          maxSteps: 10,
          temperature: 0.7,
          createdAt: DateTime(2025, 1, 1),
          isBuiltin: true,
          welcomeMessage: '你好呀！我是你的读书伙伴 📚\n\n'
              '想看什么类型的书？或者正在读什么？\n'
              '我们可以一起聊聊～',
        ),
      ];

  // ── CRUD ──────────────────────────────────────────────────────────────

  /// 创建一个新的 Agent 好友。
  ///
  /// 会自动：
  /// 1. 保存 AgentFriend 配置
  /// 2. 创建对应的 IM 会话（带欢迎消息）
  /// 3. 在 AgentService 中注册 AgentConfig
  ///
  /// 返回创建的 [AgentFriend]。
  Future<AgentFriend> createFriend({
    required String name,
    required String icon,
    required String description,
    required String systemPrompt,
    List<String> toolNames = const [],
    String? welcomeMessage,
  }) async {
    final id = 'agent_friend_${DateTime.now().millisecondsSinceEpoch}';
    final friend = AgentFriend(
      id: id,
      name: name,
      icon: icon,
      description: description,
      systemPrompt: systemPrompt,
      toolNames: toolNames,
      createdAt: DateTime.now(),
      welcomeMessage: welcomeMessage,
    );

    _friends.insert(0, friend);
    await _saveToStorage();

    // 创建对应的 IM 会话
    await _createConversationForFriend(friend);

    notifyListeners();
    return friend;
  }

  /// 为 AgentFriend 创建对应的 IM 会话。
  Future<void> _createConversationForFriend(AgentFriend friend) async {
    try {
      final chatService = di.sl<ChatService>();

      // 如果会话已存在，跳过
      if (chatService.conversations.any((c) => c.id == friend.id)) return;

      // 创建会话
      final conv = await chatService.createConversation(
        id: friend.id,
        name: friend.name,
        type: LingConversationType.single,
        members: [
          LingChatUser(
            id: friend.id,
            name: friend.name,
            avatarUrl: null,
            status: LingUserStatus.online,
            metadata: {'isAgent': true, 'icon': friend.icon},
          ),
        ],
      );

      // 发送欢迎消息
      final welcome = friend.welcomeMessage ?? '你好！我是${friend.name}，有什么可以帮你的吗？';
      await chatService.addAiMessage(
        conversationId: conv.id,
        text: welcome,
      );
    } catch (e) {
      debugPrint('[AgentFriendService] create conversation error: $e');
    }
  }

  /// 为已有的 AgentFriend 创建会话（如果不存在）。
  /// 用于从聊天列表添加内置 Agent 好友。
  Future<void> ensureConversationForFriend(String friendId) async {
    final friend = getFriend(friendId);
    if (friend == null) return;
    await _createConversationForFriend(friend);
  }

  /// 更新 Agent 好友配置。
  Future<void> updateFriend(String id, {
    String? name,
    String? icon,
    String? description,
    String? systemPrompt,
    List<String>? toolNames,
    String? welcomeMessage,
  }) async {
    final idx = _friends.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _friends[idx] = _friends[idx].copyWith(
      name: name,
      icon: icon,
      description: description,
      systemPrompt: systemPrompt,
      toolNames: toolNames,
      welcomeMessage: welcomeMessage,
    );
    await _saveToStorage();
    notifyListeners();
  }

  /// 删除 Agent 好友（同时删除会话）。
  Future<void> deleteFriend(String id) async {
    final friend = _friends.where((f) => f.id == id).firstOrNull;
    if (friend == null || friend.isBuiltin) return;

    _friends.removeWhere((f) => f.id == id);
    await _saveToStorage();

    // 删除对应的 IM 会话
    try {
      await di.sl<ChatService>().deleteConversation(id);
    } catch (e) {
      debugPrint('[AgentFriendService] delete conversation error: $e');
    }

    notifyListeners();
  }

  /// 根据 ID 获取 Agent 好友。
  AgentFriend? getFriend(String id) =>
      _friends.where((f) => f.id == id).firstOrNull;

  /// 判断某个会话 ID 是否是 Agent 好友会话。
  bool isAgentFriendConversation(String conversationId) =>
      _friends.any((f) => f.id == conversationId);

  /// 获取某个会话对应的 AgentFriend（如果有）。
  AgentFriend? getFriendByConversation(String conversationId) =>
      getFriend(conversationId);
}
