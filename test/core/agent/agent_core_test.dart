import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent_config.dart';
import 'package:nudgee/core/agent/agent_core.dart';
import 'package:nudgee/core/agent/agent_event.dart';
import 'package:nudgee/core/agent/context/context_governor.dart';
import 'package:nudgee/core/agent/permission/permission.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';
import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_registry.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

import 'providers/mock_llm_client.dart';

/// Test tool that echoes input.
class EchoTool extends AgentTool {
  @override
  String get name => 'echo';

  @override
  String get description => 'Echoes the message back.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'message': {'type': 'string', 'description': 'Message to echo'},
        },
        'required': ['message'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final msg = args['message'] as String? ?? 'no message';
    return ToolResult.success('Echo: $msg');
  }
}

/// Test tool that requires confirmation.
class DeleteTool extends AgentTool {
  @override
  String get name => 'delete';

  @override
  String get description => 'Deletes an item.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Item ID to delete'},
        },
        'required': ['id'],
      };

  @override
  bool get requiresConfirmation => true;

  @override
  bool get isMutation => true;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    return ToolResult.success('Deleted ${args['id']}');
  }
}

void main() {
  late MockLLMClient llmClient;
  late ToolRegistry toolRegistry;
  late ContextGovernor contextGovernor;
  late PermissionContext permissionContext;

  setUp(() {
    llmClient = MockLLMClient();
    toolRegistry = ToolRegistry();
    toolRegistry.registerAll([EchoTool(), DeleteTool()]);
    contextGovernor = ContextGovernor(
      systemPrompt: 'You are a test agent.',
      contextWindow: 64000,
    );
    permissionContext = PermissionContext.fixed(PermissionMode.normal);
  });

  /// Collects all events from an AgentCore run into a list.
  Future<List<AgentEvent>> runAgent(
    AgentCore core, {
    required String userInput,
    List<LlmMessage> history = const [],
  }) async {
    final events = <AgentEvent>[];
    await for (final event in core.run(userInput: userInput, history: history)) {
      events.add(event);
    }
    return events;
  }

  group('AgentCore.pure chat (no tools)', () {
    test('completes with content event and done event', () async {
      final config = AgentConfig(
        id: 'chat-only',
        name: 'Chat Only',
        systemPrompt: 'You are a helpful assistant.',
        toolNames: const [],  // No tools
      );
      final core = AgentCore(
        config: config,
        llmClient: llmClient,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
      );

      llmClient.enqueueContent('Hello! How can I help you?');

      final events = await runAgent(core, userInput: 'Hi');

      // Should have content events and a done event
      final contentEvents = events.whereType<ContentEvent>().toList();
      final doneEvents = events.whereType<DoneEvent>().toList();

      expect(contentEvents, isNotEmpty);
      expect(doneEvents, hasLength(1));
      expect(doneEvents.first.finalReply, contains('Hello'));
    });

    test('emits thinking event when LLM provides reasoning', () async {
      final config = AgentConfig(
        id: 'thinking-agent',
        name: 'Thinking Agent',
        systemPrompt: 'You think before answering.',
        toolNames: const [],
      );
      final core = AgentCore(
        config: config,
        llmClient: llmClient,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
      );

      llmClient.enqueueThinking('Let me think about this...', 'The answer is 42.');

      final events = await runAgent(core, userInput: 'What is the answer?');

      final thinkingEvents = events.whereType<ThinkingEvent>().toList();
      expect(thinkingEvents, isNotEmpty);
      expect(thinkingEvents.first.delta, contains('think'));
    });
  });

  group('AgentCore.tool calling', () {
    test('executes tool call and continues', () async {
      final config = AgentConfig(
        id: 'tool-agent',
        name: 'Tool Agent',
        systemPrompt: 'You use tools.',
        toolNames: const ['echo'],
      );
      final core = AgentCore(
        config: config,
        llmClient: llmClient,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
      );

      // First LLM response: tool call
      llmClient.enqueueToolCalls([
        const ToolCall(id: 'tc1', name: 'echo', arguments: {'message': 'hello'}),
      ]);
      // Second LLM response: final reply
      llmClient.enqueueContent('I echoed your message!');

      final events = await runAgent(core, userInput: 'Echo hello');

      final toolCallEvents = events.whereType<ToolCallEvent>().toList();
      final toolResultEvents = events.whereType<ToolResultEvent>().toList();
      final doneEvents = events.whereType<DoneEvent>().toList();

      expect(toolCallEvents, hasLength(1));
      expect(toolCallEvents.first.call.name, 'echo');
      expect(toolResultEvents, hasLength(1));
      expect(toolResultEvents.first.result.success, true);
      expect(toolResultEvents.first.result.output, 'Echo: hello');
      expect(doneEvents, hasLength(1));
      expect(doneEvents.first.finalReply, contains('echoed'));
    });

    test('handles tool execution error gracefully', () async {
      // Register a failing tool
      toolRegistry.unregister('echo');

      final config = AgentConfig(
        id: 'error-agent',
        name: 'Error Agent',
        systemPrompt: 'You use tools.',
        toolNames: const ['echo'],
      );

      // Re-register echo but make it fail
      toolRegistry.register(EchoTool());

      final core = AgentCore(
        config: config,
        llmClient: llmClient,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
      );

      // LLM calls a non-existent tool
      llmClient.enqueueToolCalls([
        const ToolCall(id: 'tc1', name: 'nonexistent', arguments: {}),
      ]);
      llmClient.enqueueContent('Sorry, that tool failed. Let me try another way.');

      final events = await runAgent(core, userInput: 'Do something');

      final toolResultEvents = events.whereType<ToolResultEvent>().toList();
      expect(toolResultEvents, hasLength(1));
      expect(toolResultEvents.first.result.success, false);

      final doneEvents = events.whereType<DoneEvent>().toList();
      expect(doneEvents, hasLength(1));
    });
  });

  group('AgentCore.permission', () {
    test('denies sensitive tool in plan mode', () async {
      permissionContext = PermissionContext.fixed(PermissionMode.plan);

      final config = AgentConfig(
        id: 'plan-agent',
        name: 'Plan Agent',
        systemPrompt: 'You plan.',
        toolNames: const ['delete'],
      );
      final core = AgentCore(
        config: config,
        llmClient: llmClient,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
      );

      llmClient.enqueueToolCalls([
        const ToolCall(id: 'tc1', name: 'delete', arguments: {'id': '123'}),
      ]);
      llmClient.enqueueContent('I cannot delete in plan mode.');

      final events = await runAgent(core, userInput: 'Delete item 123');

      final confirmEvents = events.whereType<HumanConfirmationEvent>().toList();
      expect(confirmEvents, isNotEmpty);
      expect(confirmEvents.first.reason, contains('Plan mode'));
    });

    test('allows sensitive tool in bypass mode', () async {
      permissionContext = PermissionContext.fixed(PermissionMode.bypassPermissions);

      final config = AgentConfig(
        id: 'bypass-agent',
        name: 'Bypass Agent',
        systemPrompt: 'You bypass.',
        toolNames: const ['delete'],
      );
      final core = AgentCore(
        config: config,
        llmClient: llmClient,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
      );

      llmClient.enqueueToolCalls([
        const ToolCall(id: 'tc1', name: 'delete', arguments: {'id': '456'}),
      ]);
      llmClient.enqueueContent('Deleted!');

      final events = await runAgent(core, userInput: 'Delete item 456');

      final toolResultEvents = events.whereType<ToolResultEvent>().toList();
      expect(toolResultEvents, hasLength(1));
      expect(toolResultEvents.first.result.success, true);
    });
  });

  group('AgentCore.stats', () {
    test('reports token usage in done event', () async {
      final config = AgentConfig(
        id: 'stats-agent',
        name: 'Stats Agent',
        systemPrompt: 'You report stats.',
        toolNames: const [],
      );
      final core = AgentCore(
        config: config,
        llmClient: llmClient,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
      );

      llmClient.enqueueContent('Done!');

      final events = await runAgent(core, userInput: 'Hi');

      final doneEvent = events.whereType<DoneEvent>().first;
      expect(doneEvent.stats.inputTokens, greaterThan(0));
      expect(doneEvent.stats.outputTokens, greaterThan(0));
      expect(doneEvent.stats.steps, greaterThan(0));
    });

    test('counts tool calls in stats', () async {
      final config = AgentConfig(
        id: 'count-agent',
        name: 'Count Agent',
        systemPrompt: 'You count.',
        toolNames: const ['echo'],
      );
      final core = AgentCore(
        config: config,
        llmClient: llmClient,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
      );

      llmClient.enqueueToolCalls([
        const ToolCall(id: 'tc1', name: 'echo', arguments: {'message': 'a'}),
      ]);
      llmClient.enqueueContent('Done!');

      final events = await runAgent(core, userInput: 'Echo a');

      final doneEvent = events.whereType<DoneEvent>().first;
      expect(doneEvent.stats.toolCalls, 1);
    });
  });

  group('AgentCore.history', () {
    test('includes history in LLM request', () async {
      final config = AgentConfig(
        id: 'history-agent',
        name: 'History Agent',
        systemPrompt: 'You remember.',
        toolNames: const [],
      );
      final core = AgentCore(
        config: config,
        llmClient: llmClient,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
      );

      llmClient.enqueueContent('I remember!');

      final history = [
        const LlmMessage.user('My name is Test.'),
        const LlmMessage.assistant(text: 'Nice to meet you, Test!'),
      ];

      await runAgent(core, userInput: 'What is my name?', history: history);

      // Check that the mock received the history
      expect(llmClient.requests, isNotEmpty);
      final request = llmClient.requests.first;
      // History + new user message
      expect(request.messages.length, greaterThan(2));
    });
  });
}
