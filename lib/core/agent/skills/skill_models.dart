import 'package:nudgee/core/agent/agent_event.dart';

/// Result of a skill execution.
class SkillResult {
  /// Whether the skill completed successfully.
  final bool success;

  /// Human-readable summary of what the skill did.
  final String summary;

  /// Detailed output (may include structured data).
  final Map<String, dynamic>? data;

  /// Error message if [success] is false.
  final String? error;

  /// Number of steps completed.
  final int stepsCompleted;

  /// Tools used during execution.
  final List<String> toolsUsed;

  /// Creates a [SkillResult].
  const SkillResult({
    required this.success,
    required this.summary,
    this.data,
    this.error,
    this.stepsCompleted = 0,
    this.toolsUsed = const [],
  });

  /// Creates a successful result.
  factory SkillResult.ok(
    String summary, {
    Map<String, dynamic>? data,
    int stepsCompleted = 0,
    List<String> toolsUsed = const [],
  }) =>
      SkillResult(
        success: true,
        summary: summary,
        data: data,
        stepsCompleted: stepsCompleted,
        toolsUsed: toolsUsed,
      );

  /// Creates a failed result.
  factory SkillResult.failed(
    String error, {
    int stepsCompleted = 0,
    List<String> toolsUsed = const [],
  }) =>
      SkillResult(
        success: false,
        summary: 'Skill failed: $error',
        error: error,
        stepsCompleted: stepsCompleted,
        toolsUsed: toolsUsed,
      );

  @override
  String toString() =>
      'SkillResult(${success ? "ok" : "fail"}, $stepsCompleted steps, '
      '${toolsUsed.length} tools)';
}

/// Events emitted during skill execution.
///
/// Skills emit a stream of these events to report progress,
/// tool calls, intermediate output, and completion.
sealed class SkillEvent {
  const SkillEvent();

  /// A step in the skill workflow has started.
  const factory SkillEvent.step(String description, {int? stepNumber, int? totalSteps}) =
      SkillStepEvent;

  /// The skill is calling a tool.
  const factory SkillEvent.toolCall(ToolCall call) = SkillToolCallEvent;

  /// A tool has returned a result.
  const factory SkillEvent.toolResult(String toolName, bool success, String output) =
      SkillToolResultEvent;

  /// Intermediate output from the skill.
  const factory SkillEvent.output(String content) = SkillOutputEvent;

  /// The skill has completed.
  const factory SkillEvent.done(SkillResult result) = SkillDoneEvent;

  /// The skill encountered an error.
  const factory SkillEvent.error(String message) = SkillErrorEvent;
}

/// A step event.
class SkillStepEvent extends SkillEvent {
  final String description;
  final int? stepNumber;
  final int? totalSteps;

  const SkillStepEvent(this.description, {this.stepNumber, this.totalSteps});
}

/// A tool call event.
class SkillToolCallEvent extends SkillEvent {
  final ToolCall call;
  const SkillToolCallEvent(this.call);
}

/// A tool result event.
class SkillToolResultEvent extends SkillEvent {
  final String toolName;
  final bool success;
  final String output;
  const SkillToolResultEvent(this.toolName, this.success, this.output);
}

/// An output event.
class SkillOutputEvent extends SkillEvent {
  final String content;
  const SkillOutputEvent(this.content);
}

/// A done event.
class SkillDoneEvent extends SkillEvent {
  final SkillResult result;
  const SkillDoneEvent(this.result);
}

/// An error event.
class SkillErrorEvent extends SkillEvent {
  final String message;
  const SkillErrorEvent(this.message);
}

/// A lightweight summary of a skill for progressive disclosure.
///
/// The LLM first sees only [name] and [summary] to decide which skill
/// is relevant. If a skill is selected, [fullDescription] is loaded
/// to guide execution.
class SkillSummary {
  final String id;
  final String name;
  final String summary;
  final List<String> keywords;

  const SkillSummary({
    required this.id,
    required this.name,
    required this.summary,
    this.keywords = const [],
  });

  @override
  String toString() => 'SkillSummary($id: $name)';
}
