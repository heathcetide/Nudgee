import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_registry.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';
import 'package:nudgee/core/agent/tools/builtin/builtin_tools.dart';
import 'package:nudgee/core/agent/tools/builtin/todo_write_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/ask_user_tool.dart';
import 'package:nudgee/core/agent/tools/builtin/tool_search_tool.dart';

void main() {
  group('BuiltinTools registration', () {
    test('registerBuiltinTools registers all 14 tools', () {
      final registry = ToolRegistry();
      registerBuiltinTools(registry);

      expect(registry.length, builtinToolNames.length);
      for (final name in builtinToolNames) {
        expect(registry.contains(name), true, reason: 'Missing tool: $name');
      }
    });

    test('builtinToolNames has 14 entries', () {
      expect(builtinToolNames, hasLength(14));
    });

    test('definitionsFor returns all definitions', () {
      final registry = ToolRegistry();
      registerBuiltinTools(registry);

      final defs = registry.definitionsFor(builtinToolNames);
      expect(defs, hasLength(14));
    });

    test('mutation tools are marked correctly', () {
      final registry = ToolRegistry();
      registerBuiltinTools(registry);

      // These should be mutations
      expect(registry.isMutation('schedule.add'), true);
      expect(registry.isMutation('schedule.remove'), true);
      expect(registry.isMutation('post.create'), true);
      expect(registry.isMutation('post.like'), true);
      expect(registry.isMutation('notification.schedule'), true);
      expect(registry.isMutation('memory.save'), true);
      expect(registry.isMutation('todo.write'), true);

      // These should NOT be mutations
      expect(registry.isMutation('schedule.query'), false);
      expect(registry.isMutation('post.query'), false);
      expect(registry.isMutation('user.profile'), false);
      expect(registry.isMutation('web.search'), false);
      expect(registry.isMutation('tool.search'), false);
    });

    test('confirmation required for sensitive tools', () {
      final registry = ToolRegistry();
      registerBuiltinTools(registry);

      // These require confirmation
      expect(registry.needsConfirmation('schedule.add'), true);
      expect(registry.needsConfirmation('schedule.remove'), true);
      expect(registry.needsConfirmation('post.create'), true);
      expect(registry.needsConfirmation('post.like'), true);
      expect(registry.needsConfirmation('notification.schedule'), true);
      expect(registry.needsConfirmation('memory.save'), true);

      // These do NOT require confirmation
      expect(registry.needsConfirmation('schedule.query'), false);
      expect(registry.needsConfirmation('post.query'), false);
      expect(registry.needsConfirmation('user.profile'), false);
      expect(registry.needsConfirmation('web.search'), false);
      expect(registry.needsConfirmation('todo.write'), false);
      expect(registry.needsConfirmation('ask_user'), false);
    });
  });

  group('TodoWriteTool', () {
    late TodoWriteTool tool;

    setUp(() {
      tool = TodoWriteTool();
    });

    test('creates and updates todo list', () async {
      final result = await tool.execute({
        'todos': [
          {'content': 'Step 1', 'status': 'completed'},
          {'content': 'Step 2', 'status': 'in_progress'},
          {'content': 'Step 3', 'status': 'pending'},
        ],
      });

      expect(result.success, true);
      expect(result.output, contains('1 completed'));
      expect(result.output, contains('1 in progress'));
      expect(result.output, contains('1 pending'));
      expect(result.output, contains('[x] Step 1'));
      expect(result.output, contains('[~] Step 2'));
      expect(result.output, contains('[ ] Step 3'));
    });

    test('replaces entire list on each call', () async {
      await tool.execute({
        'todos': [
          {'content': 'A', 'status': 'pending'},
          {'content': 'B', 'status': 'pending'},
        ],
      });
      expect(tool.todos, hasLength(2));

      await tool.execute({
        'todos': [
          {'content': 'C', 'status': 'pending'},
        ],
      });
      expect(tool.todos, hasLength(1));
      expect(tool.todos[0].content, 'C');
    });

    test('handles empty list', () async {
      final result = await tool.execute({'todos': []});
      expect(result.success, true);
      expect(tool.todos, isEmpty);
    });

    test('skips items with empty content', () async {
      await tool.execute({
        'todos': [
          {'content': '', 'status': 'pending'},
          {'content': 'Valid', 'status': 'pending'},
        ],
      });
      expect(tool.todos, hasLength(1));
      expect(tool.todos[0].content, 'Valid');
    });

    test('returns error for missing todos field', () async {
      final result = await tool.execute({});
      expect(result.success, false);
      expect(result.error, contains('todos'));
    });
  });

  group('AskUserTool', () {
    test('returns question result', () async {
      final tool = AskUserTool();
      final result = await tool.execute({
        'question': 'What is your preferred language?',
      });

      expect(result.success, true);
      expect(result.output, contains('What is your preferred language?'));
      expect(result.output, contains('QUESTION_FOR_USER'));
    });

    test('includes choices when provided', () async {
      final tool = AskUserTool();
      final result = await tool.execute({
        'question': 'Pick one:',
        'choices': ['English', 'Chinese'],
      });

      expect(result.success, true);
      expect(result.output, contains('English'));
      expect(result.output, contains('Chinese'));
    });

    test('returns error for missing question', () async {
      final tool = AskUserTool();
      final result = await tool.execute({});

      expect(result.success, false);
      expect(result.error, contains('question'));
    });
  });

  group('ToolSearchTool', () {
    test('finds tools by keyword in name', () async {
      final registry = ToolRegistry();
      registerBuiltinTools(registry);
      final tool = ToolSearchTool(registry);

      final result = await tool.execute({'keyword': 'schedule'});

      expect(result.success, true);
      expect(result.output, contains('schedule.add'));
      expect(result.output, contains('schedule.query'));
      expect(result.output, contains('schedule.remove'));
    });

    test('finds tools by keyword in description', () async {
      final registry = ToolRegistry();
      registerBuiltinTools(registry);
      final tool = ToolSearchTool(registry);

      final result = await tool.execute({'keyword': 'notification'});

      expect(result.success, true);
      expect(result.output, contains('notification.schedule'));
    });

    test('returns available tools when no match', () async {
      final registry = ToolRegistry();
      registerBuiltinTools(registry);
      final tool = ToolSearchTool(registry);

      final result = await tool.execute({'keyword': 'nonexistent'});

      expect(result.success, true);
      expect(result.output, contains('No tools found'));
      // Should list available tool names
      expect(result.output, contains('schedule.add'));
    });

    test('returns error for missing keyword', () async {
      final registry = ToolRegistry();
      final tool = ToolSearchTool(registry);

      final result = await tool.execute({});

      expect(result.success, false);
      expect(result.error, contains('keyword'));
    });
  });
}
