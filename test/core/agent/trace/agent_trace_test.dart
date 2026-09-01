import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent.dart';

import '../test_env.dart';

// LLM config from environment — tests skip if NUDGEE_LLM_API_KEY not set.
final String qiniuApiKey = TestEnv.llmApiKey ?? '';
final String qiniuBaseUrl = TestEnv.llmBaseUrl;
final String qiniuModel = TestEnv.llmModel;

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
    final expr = args['expression'] as String? ?? '';
    if (expr.contains('*')) {
      final parts = expr.split('*');
      if (parts.length == 2) {
        final result = double.parse(parts[0]) * double.parse(parts[1]);
        return ToolResult.success('$expr = $result');
      }
    }
    return const ToolResult.error('Unsupported expression');
  }
}

class TimeTool extends AgentTool {
  @override
  String get name => 'get_current_time';

  @override
  String get description => 'Get the current date and time in ISO format.';

  @override
  Map<String, dynamic> get parametersSchema => {'type': 'object'};

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    return ToolResult.success(DateTime.now().toIso8601String());
  }
}

void main() {
  if (!TestEnv.hasLlmKey) return; // Skip: no NUDGEE_LLM_API_KEY
  group('Agent Trace — End-to-End Observability', () {
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

    tearDownAll(() => client.dispose());

    test('trace records full ReAct loop with tools', () async {
      final trace = AgentTrace();

      final config = AgentConfig(
        id: 'trace-test-agent',
        name: 'Trace Test Agent',
        systemPrompt: 'You are a helpful math assistant. Use the calculator tool for math.',
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
        trace: trace,
      );

      await for (final _ in core.run(userInput: 'What is 12 * 8?')) {
        // Consume events — trace is recorded internally
      }

      // ── Verify trace structure ──
      print('\n${trace.format()}');

      expect(trace.isNotEmpty, true);
      expect(trace.length, greaterThan(5));

      // Should have run start
      final runStarts = trace.findByType(TraceEntryType.runStart);
      expect(runStarts, hasLength(1));
      expect(runStarts[0].data['input'], 'What is 12 * 8?');
      expect(runStarts[0].data['model'], qiniuModel);

      // Should have step starts
      final stepStarts = trace.findByType(TraceEntryType.stepStart);
      expect(stepStarts, isNotEmpty);

      // Should have LLM requests
      final llmReqs = trace.findByType(TraceEntryType.llmRequest);
      expect(llmReqs, isNotEmpty);
      expect(llmReqs[0].data['toolCount'], 2);

      // Should have LLM responses
      final llmResps = trace.findByType(TraceEntryType.llmResponse);
      expect(llmResps, isNotEmpty);

      // Should have tool calls
      final toolCalls = trace.toolCalls;
      expect(toolCalls, isNotEmpty);
      expect(toolCalls[0].data['toolName'], 'calculator');

      // Should have tool results
      final toolResults = trace.toolResults;
      expect(toolResults, isNotEmpty);
      expect(toolResults[0].data['success'], true);
      expect(toolResults[0].data['output'], contains('96'));

      // Should have permission checks
      final permChecks = trace.findByType(TraceEntryType.permissionCheck);
      expect(permChecks, isNotEmpty);
      expect(permChecks[0].data['decision'], 'allow');

      // Should have run end
      final runEnds = trace.findByType(TraceEntryType.runEnd);
      expect(runEnds, hasLength(1));
      expect(runEnds[0].data['stats'], isNotNull);

      // ── Verify JSON serialization ──
      final json = trace.toJson();
      expect(json['entryCount'], trace.length);
      expect(json['entries'], isA<List>());
      expect((json['entries'] as List).length, trace.length);

      final jsonStr = trace.toJsonString();
      expect(jsonStr, isNotEmpty);
      expect(jsonStr, contains('runStart'));
      expect(jsonStr, contains('toolCall'));
      expect(jsonStr, contains('toolResult'));
      expect(jsonStr, contains('runEnd'));

      print('\n── JSON Trace (first 500 chars) ──');
      print(jsonStr.substring(0, jsonStr.length > 500 ? 500 : jsonStr.length));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('trace records pure chat (no tools)', () async {
      final trace = AgentTrace();

      final config = AgentConfig(
        id: 'trace-chat-agent',
        name: 'Trace Chat Agent',
        systemPrompt: 'You are friendly. Keep replies short.',
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
        trace: trace,
      );

      await for (final _ in core.run(userInput: 'Say hello in 3 words.')) {}

      print('\n${trace.format()}');

      // Should have run start, LLM request (streaming), run end
      expect(trace.findByType(TraceEntryType.runStart), hasLength(1));
      expect(trace.findByType(TraceEntryType.llmRequest), hasLength(1));
      expect(trace.findByType(TraceEntryType.llmRequest)[0].data['streaming'], true);
      expect(trace.findByType(TraceEntryType.runEnd), hasLength(1));

      // Should NOT have tool calls
      expect(trace.toolCalls, isEmpty);
      expect(trace.toolResults, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('trace records multi-step ReAct with 2 tools', () async {
      final trace = AgentTrace();

      final config = AgentConfig(
        id: 'trace-multi-agent',
        name: 'Trace Multi Agent',
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
        trace: trace,
      );

      await for (final _ in core.run(
        userInput: 'What is 7 * 6? Also tell me the current time.',
      )) {}

      print('\n${trace.format()}');

      // Should have at least 2 tool calls
      expect(trace.toolCalls.length, greaterThanOrEqualTo(2));

      final toolNames = trace.toolCalls.map((e) => e.data['toolName']).toSet();
      expect(toolNames, contains('calculator'));
      expect(toolNames, contains('get_current_time'));

      // Calculator should return 42
      final calcResult = trace.toolResults
          .where((e) => e.data['toolName'] == 'calculator')
          .first;
      expect(calcResult.data['output'], contains('42'));

      // Time tool should return a timestamp
      final timeResult = trace.toolResults
          .where((e) => e.data['toolName'] == 'get_current_time')
          .first;
      expect(timeResult.data['output'], contains('20'));  // Year 20xx

      print('\n── Tool Call Summary ──');
      for (final tc in trace.toolCalls) {
        stdout.writeln('  ${tc.seq}: ${tc.summary}');
      }
      print('── Tool Result Summary ──');
      for (final tr in trace.toolResults) {
        stdout.writeln('  ${tr.seq}: ${tr.summary}');
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('trace can be recorded from events via recordEvent', () async {
      final trace = AgentTrace();

      final config = AgentConfig(
        id: 'trace-event-agent',
        name: 'Trace Event Agent',
        systemPrompt: 'You are a math assistant. Use the calculator tool.',
        model: qiniuModel,
        toolNames: const ['calculator'],
        maxSteps: 5,
      );

      // No trace passed to AgentCore — we'll record from events manually
      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: contextGovernor,
        permissionContext: permissionContext,
      );

      trace.recordRunStart(
        input: 'What is 9 * 9?',
        agentId: config.id,
        model: config.model,
      );

      await for (final event in core.run(userInput: "What is 9 * 9?")) {
        trace.recordEvent(event);
      }

      print('\n${trace.format()}');

      // Should have entries from events
      expect(trace.isNotEmpty, true);
      expect(trace.toolCalls, isNotEmpty);
      expect(trace.toolResults, isNotEmpty);
      expect(trace.findByType(TraceEntryType.runEnd), hasLength(1));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
