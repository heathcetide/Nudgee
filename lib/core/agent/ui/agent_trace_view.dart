import 'package:flutter/material.dart';

import 'package:nudgee/core/agent/agent.dart';

/// A widget that renders an [AgentTrace] as a visual timeline tree.
///
/// Each trace entry is displayed as a row with:
/// - Timestamp (elapsed from start)
/// - Type icon
/// - Summary text
/// - Expandable details (structured data)
///
/// Usage:
/// ```dart
/// AgentTraceView(trace: agentTrace)
/// ```
class AgentTraceView extends StatelessWidget {
  /// The trace to display.
  final AgentTrace trace;

  /// Whether to auto-expand all entries (default: false).
  final bool autoExpand;

  /// Maximum number of entries to display (0 = all).
  final int maxEntries;

  /// Creates an [AgentTraceView].
  const AgentTraceView({
    super.key,
    required this.trace,
    this.autoExpand = false,
    this.maxEntries = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (trace.isEmpty) {
      return const Center(child: Text('No trace data'));
    }

    final entries = trace.entries;
    final display = maxEntries > 0 ? entries.take(maxEntries).toList() : entries;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: display.length,
      itemBuilder: (context, index) {
        final entry = display[index];
        return _TraceEntryTile(
          entry: entry,
          isLast: index == display.length - 1,
          initiallyExpanded: autoExpand,
        );
      },
    );
  }
}

class _TraceEntryTile extends StatefulWidget {
  final TraceEntry entry;
  final bool isLast;
  final bool initiallyExpanded;

  const _TraceEntryTile({
    required this.entry,
    required this.isLast,
    this.initiallyExpanded = false,
  });

  @override
  State<_TraceEntryTile> createState() => _TraceEntryTileState();
}

class _TraceEntryTileState extends State<_TraceEntryTile> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final color = _typeColor(entry.type, theme);
    final hasData = entry.data.isNotEmpty;

    return Column(
      children: [
        // Timeline row
        InkWell(
          onTap: hasData ? () => setState(() => _expanded = !_expanded) : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline indicator
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!widget.isLast)
                      Container(
                        width: 2,
                        height: 28,
                        color: theme.dividerColor,
                      ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_typeIcon(entry.type), size: 14, color: color),
                          const SizedBox(width: 4),
                          Text(
                            entry.type.name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${entry.elapsed.inMilliseconds}ms',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(100),
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (hasData) ...[
                            const SizedBox(width: 4),
                            Icon(
                              _expanded ? Icons.expand_less : Icons.expand_more,
                              size: 16,
                              color: theme.colorScheme.onSurface.withAlpha(100),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.summary,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Expanded details
        if (_expanded && hasData)
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _buildDataDisplay(context, entry.data),
            ),
          ),
      ],
    );
  }

  Widget _buildDataDisplay(BuildContext context, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final buffer = StringBuffer();

    void writeValue(String key, dynamic value, int indent) {
      final padding = '  ' * indent;
      if (value is Map<String, dynamic>) {
        buffer.writeln('$padding$key:');
        for (final entry in value.entries) {
          writeValue(entry.key, entry.value, indent + 1);
        }
      } else if (value is List) {
        buffer.writeln('$padding$key: [${value.length} items]');
        for (var i = 0; i < value.length && i < 5; i++) {
          writeValue('[$i]', value[i], indent + 1);
        }
        if (value.length > 5) {
          buffer.writeln('${'  ' * (indent + 1)}... ${value.length - 5} more');
        }
      } else {
        final str = value?.toString() ?? 'null';
        final truncated = str.length > 100 ? '${str.substring(0, 100)}...' : str;
        buffer.writeln('$padding$key: $truncated');
      }
    }

    for (final entry in data.entries) {
      writeValue(entry.key, entry.value, 0);
    }

    return SelectableText(
      buffer.toString().trimRight(),
      style: theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        fontSize: 11,
      ),
    );
  }

  Color _typeColor(TraceEntryType type, ThemeData theme) {
    return switch (type) {
      TraceEntryType.runStart => Colors.blue,
      TraceEntryType.runEnd => Colors.green,
      TraceEntryType.stepStart || TraceEntryType.stepEnd => Colors.indigo,
      TraceEntryType.llmRequest => Colors.purple,
      TraceEntryType.llmResponse => Colors.deepPurple,
      TraceEntryType.llmStreamChunk => Colors.purple.withAlpha(120),
      TraceEntryType.toolCall => Colors.orange,
      TraceEntryType.toolResult => Colors.teal,
      TraceEntryType.permissionCheck => Colors.amber,
      TraceEntryType.permissionDenied => Colors.red,
      TraceEntryType.permissionAsked => Colors.amber.shade700,
      TraceEntryType.contextCompacted => Colors.cyan,
      TraceEntryType.contextSanitized => Colors.cyan,
      TraceEntryType.error => theme.colorScheme.error,
      TraceEntryType.warning => Colors.orange.shade700,
      TraceEntryType.info => theme.colorScheme.onSurface.withAlpha(120),
    };
  }

  IconData _typeIcon(TraceEntryType type) {
    return switch (type) {
      TraceEntryType.runStart => Icons.play_arrow,
      TraceEntryType.runEnd => Icons.stop,
      TraceEntryType.stepStart => Icons.login,
      TraceEntryType.stepEnd => Icons.logout,
      TraceEntryType.llmRequest => Icons.cloud_upload,
      TraceEntryType.llmResponse => Icons.cloud_download,
      TraceEntryType.llmStreamChunk => Icons.stream,
      TraceEntryType.toolCall => Icons.build,
      TraceEntryType.toolResult => Icons.build_circle,
      TraceEntryType.permissionCheck => Icons.shield,
      TraceEntryType.permissionDenied => Icons.block,
      TraceEntryType.permissionAsked => Icons.help,
      TraceEntryType.contextCompacted => Icons.compress,
      TraceEntryType.contextSanitized => Icons.cleaning_services,
      TraceEntryType.error => Icons.error,
      TraceEntryType.warning => Icons.warning,
      TraceEntryType.info => Icons.info,
    };
  }
}

/// A bottom sheet / dialog that shows the full trace for an agent run.
class AgentTraceDialog extends StatelessWidget {
  final AgentTrace trace;

  const AgentTraceDialog({super.key, required this.trace});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Agent Trace (${trace.length} entries)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: AgentTraceView(trace: trace),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
