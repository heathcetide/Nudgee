import 'package:nudgee/core/agent/agent_config.dart';

/// Agent 好友模型。
///
/// 用户可以创建各种专属 Agent 作为"好友"，每个 Agent 有不同的
/// 人设、工具集和记忆。例如：
/// - 秋招助手：追踪投递进度，提醒面试时间
/// - 健身教练：记录运动数据，制定训练计划
/// - 读书伙伴：推荐书籍，讨论读后感
///
/// 每个 AgentFriend 对应一个 IM 会话 (conversationId)，
/// 用户在该会话中与 Agent 对话，Agent 使用对应的 AgentConfig
/// 和独立的记忆上下文。
class AgentFriend {
  /// 唯一 ID（同时作为 conversationId）。
  final String id;

  /// 显示名称（如"秋招助手"）。
  final String name;

  /// Emoji 图标。
  final String icon;

  /// 简介（如"帮你追踪秋招进度，提醒面试"）。
  final String description;

  /// 系统提示词（定义 Agent 的人设和行为）。
  final String systemPrompt;

  /// 可用工具名称列表。
  final List<String> toolNames;

  /// LLM 模型。
  final String model;

  /// 最大推理步数。
  final int maxSteps;

  /// 温度参数。
  final double temperature;

  /// 创建时间。
  final DateTime createdAt;

  /// 是否为内置 Agent（不可删除）。
  final bool isBuiltin;

  /// 欢迎消息（创建会话时发送）。
  final String? welcomeMessage;

  const AgentFriend({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.systemPrompt,
    this.toolNames = const [],
    this.model = 'deepseek-chat',
    this.maxSteps = 10,
    this.temperature = 0.7,
    required this.createdAt,
    this.isBuiltin = false,
    this.welcomeMessage,
  });

  /// 转换为 AgentConfig（供 AgentService 使用）。
  AgentConfig toAgentConfig() => AgentConfig(
        id: id,
        name: name,
        icon: icon,
        systemPrompt: systemPrompt,
        model: model,
        toolNames: toolNames,
        maxSteps: maxSteps,
        temperature: temperature,
        isBuiltin: isBuiltin,
        description: description,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'description': description,
        'systemPrompt': systemPrompt,
        'toolNames': toolNames,
        'model': model,
        'maxSteps': maxSteps,
        'temperature': temperature,
        'createdAt': createdAt.toIso8601String(),
        'isBuiltin': isBuiltin,
        if (welcomeMessage != null) 'welcomeMessage': welcomeMessage,
      };

  factory AgentFriend.fromJson(Map<String, dynamic> json) => AgentFriend(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String? ?? '🤖',
        description: json['description'] as String? ?? '',
        systemPrompt: json['systemPrompt'] as String? ?? '',
        toolNames: (json['toolNames'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        model: json['model'] as String? ?? 'deepseek-chat',
        maxSteps: json['maxSteps'] as int? ?? 10,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        isBuiltin: json['isBuiltin'] as bool? ?? false,
        welcomeMessage: json['welcomeMessage'] as String?,
      );

  AgentFriend copyWith({
    String? name,
    String? icon,
    String? description,
    String? systemPrompt,
    List<String>? toolNames,
    String? model,
    int? maxSteps,
    double? temperature,
    String? welcomeMessage,
  }) =>
      AgentFriend(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        description: description ?? this.description,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        toolNames: toolNames ?? this.toolNames,
        model: model ?? this.model,
        maxSteps: maxSteps ?? this.maxSteps,
        temperature: temperature ?? this.temperature,
        createdAt: createdAt,
        isBuiltin: isBuiltin,
        welcomeMessage: welcomeMessage ?? this.welcomeMessage,
      );
}
