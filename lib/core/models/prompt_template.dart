/// Few-shot 示例对话。
class FewShotExample {
  final String user;
  final String assistant;

  const FewShotExample({required this.user, required this.assistant});

  Map<String, dynamic> toJson() => {'user': user, 'assistant': assistant};

  factory FewShotExample.fromJson(Map<String, dynamic> json) => FewShotExample(
        user: json['user'] as String? ?? '',
        assistant: json['assistant'] as String? ?? '',
      );
}

/// 提示词模板模型。
///
/// 支持变量占位符 `{{变量名}}`，应用时由用户填写变量值，
/// 自动替换为完整提示词。
///
/// 支持三层提示词：
/// 1. [systemPrompt] — Agent 人设和基础指令
/// 2. [toolPrompt] — 工具使用指导（注入到 extraSystemContext）
/// 3. [fewShotExamples] — few-shot 示例对话（注入到 extraSystemContext）
class PromptTemplate {
  final String id;
  final String name;
  final String icon; // emoji
  final String description;
  final String systemPrompt; // 可含 {{变量}} 占位符
  final String? toolPrompt; // 工具使用提示，可含 {{变量}}
  final List<FewShotExample> fewShotExamples; // few-shot 示例
  final String category;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PromptTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.systemPrompt,
    this.toolPrompt,
    this.fewShotExamples = const [],
    required this.category,
    this.isBuiltIn = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// 从 systemPrompt、toolPrompt、fewShotExamples 中提取变量名列表。
  List<String> get variables {
    final regex = RegExp(r'\{\{(\w+)\}\}');
    final allText = StringBuffer()
      ..write(systemPrompt)
      ..write(toolPrompt ?? '');
    for (final ex in fewShotExamples) {
      allText.write(ex.user);
      allText.write(ex.assistant);
    }
    final matches = regex.allMatches(allText.toString());
    return matches.map((m) => m.group(1)!).toSet().toList();
  }

  /// 是否有变量需要填充。
  bool get hasVariables => variables.isNotEmpty;

  /// 填充变量，返回完整的 systemPrompt。
  String fillVariables(Map<String, String> values) {
    var result = systemPrompt;
    for (final entry in values.entries) {
      result = result.replaceAll('{{$entry.key}}', entry.value);
    }
    return result;
  }

  /// 填充 toolPrompt 变量。
  String? fillToolPrompt(Map<String, String> values) {
    if (toolPrompt == null) return null;
    var result = toolPrompt!;
    for (final entry in values.entries) {
      result = result.replaceAll('{{$entry.key}}', entry.value);
    }
    return result;
  }

  /// 构建 extraSystemContext（toolPrompt + fewShot 示例）。
  /// 这个字符串会被注入到 AgentCore 的 extraSystemContext 参数。
  String buildExtraContext(Map<String, String> values) {
    final sections = <String>[];

    final tp = fillToolPrompt(values);
    if (tp != null && tp.isNotEmpty) {
      sections.add('--- Tool Guidance ---\n$tp');
    }

    if (fewShotExamples.isNotEmpty) {
      final examples = fewShotExamples.map((ex) {
        final u = _fill(ex.user, values);
        final a = _fill(ex.assistant, values);
        return 'User: $u\nAssistant: $a';
      }).join('\n\n');
      sections.add('--- Examples ---\n$examples');
    }

    return sections.join('\n\n');
  }

  String _fill(String text, Map<String, String> values) {
    var result = text;
    for (final entry in values.entries) {
      result = result.replaceAll('{{$entry.key}}', entry.value);
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'description': description,
        'systemPrompt': systemPrompt,
        if (toolPrompt != null) 'toolPrompt': toolPrompt,
        'fewShotExamples': fewShotExamples.map((e) => e.toJson()).toList(),
        'category': category,
        'isBuiltIn': isBuiltIn,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory PromptTemplate.fromJson(Map<String, dynamic> json) => PromptTemplate(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String? ?? '📝',
        description: json['description'] as String? ?? '',
        systemPrompt: json['systemPrompt'] as String? ?? '',
        toolPrompt: json['toolPrompt'] as String?,
        fewShotExamples: (json['fewShotExamples'] as List?)
                ?.map((e) => FewShotExample.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        category: json['category'] as String? ?? '自定义',
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );

  PromptTemplate copyWith({
    String? name,
    String? icon,
    String? description,
    String? systemPrompt,
    String? toolPrompt,
    List<FewShotExample>? fewShotExamples,
    String? category,
    DateTime? updatedAt,
  }) =>
      PromptTemplate(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        description: description ?? this.description,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        toolPrompt: toolPrompt ?? this.toolPrompt,
        fewShotExamples: fewShotExamples ?? this.fewShotExamples,
        category: category ?? this.category,
        isBuiltIn: isBuiltIn,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
