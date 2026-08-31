import 'package:equatable/equatable.dart';

/// How much effort the model should spend reasoning before answering.
enum ThinkingEffort {
  /// Minimal reasoning — fastest, cheapest.
  low,

  /// Balanced reasoning.
  medium,

  /// Maximum reasoning depth — slowest, most expensive.
  high,
}

/// Enables and configures extended thinking / reasoning output.
///
/// Provider behavior:
/// - **Anthropic**: adaptive extended thinking (`thinking: {type:
///   "adaptive"}`); [effort] maps to `output_config.effort`.
/// - **Google AI**: `generationConfig.thinkingConfig` with
///   `includeThoughts: true`; [effort] maps to `thinkingLevel`.
/// - **DeepSeek**: `thinking: {type: "enabled"}`; [effort] is ignored (no
///   effort levels).
/// - Other providers ignore this configuration entirely.
///
/// Thinking output is informational only: it's surfaced on the response
/// (`AIResponse.thinking`, `ThinkingContent`) but isn't replayed back to
/// the model on later turns.
///
/// Example:
/// ```dart
/// final config = AIConfig(
///   apiKey: 'sk-ant-...',
///   thinking: ThinkingConfig(effort: ThinkingEffort.high),
/// );
/// ```
class ThinkingConfig with Equatable {
  /// Creates a [ThinkingConfig].
  const ThinkingConfig({this.effort});

  /// How much effort the model should spend reasoning, where supported.
  final ThinkingEffort? effort;

  @override
  List<Object?> get props => [effort];
}
