import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent_config.dart';
import 'package:nudgee/core/agent/agent_core.dart';
import 'package:nudgee/core/agent/agent_event.dart';
import 'package:nudgee/core/agent/context/context_governor.dart';
import 'package:nudgee/core/agent/permission/permission.dart';
import 'package:nudgee/core/agent/providers/deepseek_client.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';
import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_registry.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

import 'test_env.dart';

// LLM config from environment — tests skip if NUDGEE_LLM_API_KEY not set.
final String qiniuApiKey = TestEnv.llmApiKey ?? '';
final String qiniuBaseUrl = TestEnv.llmBaseUrl;
final String qiniuModel = TestEnv.llmModel;

/// A simple calculator tool for testing.
class CalculatorTool extends AgentTool {
  @override
  String get name => 'calculator';

  @override
  String get description => 'Evaluate a math expression and return the result.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'expression': {
            'type': 'string',
            'description': 'Math expression to evaluate, e.g. "15*37"',
          },
        },
        'required': ['expression'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final expr = args['expression'] as String?;
    if (expr == null) return const ToolResult.error('Missing expression');
    try {
      // Simple eval: only digits and operators
      final result = _safeEval(expr);
      return ToolResult.success('$expr = $result');
    } catch (e) {
      return ToolResult.error('Failed to evaluate: $e');
    }
  }

  double _safeEval(String expr) {
    // Very basic: handle multiplication of two numbers
    expr = expr.replaceAll(' ', '');
    if (expr.contains('*')) {
      final parts = expr.split('*');
      if (parts.length == 2) {
        return double.parse(parts[0]) * double.parse(parts[1]);
      }
    }
    if (expr.contains('+')) {
      final parts = expr.split('+');
      if (parts.length == 2) {
        return double.parse(parts[0]) + double.parse(parts[1]);
      }
    }
    throw 'Unsupported expression: $expr';
  }
}

/// A time tool for testing.
class TimeTool extends AgentTool {
  @override
  String get name => 'get_current_time';

  @override
  String get description => 'Get the current date and time.';

  @override
  Map<String, dynamic> get parametersSchema => {'type': 'object'};

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    return ToolResult.success(DateTime.now().toIso8601String());
  }
}

