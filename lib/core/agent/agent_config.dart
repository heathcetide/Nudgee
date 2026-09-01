/// Agent configuration — defines an Agent's identity, model, and constraints.
///
/// Each Agent instance is configured with:
/// - A unique [id] and display [name]
/// - A [systemPrompt] that defines its persona
/// - The [model] to use (e.g. 'deepseek-chat', 'deepseek-reasoner')
/// - The [toolNames] it is allowed to call
/// - Execution limits ([maxSteps], [temperature])
class AgentConfig {
  /// Unique identifier for this Agent.
  final String id;

  /// Human-readable name shown in UI.
  final String name;

  /// Emoji or icon identifier for UI display.
  final String? icon;

  /// System prompt that defines the Agent's persona and instructions.
  final String systemPrompt;

  /// LLM model to use (e.g. 'deepseek-chat', 'deepseek-reasoner').
  final String model;

  /// Names of tools this Agent is allowed to call.
  ///
  /// Must match names registered in [ToolRegistry].
  /// Empty list means no tools (pure chat mode).
  final List<String> toolNames;

  /// Sampling temperature (0.0 = deterministic, 1.0 = creative).
  final double temperature;

  /// Maximum ReAct loop iterations before forcing stop.
  final int maxSteps;

  /// Maximum tokens per LLM response.
  final int maxTokens;

  /// Whether this is a built-in Agent (cannot be deleted by user).
  final bool isBuiltin;

  /// Optional description shown in Agent selection UI.
  final String? description;

  /// Creates an [AgentConfig].
  const AgentConfig({
    required this.id,
    required this.name,
    required this.systemPrompt,
    this.model = 'deepseek-chat',
    this.toolNames = const [],
    this.temperature = 0.7,
    this.maxSteps = 10,
    this.maxTokens = 4096,
    this.isBuiltin = false,
    this.icon,
    this.description,
  });

  /// Creates a copy with updated fields.
  AgentConfig copyWith({
    String? id,
    String? name,
    String? icon,
    String? systemPrompt,
    String? model,
    List<String>? toolNames,
    double? temperature,
    int? maxSteps,
    int? maxTokens,
    bool? isBuiltin,
    String? description,
  }) =>
      AgentConfig(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        model: model ?? this.model,
        toolNames: toolNames ?? this.toolNames,
        temperature: temperature ?? this.temperature,
        maxSteps: maxSteps ?? this.maxSteps,
        maxTokens: maxTokens ?? this.maxTokens,
        isBuiltin: isBuiltin ?? this.isBuiltin,
        description: description ?? this.description,
      );

  /// Converts to JSON for persistence.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (icon != null) 'icon': icon,
        'system_prompt': systemPrompt,
        'model': model,
        'tool_names': toolNames,
        'temperature': temperature,
        'max_steps': maxSteps,
        'max_tokens': maxTokens,
        'is_builtin': isBuiltin,
        if (description != null) 'description': description,
      };

  /// Creates from JSON.
  factory AgentConfig.fromJson(Map<String, dynamic> json) => AgentConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String?,
        systemPrompt: json['system_prompt'] as String,
        model: json['model'] as String? ?? 'deepseek-chat',
        toolNames: (json['tool_names'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
        maxSteps: json['max_steps'] as int? ?? 10,
        maxTokens: json['max_tokens'] as int? ?? 4096,
        isBuiltin: json['is_builtin'] as bool? ?? false,
        description: json['description'] as String?,
      );

  @override
  String toString() => 'AgentConfig($id, $name, model=$model, tools=${toolNames.length})';
}
