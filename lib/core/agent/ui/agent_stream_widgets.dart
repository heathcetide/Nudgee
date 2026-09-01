import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:nudgee/core/agent/agent.dart';

/// A widget that renders an [AgentCore] run as a streaming UI.
///
/// Consumes the [AgentEvent] stream from [AgentCore.run] and renders:
/// - **Thinking phase**: animated thinking indicator with collapsible details
/// - **Tool calls**: cards showing tool name, arguments, and results
/// - **Content**: streaming markdown text
/// - **Done**: final reply with stats
///
/// Usage:
/// ```dart
/// AgentStreamBuilder(
///   agent: agentCore,
///   userInput: 'What is the weather?',
///   onDone: (reply) => print('Done: $reply'),
/// )
/// ```
class AgentStreamBuilder extends StatefulWidget {
  /// The agent core to run.
  final AgentCore agent;

  /// The user's input message.
  final String userInput;

  /// Extra system context (e.g. memory).
  final String? extraSystemContext;

  /// Called when the agent run completes with the final reply.
  final void Function(String reply, AgentRunStats stats)? onDone;

  /// Called when an error occurs.
  final void Function(String error)? onError;

  /// Whether to show the thinking process (default: true).
  final bool showThinking;

  /// Whether to show tool call cards (default: true).
  final bool showToolCalls;

  /// Creates an [AgentStreamBuilder].
  const AgentStreamBuilder({
    super.key,
    required this.agent,
    required this.userInput,
    this.extraSystemContext,
    this.onDone,
    this.onError,
    this.showThinking = true,
    this.showToolCalls = true,
  });

  @override
  State<AgentStreamBuilder> createState() => _AgentStreamBuilderState();
}

class _AgentStreamBuilderState extends State<AgentStreamBuilder> {
  final _thinkingBuffer = StringBuffer();
  final _contentBuffer = StringBuffer();
  final _toolCalls = <_ToolCallDisplay>[];
  final _events = <AgentEvent>[];

