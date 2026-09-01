import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent.dart';

const String qiniuApiKey = 'sk-c3qxB9P3y1hq9xuiqOduUg';
const String qiniuBaseUrl = 'https://llmapi.qiniu.io/v1';
const String qiniuModel = 'gpt-5.4-mini';

void main() {
  group('Phase 2 — Builtin Tools Integration (Real API)', () {
    late DeepSeekClient client;
    late ToolRegistry toolRegistry;
    late ContextGovernor contextGovernor;
    late PermissionContext permissionContext;
    late AgentTrace trace;

    setUpAll(() {
      client = DeepSeekClient(
        apiKey: qiniuApiKey,
        baseUrl: qiniuBaseUrl,
        defaultModel: qiniuModel,
      );
      toolRegistry = ToolRegistry();
      registerBuiltinTools(toolRegistry);
      contextGovernor = ContextGovernor(
        systemPrompt:
            'You are Nudgee, a personal productivity assistant. '
            'You help users manage their schedule, posts, and reminders. '
            'Use the available tools when the user asks you to perform actions. '
            'For read-only queries (like checking the schedule), use tools directly. '
            'For mutations (like adding a schedule), use the tool and report the result.',
        contextWindow: 64000,
      );
      permissionContext = PermissionContext.fixed(PermissionMode.bypassPermissions);
    });

    tearDownAll(() {
      client.dispose();
    });

    setUp(() {
      trace = AgentTrace();
    });

    test('1. Agent uses todo.write to plan a multi-step task', () async {
      final config = AgentConfig(
        id: 'todo-agent',
        name: 'Todo Agent',
        systemPrompt:
            'You are a task planner. When asked to do something complex, '
            'use the todo.write tool to create a plan first, then report the plan.',
        model: qiniuModel,
        toolNames: const ['todo.write'],
        maxSteps: 5,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
        trace: trace,
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(
        userInput: 'Plan a morning routine: exercise, meditation, and breakfast. '
            'Create a todo list.',
      )) {
        events.add(event);
      }

      print('\n${trace.format()}');

      // Should have used todo.write
      final toolCalls = events.whereType<ToolCallEvent>().toList();
      expect(toolCalls, isNotEmpty);
      expect(toolCalls.any((e) => e.call.name == 'todo.write'), true);

      // Should have a done event with a reply
      final done = events.whereType<DoneEvent>().first;
      expect(done.finalReply, isNotEmpty);

      print('  -> reply: ${done.finalReply}');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('2. Agent uses tool.search to discover available tools', () async {
      final config = AgentConfig(
        id: 'search-agent',
        name: 'Search Agent',
        systemPrompt:
            'You are a helpful assistant. When the user asks about capabilities, '
            'use the tool.search tool to find relevant tools.',
        model: qiniuModel,
        toolNames: const ['tool.search'],
        maxSteps: 5,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
        trace: trace,
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(
        userInput: 'Can you help me manage my schedule? Search for schedule-related tools.',
      )) {
        events.add(event);
      }

      print('\n${trace.format()}');

      final toolCalls = events.whereType<ToolCallEvent>().toList();
      expect(toolCalls, isNotEmpty);
      expect(toolCalls[0].call.name, 'tool.search');
      expect(toolCalls[0].call.arguments['keyword'].toString().toLowerCase(),
          contains('schedule'));

      final done = events.whereType<DoneEvent>().first;
      expect(done.finalReply.toLowerCase(), contains('schedule'));

      print('  -> reply: ${done.finalReply}');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('3. Agent uses ask_user for clarification', () async {
      final config = AgentConfig(
        id: 'ask-agent',
        name: 'Ask Agent',
        systemPrompt:
            'You are a helpful assistant. When you need more information '
            'from the user, use the ask_user tool.',
        model: qiniuModel,
        toolNames: const ['ask_user'],
        maxSteps: 5,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
        trace: trace,
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(
        userInput: 'Set a reminder for me.',
      )) {
        events.add(event);
      }

      print('\n${trace.format()}');

      // The agent should ask the user for more details
      final toolCalls = events.whereType<ToolCallEvent>().toList();
      final askCalls = toolCalls.where((e) => e.call.name == 'ask_user').toList();

      // The agent may or may not use ask_user depending on the model's judgment,
      // but if it does, the question should mention time or date
      if (askCalls.isNotEmpty) {
        final question = askCalls[0].call.arguments['question'].toString().toLowerCase();
        final hasRelevantKeyword =
            question.contains('time') ||
            question.contains('when') ||
            question.contains('date') ||
            question.contains('remind');
        expect(hasRelevantKeyword, true,
            reason: 'Question should ask about time/date: $question');
      }

      final done = events.whereType<DoneEvent>().first;
      expect(done.finalReply, isNotEmpty);

      print('  -> reply: ${done.finalReply}');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('4. Agent uses web.search for current information', () async {
      final config = AgentConfig(
        id: 'web-agent',
        name: 'Web Agent',
        systemPrompt:
            'You are a helpful assistant with web search capability. '
            'Use the web.search tool when the user asks about current '
            'or factual information you might not know.',
        model: qiniuModel,
        toolNames: const ['web.search'],
        maxSteps: 5,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
        trace: trace,
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(
        userInput: 'Search the web for "Dart programming language" and tell me what you find.',
      )) {
        events.add(event);
      }

      print('\n${trace.format()}');

      final toolCalls = events.whereType<ToolCallEvent>().toList();
      expect(toolCalls, isNotEmpty);
      expect(toolCalls[0].call.name, 'web.search');

      final done = events.whereType<DoneEvent>().first;
      expect(done.finalReply, isNotEmpty);

      print('  -> reply: ${done.finalReply}');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('5. Agent chains multiple tools (todo + search)', () async {
      final config = AgentConfig(
        id: 'chain-agent',
        name: 'Chain Agent',
        systemPrompt:
            'You are a productive assistant. First plan with todo.write, '
            'then use tool.search to find tools for the plan.',
        model: qiniuModel,
        toolNames: const ['todo.write', 'tool.search'],
        maxSteps: 10,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
        trace: trace,
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(
        userInput: 'I want to organize my day. First create a todo list with 3 items: '
            'check schedule, write a post, and set a reminder. '
            'Then search for tools related to each task.',
      )) {
        events.add(event);
      }

      print('\n${trace.format()}');

      // Should have multiple tool calls
      final toolCalls = events.whereType<ToolCallEvent>().toList();
      expect(toolCalls.length, greaterThanOrEqualTo(2));

      final toolNames = toolCalls.map((e) => e.call.name).toSet();
      expect(toolNames, contains('todo.write'));

      final done = events.whereType<DoneEvent>().first;
      expect(done.finalReply, isNotEmpty);

      print('  -> tools used: $toolNames');
      print('  -> reply: ${done.finalReply}');
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('6. Full trace observability with builtin tools', () async {
      final config = AgentConfig(
        id: 'trace-builtin-agent',
        name: 'Trace Builtin Agent',
        systemPrompt: 'You are a helpful assistant. Use tools when appropriate.',
        model: qiniuModel,
        toolNames: const ['todo.write', 'tool.search', 'ask_user'],
        maxSteps: 10,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
        trace: trace,
      );

      await for (final _ in core.run(
        userInput: 'Create a todo list for planning a trip, then search for tools '
            'that might help with scheduling.',
      )) {}

      print('\n${trace.format()}');

      // Verify trace structure
      expect(trace.isNotEmpty, true);
      expect(trace.findByType(TraceEntryType.runStart), hasLength(1));
      expect(trace.findByType(TraceEntryType.llmRequest), isNotEmpty);
      expect(trace.findByType(TraceEntryType.llmResponse), isNotEmpty);
      expect(trace.findByType(TraceEntryType.runEnd), hasLength(1));

      // Should have tool calls and results
      expect(trace.toolCalls, isNotEmpty);
      expect(trace.toolResults, isNotEmpty);

      // All tool results should be successful
      for (final tr in trace.toolResults) {
        expect(tr.data['success'], true,
            reason: 'Tool ${tr.data['toolName']} failed');
      }

      // JSON serialization should work
      final json = trace.toJsonString();
      expect(json, contains('runStart'));
      expect(json, contains('toolCall'));
      expect(json, contains('toolResult'));
      expect(json, contains('runEnd'));

      print('\n  -> JSON trace length: ${json.length} chars');
    }, timeout: const Timeout(Duration(seconds: 90)));
  });
}
