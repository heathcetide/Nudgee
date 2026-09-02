import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/agent.dart';
import 'package:nudgee/core/di/injector.dart' as di;
import 'package:nudgee/core/services/agent_service.dart';
import 'package:nudgee/core/services/post_service.dart';
import 'package:nudgee/core/services/user_storage_service.dart';

/// Agent 自主内容生成服务。
///
/// 定时或事件触发让 Agent 生成内容并发布到社区动态。
///
/// 触发方式：
/// 1. **定时触发**：每日早安/晚安、每周总结等
/// 2. **事件触发**：用户完成日程、达成目标等
/// 3. **手动触发**：用户请求 Agent 生成内容
///
/// 生成的内容通过 [PostService] 发布，标记为 AI 生成。
class AgentAutonomousService extends ChangeNotifier {
  final AgentService _agentService;
  Timer? _dailyTimer;

  /// 已生成的帖子缓存（避免重复）。
  final Set<String> _generatedTopics = {};

  /// 是否启用自主发帖。
  bool _enabled = true;

  AgentAutonomousService(this._agentService);

  /// 是否启用自主发帖。
  bool get enabled => _enabled;

  /// 已生成的主题。
  Set<String> get generatedTopics => Set.unmodifiable(_generatedTopics);

  /// 启用/禁用自主发帖。
  void setEnabled(bool value) {
    _enabled = value;
    if (!value) {
      stopDailyGeneration();
    }
    notifyListeners();
  }

  // ── 定时触发 ──────────────────────────────────────────────────────────

  /// 启动每日定时生成（每小时检查一次）。
  void startDailyGeneration() {
    _dailyTimer?.cancel();
    _dailyTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _checkAndGenerate();
    });
    debugPrint('[AgentAutonomous] daily generation started');
  }

  /// 停止每日定时生成。
  void stopDailyGeneration() {
    _dailyTimer?.cancel();
    _dailyTimer = null;
    debugPrint('[AgentAutonomous] daily generation stopped');
  }

  /// 检查当前时间并决定是否生成内容。
  void _checkAndGenerate() {
    if (!_enabled || !_agentService.isConfigured) return;

    final now = DateTime.now();
    final hour = now.hour;

    // 早安帖 (7-9 点)
    if (hour == 8) {
      _maybeGenerateDaily('morning');
    }
    // 晚安帖 (21-23 点)
    else if (hour == 22) {
      _maybeGenerateDaily('evening');
    }
  }

  /// 生成每日内容（早安/晚安），避免重复。
  Future<void> _maybeGenerateDaily(String period) async {
    final todayKey = '${DateTime.now().toIso8601String().substring(0, 10)}_$period';
    if (_generatedTopics.contains(todayKey)) return;

    try {
      final prompt = period == 'morning'
          ? '生成一条早安动态，内容温暖、有活力，可以包含一句简短的'
              '每日寄语或天气提醒。不要超过 100 字。直接输出动态内容，'
              '不要加引号或前缀。'
          : '生成一条晚安动态，内容温柔、治愈，可以包含一句简短的'
              '睡前感悟。不要超过 100 字。直接输出动态内容，'
              '不要加引号或前缀。';

      final content = await _generateContent(prompt);
      if (content != null && content.isNotEmpty) {
        await _publishPost(content, isAiGenerated: true);
        _generatedTopics.add(todayKey);
        debugPrint('[AgentAutonomous] generated $period post: '
            '${content.substring(0, content.length.clamp(0, 30))}...');
      }
    } catch (e) {
      debugPrint('[AgentAutonomous] _maybeGenerateDaily error: $e');
    }
  }

  // ── 事件触发 ──────────────────────────────────────────────────────────

  /// 当用户完成日程时触发。
  Future<void> onScheduleCompleted(String scheduleTitle) async {
    if (!_enabled || !_agentService.isConfigured) return;

    try {
      final prompt = '用户刚完成了日程「$scheduleTitle」。'
          '生成一条简短的鼓励动态，庆祝这个成就。'
          '语气要自然、真诚，不要超过 80 字。直接输出动态内容。';
      final content = await _generateContent(prompt);
      if (content != null && content.isNotEmpty) {
        await _publishPost(content, isAiGenerated: true);
      }
    } catch (e) {
      debugPrint('[AgentAutonomous] onScheduleCompleted error: $e');
    }
  }

  /// 当用户达成目标时触发。
  Future<void> onGoalAchieved(String goalDescription) async {
    if (!_enabled || !_agentService.isConfigured) return;

    try {
      final prompt = '用户达成了目标「$goalDescription」！'
          '生成一条庆祝动态，表达真诚的祝贺和鼓励。'
          '不要超过 100 字。直接输出动态内容。';
      final content = await _generateContent(prompt);
      if (content != null && content.isNotEmpty) {
        await _publishPost(content, isAiGenerated: true);
      }
    } catch (e) {
      debugPrint('[AgentAutonomous] onGoalAchieved error: $e');
    }
  }

  // ── 手动触发 ──────────────────────────────────────────────────────────

  /// 手动让 Agent 生成一条动态。
  ///
  /// [topic] 是主题描述，如"分享一个编程小技巧"。
  /// 返回生成的内容，如果失败返回 null。
  Future<String?> generatePost(String topic) async {
    if (!_agentService.isConfigured) return null;

    final prompt = '请生成一条关于「$topic」的社区动态。'
        '内容要有价值、有观点，像朋友分享一样自然。'
        '不要超过 200 字。直接输出动态内容，不要加引号或前缀。';
    final content = await _generateContent(prompt);
    if (content != null && content.isNotEmpty) {
      await _publishPost(content, isAiGenerated: true);
    }
    return content;
  }

  // ── 内部方法 ──────────────────────────────────────────────────────────

  /// 调用 Agent 生成内容（纯文本，不需要工具）。
  Future<String?> _generateContent(String prompt) async {
    try {
      final completer = Completer<String?>();

      final sub = _agentService.run(prompt).listen(
        (event) {
          if (event is DoneEvent) {
            completer.complete(event.finalReply);
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.complete(null);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(null);
        },
        cancelOnError: true,
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          sub.cancel();
          debugPrint('[AgentAutonomous] content generation timed out');
          return null;
        },
      );

      return result?.trim();
    } catch (e) {
      debugPrint('[AgentAutonomous] _generateContent error: $e');
      return null;
    }
  }

  /// 发布动态到社区。
  Future<void> _publishPost(String content, {bool isAiGenerated = false}) async {
    try {
      final postService = di.sl<PostService>();
      final userStorage = di.sl<UserStorageService>();
      final profile = userStorage.getProfile();
      final userId = await userStorage.getUserId() ?? 'agent';
      final userName = profile?['name'] as String? ?? 'Echo Agent';
      final avatar = profile?['avatar'] as String? ?? '';

      final post = PostItem(
        id: 'ai_post_${DateTime.now().millisecondsSinceEpoch}',
        posterUid: userId,
        posterName: isAiGenerated ? 'Echo Agent' : userName,
        posterAvatar: avatar,
        content: content,
        images: const [],
        time: DateTime.now(),
      );
      await postService.addPost(post);
      debugPrint('[AgentAutonomous] post published');
    } catch (e) {
      debugPrint('[AgentAutonomous] _publishPost error: $e');
    }
  }

  /// 释放资源。
  void dispose() {
    stopDailyGeneration();
  }
}
