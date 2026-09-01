/// Agent UI widgets — streaming visualization for agent runs.
///
/// Widgets:
/// - [AgentStreamBuilder] — renders an agent run as streaming UI
///   (thinking, tool calls, content, stats)
/// - [ThinkingCard] — animated thinking/reasoning display
/// - [ToolCallCard] — tool call visualization with arguments and results
/// - [AgentTraceView] — trace timeline tree
/// - [AgentTraceDialog] — full trace dialog
///
/// Usage:
/// ```dart
/// AgentStreamBuilder(
///   agent: agentCore,
///   userInput: 'What is 2+2?',
///   onDone: (reply, stats) => print('Done: $reply'),
/// )
/// ```
library;

export 'package:nudgee/core/agent/ui/agent_stream_widgets.dart';
export 'package:nudgee/core/agent/ui/agent_trace_view.dart';
