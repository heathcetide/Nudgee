import 'package:nudgee/core/agent/agent_stats.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

/// A tool call request from the LLM.
///
/// Produced by the LLM when it decides to call a tool.
/// The [id] is used to correlate the tool result back to the LLM.
class ToolCall {
  /// Unique ID assigned by the LLM (e.g. 'call_abc123').
  final String id;

  /// Name of the tool to call (must match a registered tool).
  final String name;

  /// Arguments parsed from the LLM's JSON response.
  final Map<String, dynamic> arguments;

  /// Creates a [ToolCall].
  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  @override
  String toString() => 'ToolCall($name, args=$arguments)';
}

/// A single step in an execution plan.
class PlanStep {
  /// Step description.
  final String description;

  /// Whether this step is completed.
  final bool isCompleted;

  /// Whether this step is currently executing.
  final bool isActive;

  /// Creates a [PlanStep].
  const PlanStep({
    required this.description,
    this.isCompleted = false,
    this.isActive = false,
  });

  PlanStep copyWith({bool? isCompleted, bool? isActive}) => PlanStep(
        description: description,
        isCompleted: isCompleted ?? this.isCompleted,
        isActive: isActive ?? this.isActive,
      );

  @override
  String toString() =>
      'PlanStep(${isCompleted ? "✅" : isActive ? "🔄" : "⬜"} $description)';
}

/// Severity of an Agent error event.
enum ErrorSeverity { info, warning, error, critical }

/// Streaming events emitted during an Agent run.
///
/// Sealed class — consumers should `switch` over subtypes to handle
/// each event kind. Events arrive in order during a single [AgentHarness.run]
/// call.
sealed class AgentEvent {
  const AgentEvent();

  /// Thinking/reasoning process delta (DeepSeek-reasoner).
  const factory AgentEvent.thinking(String delta) = ThinkingEvent;

  /// Content/reply delta — the visible response text.
  const factory AgentEvent.content(String delta) = ContentEvent;

  /// The LLM requested a tool call.
  const factory AgentEvent.toolCall(ToolCall call) = ToolCallEvent;

  /// A tool finished executing with [result].
  const factory AgentEvent.toolResult(String toolName, ToolResult result) =
      ToolResultEvent;

  /// The Agent produced an execution plan.
  const factory AgentEvent.plan(List<PlanStep> steps) = PlanEvent;

  /// The Agent requests human confirmation before a sensitive action.
  const factory AgentEvent.humanConfirmation(ToolCall call, String reason) =
      HumanConfirmationEvent;

  /// Loop detection warning — the Agent may be stuck.
  const factory AgentEvent.loopWarning(int stepCount) = LoopWarningEvent;

  /// The run completed with [finalReply] and [stats].
  const factory AgentEvent.done(String finalReply, AgentRunStats stats) =
      DoneEvent;

  /// An error occurred.
  const factory AgentEvent.error(String message, {ErrorSeverity severity}) =
      ErrorEvent;
}

/// Thinking delta event.
final class ThinkingEvent extends AgentEvent {
  final String delta;
  const ThinkingEvent(this.delta);
}

/// Content delta event.
final class ContentEvent extends AgentEvent {
  final String delta;
  const ContentEvent(this.delta);
}

/// Tool call event.
final class ToolCallEvent extends AgentEvent {
  final ToolCall call;
  const ToolCallEvent(this.call);
}

/// Tool result event.
final class ToolResultEvent extends AgentEvent {
  final String toolName;
  final ToolResult result;
  const ToolResultEvent(this.toolName, this.result);
}

/// Plan event.
final class PlanEvent extends AgentEvent {
  final List<PlanStep> steps;
  const PlanEvent(this.steps);
}

/// Human confirmation request event.
final class HumanConfirmationEvent extends AgentEvent {
  final ToolCall call;
  final String reason;
  const HumanConfirmationEvent(this.call, this.reason);
}

/// Loop warning event.
final class LoopWarningEvent extends AgentEvent {
  final int stepCount;
  const LoopWarningEvent(this.stepCount);
}

/// Done event.
final class DoneEvent extends AgentEvent {
  final String finalReply;
  final AgentRunStats stats;
  const DoneEvent(this.finalReply, this.stats);
}

/// Error event.
final class ErrorEvent extends AgentEvent {
  final String message;
  final ErrorSeverity severity;
  const ErrorEvent(this.message, {this.severity = ErrorSeverity.error});
}