  bool _isRunning = false;
  bool _isThinking = false;
  String? _error;
  AgentRunStats? _stats;
  StreamSubscription<AgentEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _startRun();
  }

  void _startRun() {
    setState(() {
      _isRunning = true;
      _isThinking = false;
      _error = null;
      _thinkingBuffer.clear();
      _contentBuffer.clear();
      _toolCalls.clear();
      _events.clear();
    });

    _sub = widget.agent
        .run(
          userInput: widget.userInput,
          extraSystemContext: widget.extraSystemContext,
        )
        .listen(
          _handleEvent,
          onError: (e) {
            setState(() {
              _isRunning = false;
              _error = e.toString();
            });
            widget.onError?.call(e.toString());
          },
          onDone: () {
            setState(() => _isRunning = false);
          },
          cancelOnError: true,
        );
  }

  void _handleEvent(AgentEvent event) {
    _events.add(event);

    switch (event) {
      case ThinkingEvent():
        setState(() {
          _isThinking = true;
          _thinkingBuffer.write(event.delta);
        });

      case ContentEvent():
        setState(() {
          _isThinking = false;
          _contentBuffer.write(event.delta);
        });

      case ToolCallEvent():
        setState(() {
          _isThinking = false;
          _toolCalls.add(_ToolCallDisplay(
            id: event.call.id,
            name: event.call.name,
            arguments: event.call.arguments,
            status: _ToolCallStatus.running,
          ));
        });

      case ToolResultEvent():
        setState(() {
          // Match by tool name (the last running call with this name)
          final idx = _toolCalls.lastIndexWhere(
            (tc) => tc.name == event.toolName && tc.status == _ToolCallStatus.running,
          );
          if (idx >= 0) {
            _toolCalls[idx] = _toolCalls[idx].copyWith(
              result: event.result.output,
              isError: !event.result.success,
              error: event.result.error,
              status: event.result.success
                  ? _ToolCallStatus.success
                  : _ToolCallStatus.error,
            );
          }
        });

      case HumanConfirmationEvent():
        // Auto-approve in bypass mode — UI would show dialog here
        break;

      case LoopWarningEvent():
        setState(() {
          _error = 'Loop warning: step ${event.stepCount}';
        });

      case DoneEvent():
        setState(() {
          _isRunning = false;
          _isThinking = false;
          _stats = event.stats;
        });
        widget.onDone?.call(event.finalReply, event.stats);

      case ErrorEvent():
        setState(() {
          _isRunning = false;
          _isThinking = false;
          _error = event.message;
        });
        widget.onError?.call(event.message);

      case PlanEvent():
        // Plan events could be rendered as a checklist
        break;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];

    // Thinking indicator
    if (widget.showThinking && _thinkingBuffer.isNotEmpty) {
      children.add(
        ThinkingCard(
          text: _thinkingBuffer.toString(),
          isStreaming: _isThinking,
        ),
      );
    }

    // Tool call cards
    if (widget.showToolCalls) {
      for (final tc in _toolCalls) {
        children.add(ToolCallCard(toolCall: tc));
      }
    }

    // Content (streaming markdown)
    if (_contentBuffer.isNotEmpty) {
      children.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
            borderRadius: BorderRadius.circular(12),
          ),
          child: MarkdownBody(
            data: _contentBuffer.toString(),
            selectable: true,
          ),
        ),
      );
    }

    // Error
    if (_error != null) {
      children.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withAlpha(80),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_error!, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      );
    }

    // Stats footer
    if (_stats != null) {
      children.add(_StatsFooter(stats: _stats!));
    }

    // Loading indicator
    if (_isRunning && _contentBuffer.isEmpty && _toolCalls.isEmpty && _thinkingBuffer.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text('Thinking...', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Displays the AI's thinking/reasoning process.
class ThinkingCard extends StatefulWidget {
  final String text;
  final bool isStreaming;

  const ThinkingCard({
    super.key,
    required this.text,
    this.isStreaming = false,
  });

  @override
  State<ThinkingCard> createState() => _ThinkingCardState();
}

class _ThinkingCardState extends State<ThinkingCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isStreaming) _pulseController.repeat();
  }

  @override
  void didUpdateWidget(ThinkingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStreaming && !oldWidget.isStreaming) {
      _pulseController.repeat();
    } else if (!widget.isStreaming && oldWidget.isStreaming) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(60),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, child) {
                      return Opacity(
                        opacity: widget.isStreaming
                            ? 0.5 + 0.5 * _pulseController.value
                            : 1.0,
                        child: const Icon(Icons.psychology, size: 16),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isStreaming ? 'Thinking...' : 'Thought process',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                widget.text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(180),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Displays a tool call with its arguments and result.
///
/// For tool calls with large arguments (e.g. file content in workspace.fs),
/// only a summary is shown in the collapsed view. The full content can be
/// expanded by the user.
class ToolCallCard extends StatelessWidget {
  final _ToolCallDisplay toolCall;

  const ToolCallCard({super.key, required this.toolCall});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = toolCall.status;

    final (icon, color, label) = switch (status) {
      _ToolCallStatus.running =>
        (Icons.hourglass_top, theme.colorScheme.primary, '执行中'),
      _ToolCallStatus.success =>
        (Icons.check_circle, Colors.green, '成功'),
      _ToolCallStatus.error =>
        (Icons.error, theme.colorScheme.error, '失败'),
    };

    // Build a short summary for the subtitle
    final summary = _buildSummary();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(icon, color: color, size: 18),
        title: Text(
          toolCall.name,
          style: theme.textTheme.labelMedium?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          summary.isNotEmpty ? '$label · $summary' : label,
          style: theme.textTheme.bodySmall?.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        initiallyExpanded: false,
        children: [
          // Arguments (with smart truncation for large values)
          if (toolCall.arguments.isNotEmpty)
            _buildArgumentsSection(context),
          // Result
          if (toolCall.result != null)
            _buildSection(
              context,
              '结果',
              toolCall.result!,
              isError: toolCall.isError,
            ),
          // Error
          if (toolCall.error != null)
            _buildSection(context, '错误', toolCall.error!, isError: true),
        ],
      ),
    );
  }

  /// Builds a short summary string for the subtitle.
  /// e.g. "write → match3/index.html" or "exec → 45 lines"
  String _buildSummary() {
    final args = toolCall.arguments;
    if (args.isEmpty) return '';

    switch (toolCall.name) {
      case 'workspace.fs':
        final action = args['action'] as String? ?? '';
        final path = args['path'] as String? ?? '';
        if (action == 'write' || action == 'read') {
          final content = args['content'] as String? ?? '';
          final lines = content.split('\n').length;
          return '$action → $path ($lines 行)';
        }
        return '$action → $path';
      case 'workspace.js.exec':
        final code = args['code'] as String? ?? '';
        final lines = code.split('\n').length;
        return '执行 $lines 行 JS';
      case 'cloud.exec':
        final lang = args['language'] as String? ?? '';
        final code = args['code'] as String? ?? '';
        final lines = code.split('\n').length;
        return '$lang · $lines 行';
      case 'web.search':
        final query = args['query'] as String? ?? '';
        return query.length > 30 ? '${query.substring(0, 30)}...' : query;
      case 'github.search':
        final query = args['query'] as String? ?? '';
        final type = args['type'] as String? ?? 'repositories';
        return '$type: $query';
      case 'schedule.add':
        final title = args['title'] as String? ?? '';
        return title;
      case 'memory.save':
        final key = args['key'] as String? ?? '';
        return key;
      default:
        // Generic: show first string value
        for (final entry in args.entries) {
          if (entry.value is String && entry.value.toString().isNotEmpty) {
            final val = entry.value.toString();
            return val.length > 40 ? '${val.substring(0, 40)}...' : val;
          }
        }
        return '';
    }
  }

  /// Builds the arguments section with smart truncation.
  /// Large string values (like file content) are truncated to a preview,
  /// with a "show full" toggle.
  Widget _buildArgumentsSection(BuildContext context) {
    final theme = Theme.of(context);
    final args = toolCall.arguments;

    // Check if any argument value is very long (> 200 chars)
    final hasLargeContent = args.values.any(
      (v) => v is String && v.length > 200,
    );

    if (!hasLargeContent) {
      // Small arguments — show all
      return _buildSection(context, '参数', _formatJson(args));
    }

    // Large arguments — show truncated preview per field
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '参数',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(120),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          for (final entry in args.entries)
            _buildArgumentField(context, entry.key, entry.value),
        ],
      ),
    );
  }

  Widget _buildArgumentField(BuildContext context, String key, dynamic value) {
    final theme = Theme.of(context);
    final valueStr = value?.toString() ?? 'null';
    final isLong = valueStr.length > 200;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$key:',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withAlpha(160),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
              borderRadius: BorderRadius.circular(6),
            ),
            child: isLong
                ? _TruncatedText(text: valueStr, maxLines: 5)
                : SelectableText(
                    valueStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content,
      {bool isError = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(120),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isError
                  ? theme.colorScheme.errorContainer.withAlpha(40)
                  : theme.colorScheme.surfaceContainerHighest.withAlpha(60),
              borderRadius: BorderRadius.circular(6),
            ),
            child: content.length > 500
                ? _TruncatedText(text: content, maxLines: 10)
                : SelectableText(
                    content,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatJson(Map<String, dynamic> json) {
    try {
      return const JsonEncoder.withIndent('  ').convert(json);
    } catch (_) {
      return json.toString();
    }
  }
}

/// A text widget that can be expanded to show full content.
class _TruncatedText extends StatefulWidget {
  final String text;
  final int maxLines;

  const _TruncatedText({required this.text, required this.maxLines});

  @override
  State<_TruncatedText> createState() => _TruncatedTextState();
}

class _TruncatedTextState extends State<_TruncatedText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          widget.text,
          maxLines: _expanded ? null : widget.maxLines,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 2),
              Text(
                _expanded
                    ? '收起'
                    : '展开全部 (${widget.text.length} 字符)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Displays run statistics.
class _StatsFooter extends StatelessWidget {
  final AgentRunStats stats;

  const _StatsFooter({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          _StatChip(icon: Icons.layers, label: '${stats.steps} steps'),
          _StatChip(
              icon: Icons.build, label: '${stats.toolCalls} tool calls'),
          _StatChip(
            icon: Icons.token,
            label: '${stats.inputTokens + stats.outputTokens} tokens',
          ),
          _StatChip(
            icon: Icons.timer,
            label: '${stats.duration.inSeconds}.${(stats.duration.inMilliseconds % 1000) ~/ 10}s',
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: theme.colorScheme.onSurface.withAlpha(120)),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(120),
          ),
        ),
      ],
    );
  }
}

/// Internal representation of a tool call for display.
enum _ToolCallStatus { running, success, error }

class _ToolCallDisplay {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final String? result;
  final String? error;
  final bool isError;
  final _ToolCallStatus status;

  const _ToolCallDisplay({
    required this.id,
    required this.name,
    required this.arguments,
    this.result,
    this.error,
    this.isError = false,
    this.status = _ToolCallStatus.running,
  });

  _ToolCallDisplay copyWith({
    String? result,
    String? error,
    bool? isError,
    _ToolCallStatus? status,
  }) {
    return _ToolCallDisplay(
      id: id,
      name: name,
      arguments: arguments,
      result: result ?? this.result,
      error: error ?? this.error,
      isError: isError ?? this.isError,
      status: status ?? this.status,
    );
  }
}
