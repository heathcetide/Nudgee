/// Agent run statistics — tracks resource usage for a single Agent execution.
///
/// Reported in [AgentEvent.done] and used by [CostTracker] for budget enforcement.
class AgentRunStats {
  /// Number of ReAct loop iterations completed.
  final int steps;

  /// Total input tokens consumed across all LLM calls.
  final int inputTokens;

  /// Total output tokens consumed across all LLM calls.
  final int outputTokens;

  /// Total reasoning/thinking tokens (DeepSeek-reasoner).
  final int thinkingTokens;

  /// Number of tool calls made.
  final int toolCalls;

  /// Number of skills triggered.
  final int skillUses;

  /// Wall-clock duration of the run.
  final Duration duration;

  /// Estimated cost in CNY.
  final double estimatedCost;

  /// Creates [AgentRunStats].
  const AgentRunStats({
    required this.steps,
    required this.inputTokens,
    required this.outputTokens,
    this.thinkingTokens = 0,
    required this.toolCalls,
    required this.skillUses,
    required this.duration,
    this.estimatedCost = 0.0,
  });

  /// Empty stats (used for errors/aborts).
  const AgentRunStats.empty()
      : steps = 0,
        inputTokens = 0,
        outputTokens = 0,
        thinkingTokens = 0,
        toolCalls = 0,
        skillUses = 0,
        duration = Duration.zero,
        estimatedCost = 0.0;

  /// Total tokens (input + output + thinking).
  int get totalTokens => inputTokens + outputTokens + thinkingTokens;

  /// Creates a copy with updated fields.
  AgentRunStats copyWith({
    int? steps,
    int? inputTokens,
    int? outputTokens,
    int? thinkingTokens,
    int? toolCalls,
    int? skillUses,
    Duration? duration,
    double? estimatedCost,
  }) =>
      AgentRunStats(
        steps: steps ?? this.steps,
        inputTokens: inputTokens ?? this.inputTokens,
        outputTokens: outputTokens ?? this.outputTokens,
        thinkingTokens: thinkingTokens ?? this.thinkingTokens,
        toolCalls: toolCalls ?? this.toolCalls,
        skillUses: skillUses ?? this.skillUses,
        duration: duration ?? this.duration,
        estimatedCost: estimatedCost ?? this.estimatedCost,
      );

  /// Merges two stats (used for sub-agent aggregation).
  AgentRunStats merge(AgentRunStats other) => AgentRunStats(
        steps: steps + other.steps,
        inputTokens: inputTokens + other.inputTokens,
        outputTokens: outputTokens + other.outputTokens,
        thinkingTokens: thinkingTokens + other.thinkingTokens,
        toolCalls: toolCalls + other.toolCalls,
        skillUses: skillUses + other.skillUses,
        duration: duration + other.duration,
        estimatedCost: estimatedCost + other.estimatedCost,
      );

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
        'steps': steps,
        'input_tokens': inputTokens,
        'output_tokens': outputTokens,
        'thinking_tokens': thinkingTokens,
        'total_tokens': totalTokens,
        'tool_calls': toolCalls,
        'skill_uses': skillUses,
        'duration_ms': duration.inMilliseconds,
        'estimated_cost': estimatedCost,
      };

  @override
  String toString() =>
      'AgentRunStats(steps=$steps, tokens=$totalTokens, tools=$toolCalls, ${duration.inSeconds}s)';
}
