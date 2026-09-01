import 'dart:convert';

import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

/// A single todo item tracked by the agent.
class TodoItem {
  final String content;
  final String status; // 'pending', 'in_progress', 'completed'

  const TodoItem({
    required this.content,
    required this.status,
  });

  Map<String, dynamic> toJson() => {'content': content, 'status': status};

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        content: json['content'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
      );
}

/// Tool: todo.write
///
/// Manages the agent's internal todo list for tracking multi-step tasks.
/// The agent can create, update, and view its todo list to stay organized
/// during complex operations.
///
/// This tool maintains an in-memory todo list (not persisted).
/// Mutation tool — but does not require user confirmation (internal state only).
class TodoWriteTool extends AgentTool {
  List<TodoItem> _todos = const [];

  TodoWriteTool();

  @override
  String get name => 'todo.write';

  @override
  String get description =>
      'Manage your todo list for tracking multi-step tasks. '
      'Provide a list of todo items with their status. '
      'This replaces the entire todo list. '
      'Use this to plan complex tasks and track your progress.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'todos': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'content': {'type': 'string'},
                'status': {
                  'type': 'string',
                  'enum': ['pending', 'in_progress', 'completed'],
                },
              },
              'required': ['content', 'status'],
            },
            'description': 'The complete todo list (replaces existing)',
          },
        },
        'required': ['todos'],
      };

  @override
  bool get isMutation => true;

  @override
  bool get requiresConfirmation => false; // Internal state, no user impact

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final todosRaw = args['todos'] as List?;
    if (todosRaw == null) {
      return const ToolResult.error('Missing required field: todos');
    }

    final newTodos = <TodoItem>[];
    for (final raw in todosRaw) {
      if (raw is Map<String, dynamic>) {
        final item = TodoItem.fromJson(raw);
        if (item.content.isNotEmpty) {
          newTodos.add(item);
        }
      }
    }

    _todos = List.unmodifiable(newTodos);

    // Format the todo list for the agent to see
    final lines = _todos.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final todo = entry.value;
      final icon = todo.status == 'completed'
          ? '[x]'
          : todo.status == 'in_progress'
              ? '[~]'
              : '[ ]';
      return '$i. $icon ${todo.content}';
    }).join('\n');

    final completed = _todos.where((t) => t.status == 'completed').length;
    final inProgress = _todos.where((t) => t.status == 'in_progress').length;
    final pending = _todos.where((t) => t.status == 'pending').length;

    return ToolResult.success(
        'Todo list updated ($completed completed, $inProgress in progress, '
        '$pending pending):\n$lines');
  }

  /// Gets the current todo list (for external inspection).
  List<TodoItem> get todos => _todos;
}
