/// 提示词模板模型。
///
/// 支持变量占位符 `{{变量名}}`，应用时由用户填写变量值，
/// 自动替换为完整提示词。
class PromptTemplate {
  final String id;
  final String name;
  final String icon; // emoji
  final String description;
  final String systemPrompt; // 可含 {{变量}} 占位符
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
    required this.category,
    this.isBuiltIn = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// 从 systemPrompt 中提取变量名列表 (如 {{主题}} → 主题)。
  List<String> get variables {
    final regex = RegExp(r'\{\{(\w+)\}\}');
    final matches = regex.allMatches(systemPrompt);
    final vars = matches.map((m) => m.group(1)!).toSet().toList();
    // Also check description for variables that map to user message.
    return vars;
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'description': description,
        'systemPrompt': systemPrompt,
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
    String? category,
    DateTime? updatedAt,
  }) =>
      PromptTemplate(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        description: description ?? this.description,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        category: category ?? this.category,
        isBuiltIn: isBuiltIn,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