void main() {
  if (!TestEnv.hasLlmKey) return; // Skip: no NUDGEE_LLM_API_KEY
  group('Qiniu LLM Gateway — Real API Integration', () {
    late DeepSeekClient client;
    late ToolRegistry toolRegistry;
    late ContextGovernor contextGovernor;
    late PermissionContext permissionContext;

    setUpAll(() {
      // Skip setup if no API key — individual tests will also check.
      if (!TestEnv.hasLlmKey) return;
      client = DeepSeekClient(
        apiKey: qiniuApiKey,
        baseUrl: qiniuBaseUrl,
        defaultModel: qiniuModel,
      );
      toolRegistry = ToolRegistry();
      toolRegistry.registerAll([CalculatorTool(), TimeTool()]);
      contextGovernor = ContextGovernor(
        systemPrompt: 'You are a helpful assistant. Use tools when appropriate.',
        contextWindow: 64000,
      );
      permissionContext = PermissionContext.fixed(PermissionMode.bypassPermissions);
    });

    tearDownAll(() {
      client.dispose();
    });

    test('1. DeepSeekClient.chat — basic chat', () async {
      final response = await client.chat(
        messages: [const LlmMessage.user('What is 2+2? Reply in one word.')],
        temperature: 0.0,
        maxTokens: 20,
      );

      expect(response.content, isNotEmpty);
      expect(response.content.toLowerCase(), contains('4'));
      expect(response.finishReason, 'stop');
      expect(response.usage, isNotNull);
      expect(response.usage!.inputTokens, greaterThan(0));
      expect(response.usage!.outputTokens, greaterThan(0));

      print('  └─ reply: ${response.content}');
      print('  └─ usage: in=${response.usage!.inputTokens} out=${response.usage!.outputTokens}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('2. DeepSeekClient.streamChat — streaming', () async {
      final chunks = <LlmChunk>[];
      await for (final chunk in client.streamChat(
        messages: [const LlmMessage.user('Count from 1 to 5.')],
        temperature: 0.0,
        maxTokens: 50,
      )) {
        chunks.add(chunk);
      }

      final contentChunks = chunks.where((c) => c.hasContent).toList();
      expect(contentChunks, isNotEmpty);

      final fullContent = contentChunks.map((c) => c.contentDelta!).join();
      expect(fullContent, isNotEmpty);
      expect(fullContent, contains('1'));
      expect(fullContent, contains('5'));

      final doneChunks = chunks.where((c) => c.isDone).toList();
      expect(doneChunks, isNotEmpty);

      print('  └─ content chunks: ${contentChunks.length}');
      print('  └─ full reply: $fullContent');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('3. DeepSeekClient.chat — tool calling', () async {
      final response = await client.chat(
        messages: [
          const LlmMessage.user('What is 15 * 37? Use the calculator tool.'),
        ],
        tools: [
          const LlmToolDefinition(
            name: 'calculator',
            description: 'Evaluate a math expression and return the result.',
            parametersSchema: {
              'type': 'object',
              'properties': {
                'expression': {
                  'type': 'string',
                  'description': 'Math expression to evaluate, e.g. "15*37"',
                },
              },
              'required': ['expression'],
            },
          ),
        ],
        temperature: 0.0,
      );

      expect(response.hasToolCalls, true);
      expect(response.toolCalls, hasLength(1));
      expect(response.toolCalls[0].name, 'calculator');
      expect(response.toolCalls[0].arguments['expression'], isNotNull);
      expect(response.finishReason, 'tool_calls');

      print('  └─ tool: ${response.toolCalls[0].name}');
      print('  └─ args: ${response.toolCalls[0].arguments}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('4. DeepSeekClient.chat — multi-turn conversation', () async {
      // Turn 1
      final r1 = await client.chat(
        messages: [
          const LlmMessage.user('My name is Alice and I like cats.'),
        ],
        temperature: 0.0,
        maxTokens: 50,
      );
      expect(r1.content, isNotEmpty);

      // Turn 2 with history
      final r2 = await client.chat(
        messages: [
          const LlmMessage.user('My name is Alice and I like cats.'),
          LlmMessage.assistant(text: r1.content),
          const LlmMessage.user('What is my name and what do I like?'),
        ],
        temperature: 0.0,
        maxTokens: 50,
      );

      expect(r2.content.toLowerCase(), contains('alice'));
      expect(r2.content.toLowerCase(), contains('cat'));

      print('  └─ turn1: ${r1.content}');
      print('  └─ turn2: ${r2.content}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('5. AgentCore — full ReAct loop with tools', () async {
      final config = AgentConfig(
        id: 'qiniu-test-agent',
        name: 'Qiniu Test Agent',
        systemPrompt: 'You are a helpful math assistant. Always use the calculator tool for math questions.',
        model: qiniuModel,
        toolNames: const ['calculator', 'get_current_time'],
        maxSteps: 5,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(userInput: 'What is 15 * 37?')) {
        events.add(event);
        // Print trace
        if (event is ThinkingEvent) {
          print('  │ thinking: ${event.delta}');
        } else if (event is ContentEvent) {
          stdout.write(event.delta);
        } else if (event is ToolCallEvent) {
          print('  │ tool_call: ${event.call.name}(${event.call.arguments})');
        } else if (event is ToolResultEvent) {
          print('  │ tool_result: ${event.result.output}');
        } else if (event is DoneEvent) {
          print('  │ done: "${event.finalReply}"');
          print('  │ stats: steps=${event.stats.steps} '
              'tokens=${event.stats.totalTokens} '
              'toolCalls=${event.stats.toolCalls}');
        } else if (event is ErrorEvent) {
          print('  │ error: ${event.message}');
        }
      }

      // Verify the ReAct loop completed
      final doneEvents = events.whereType<DoneEvent>().toList();
      expect(doneEvents, hasLength(1));

      final toolCallEvents = events.whereType<ToolCallEvent>().toList();
      expect(toolCallEvents, isNotEmpty);
      expect(toolCallEvents[0].call.name, 'calculator');

      final toolResultEvents = events.whereType<ToolResultEvent>().toList();
      expect(toolResultEvents, isNotEmpty);
      expect(toolResultEvents[0].result.success, true);
      // 15*37 = 555
      expect(toolResultEvents[0].result.output, contains('555'));

      // The final reply should contain the answer
      expect(doneEvents[0].finalReply.toLowerCase(), contains('555'));

      print('  └─ events: ${events.length} total');
      print('  └─ final: ${doneEvents[0].finalReply}');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('6. AgentCore — pure chat (no tools)', () async {
      final config = AgentConfig(
        id: 'qiniu-chat-agent',
        name: 'Qiniu Chat Agent',
        systemPrompt: 'You are a friendly assistant. Keep replies short.',
        model: qiniuModel,
        toolNames: const [],
        maxSteps: 1,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(userInput: 'Say hello in 5 words.')) {
        events.add(event);
        if (event is ContentEvent) {
          stdout.write(event.delta);
        } else if (event is DoneEvent) {
          print('');
          print('  └─ stats: tokens=${event.stats.totalTokens}');
        }
      }

      final doneEvents = events.whereType<DoneEvent>().toList();
      expect(doneEvents, hasLength(1));
      expect(doneEvents[0].finalReply, isNotEmpty);

      // Should NOT have tool calls
      final toolCallEvents = events.whereType<ToolCallEvent>().toList();
      expect(toolCallEvents, isEmpty);

      print('  └─ reply: ${doneEvents[0].finalReply}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('7. AgentCore — multi-step ReAct (two tool calls)', () async {
      final config = AgentConfig(
        id: 'qiniu-multi-step-agent',
        name: 'Qiniu Multi-Step Agent',
        systemPrompt: 'You are a helpful assistant. Use tools when asked.',
        model: qiniuModel,
        toolNames: const ['calculator', 'get_current_time'],
        maxSteps: 10,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(
        userInput: 'What is 12 * 8? Also tell me the current time.',
      )) {
        events.add(event);
        if (event is ContentEvent) {
          stdout.write(event.delta);
        } else if (event is ToolCallEvent) {
          print('  │ tool_call: ${event.call.name}(${event.call.arguments})');
        } else if (event is ToolResultEvent) {
          print('  │ tool_result: ${event.result.output}');
        } else if (event is DoneEvent) {
          print('');
          print('  └─ stats: steps=${event.stats.steps} '
              'tokens=${event.stats.totalTokens} '
              'toolCalls=${event.stats.toolCalls}');
        }
      }

      final doneEvents = events.whereType<DoneEvent>().toList();
      expect(doneEvents, hasLength(1));

      final toolCallEvents = events.whereType<ToolCallEvent>().toList();
      // Should have at least 2 tool calls (calculator + get_current_time)
      expect(toolCallEvents.length, greaterThanOrEqualTo(2));

      final toolNames = toolCallEvents.map((e) => e.call.name).toSet();
      expect(toolNames, contains('calculator'));
      expect(toolNames, contains('get_current_time'));

      // 12*8 = 96
      final calcResult = events
          .whereType<ToolResultEvent>()
          .firstWhere((e) => e.toolName == 'calculator');
      expect(calcResult.result.output, contains('96'));

      print('  └─ tool calls: ${toolCallEvents.length}');
      print('  └─ tools used: $toolNames');
      print('  └─ final: ${doneEvents[0].finalReply}');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
