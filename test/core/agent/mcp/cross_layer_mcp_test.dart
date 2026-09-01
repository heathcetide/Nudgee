import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent.dart';
import 'package:nudgee/core/agent/mcp/mcp.dart';
import 'package:nudgee/core/agent/memory/memory.dart';
import 'package:nudgee/core/agent/skills/skills.dart';
import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

import '../memory/mock_memory_storage.dart';

const String qiniuApiKey = 'sk-c3qxB9P3y1hq9xuiqOduUg';
const String qiniuBaseUrl = 'https://llmapi.qiniu.io/v1';
const String qiniuModel = 'gpt-5.4-mini';

void main() {
  group('Cross-Layer Integration — Phase 1+2+3+4+5 (Full Stack + MCP)', () {
    late DeepSeekClient client;
    late ToolRegistry toolRegistry;
    late SkillRegistry skillRegistry;
    late McpManager mcpManager;
    late MockMemoryStorage storage;
    late MemoryManager memoryManager;

    setUpAll(() {
      client = DeepSeekClient(
        apiKey: qiniuApiKey,
        baseUrl: qiniuBaseUrl,
        defaultModel: qiniuModel,
      );
      toolRegistry = ToolRegistry();
      registerBuiltinTools(toolRegistry);
      skillRegistry = SkillRegistry();
      registerBuiltinSkills(skillRegistry);
      mcpManager = McpManager(toolRegistry: toolRegistry);
    });

    tearDownAll(() {
      mcpManager.disconnectAll();
      client.dispose();
    });

    setUp(() {
      storage = MockMemoryStorage();
      memoryManager = MemoryManager(
        storage: storage,
        llmClient: client,
        llmModel: qiniuModel,
      );
    });

    // ── L2+L5: MCP tools accessible via ToolRegistry ──────────────────────

    test('L2+L5: InProcessMcpServer exposes tools to ToolRegistry', () async {
      final inProcess = InProcessMcpServer(toolRegistry: toolRegistry);
      await mcpManager.connect(inProcess);

      // Tools should be available via McpManager
      final mcpTools = mcpManager.allTools();
      expect(mcpTools, isNotEmpty);
      expect(mcpTools.every((t) => t.serverId == 'nudgee-builtin'), true);

      // Should be able to call tools via McpManager
      final result = await mcpManager.callTool(
        'nudgee-builtin',
        'todo.write',
        {
          'todos': [
            {'content': 'MCP test', 'status': 'pending'}
          ]
        },
      );
      expect(result.success, true);

      print('\n  -> MCP tools: ${mcpTools.length}');
      print('  -> tool call result: ${result.output}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    // ── L1+L2+L5: Agent uses MCP-exposed tools ────────────────────────────

    test('L1+L2+L5: Agent uses tools exposed via MCP', () async {
      // Create a separate tool registry with only MCP-exposed tools
      final mcpRegistry = ToolRegistry();
      final mcpMgr = McpManager(toolRegistry: mcpRegistry);
      final inProcess = InProcessMcpServer(
        toolRegistry: toolRegistry, // source: builtin tools
        id: 'builtin-mcp',
      );
      await mcpMgr.connect(inProcess);

      // The MCP tools should now be in mcpRegistry
      expect(mcpRegistry.contains('todo.write'), true);
      expect(mcpRegistry.get('todo.write'), isA<McpToolAdapter>());

      // Run an agent that uses the MCP-exposed tool
      final config = AgentConfig(
        id: 'mcp-agent',
        name: 'MCP Agent',
        systemPrompt: 'You are a helpful assistant. Use tools when asked.',
        model: qiniuModel,
        toolNames: const ['todo.write', 'tool.search'],
        maxSteps: 10,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: mcpRegistry,
        contextGovernor: ContextGovernor(
          systemPrompt: 'You are a helpful assistant. Use tools when asked.',
        ),
        permissionContext:
            PermissionContext.fixed(PermissionMode.bypassPermissions),
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(
        userInput: 'Create a todo list with 1 item: "test MCP integration"',
      )) {
        events.add(event);
      }

      final done = events.whereType<DoneEvent>().first;
      expect(done.finalReply, isNotEmpty);

      // Verify the tool was called (via McpToolAdapter)
      final toolCalls = events.whereType<ToolCallEvent>();
      expect(toolCalls.any((e) => e.call.name == 'todo.write'), true);

      print('\n  -> agent reply: ${done.finalReply}');
      print('  -> tool calls: ${toolCalls.length}');

      await mcpMgr.disconnectAll();
    }, timeout: const Timeout(Duration(seconds: 60)));

    // ── L3+L5: MCP resources provide context to memory ───────────────────

    test('L3+L5: MCP resource content can be saved to memory', () async {
      final inProcess = InProcessMcpServer(toolRegistry: toolRegistry);
      inProcess.registerResource(
        'user://profile',
        () => 'Name: Grace, Role: Product Manager, Goals: ship v2.0',
      );
      await mcpManager.connect(inProcess);

      // Read resource via MCP
      final content =
          await mcpManager.readResource('nudgee-builtin', 'user://profile');
      expect(content, contains('Grace'));

      // Save to memory
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'fact.profile',
        category: MemoryCategory.fact,
        value: content,
        confidence: 0.9,
        source: 'mcp_resource',
      ));

      // Verify it's in memory
      final memContext = memoryManager.buildMemoryContext();
      expect(memContext, contains('Grace'));
      expect(memContext, contains('Product Manager'));

      print('\n  -> MCP resource: $content');
      print('  -> saved to memory, context includes profile info');
    }, timeout: const Timeout(Duration(seconds: 30)));

    // ── L4+L5: Skill uses MCP-exposed tools ───────────────────────────────

    test('L4+L5: Skill executor uses tools from MCP server', () async {
      final inProcess = InProcessMcpServer(toolRegistry: toolRegistry);
      await mcpManager.connect(inProcess);

      final executor = SkillExecutor(
        toolRegistry: toolRegistry,
        llmClient: client,
        llmModel: qiniuModel,
      );

      final events = <SkillExecutionEvent>[];
      await for (final event in executor.executeSkill(
        skill: skillRegistry.getById('daily_briefing')!,
        userInput: 'Give me a daily briefing',
      )) {
        events.add(event);
      }

      final done =
          events.where((e) => e.type == SkillExecutionEventType.done).first;
      expect(done.result!.success, true);
      expect(done.result!.toolsUsed, contains('schedule.query'));

      print('\n  -> skill result: ${done.result!.summary}');
      print('  -> tools used: ${done.result!.toolsUsed}');
    }, timeout: const Timeout(Duration(seconds: 60)));

    // ── L1+L2+L3+L4+L5: Full stack with MCP ───────────────────────────────

    test('L1+L2+L3+L4+L5: Full stack — memory + skill + MCP + agent', () async {
      // 1. Set up MCP
      final inProcess = InProcessMcpServer(toolRegistry: toolRegistry);
      inProcess.registerResource(
        'user://preferences',
        () => 'User prefers morning workouts and concise responses',
      );
      await mcpManager.connect(inProcess);

      // 2. Read MCP resource and save to memory
      await mcpManager.readResource('nudgee-builtin', 'user://preferences');
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'preference.morning_workout',
        category: MemoryCategory.preference,
        value: 'User prefers morning workouts',
        confidence: 0.85,
        source: 'mcp_resource',
      ));
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'preference.reply_style',
        category: MemoryCategory.preference,
        value: 'User prefers concise responses',
        confidence: 0.8,
        source: 'mcp_resource',
      ));

      // 3. Match a skill
      final harness = AgentHarness(
        llmClient: client,
        toolRegistry: toolRegistry,
        skillRegistry: skillRegistry,
        permissionContext:
            PermissionContext.fixed(PermissionMode.bypassPermissions),
        llmModel: qiniuModel,
      );

      final matchedSkill = await harness.matchSkill(
          'I want to start exercising in the morning');
      expect(matchedSkill, isNotNull);
      expect(matchedSkill!.id, 'fitness_plan');

      // 4. Execute skill with memory context
      final skillEvents = <SkillExecutionEvent>[];
      await for (final event in harness.executeSkill(
        skillId: 'fitness_plan',
        userInput: 'I want to start exercising in the morning',
        memoryContext: () => memoryManager.buildMemoryContext(),
      )) {
        skillEvents.add(event);
      }

      final skillDone = skillEvents
          .where((e) => e.type == SkillExecutionEventType.done)
          .first;
      expect(skillDone.result!.success, true);

      // 5. Run agent with skill output + memory
      final memoryCtx = memoryManager.buildMemoryContext();
      final skillOutput = skillEvents
          .where((e) => e.type == SkillExecutionEventType.output)
          .map((e) => e.output ?? '')
          .join('\n');

      harness.registerAgent(AgentConfig(
        id: 'full-mcp-agent',
        name: 'Full MCP Agent',
        systemPrompt: 'You are a personal fitness assistant. '
            'Use user memory and skill output. Be concise.',
        model: qiniuModel,
        toolNames: const [],
        maxSteps: 1,
      ));

      final agentEvents = <AgentEvent>[];
      await for (final event in harness.run(
        userInput: 'I want to start exercising in the morning',
        extraSystemContext: '--- User Memory ---\n$memoryCtx\n\n'
            '--- Skill Output ---\n$skillOutput',
      )) {
        agentEvents.add(event);
      }

      final done = agentEvents.whereType<DoneEvent>().first;
      print('\n  -> final reply:\n${done.finalReply}');

      expect(done.finalReply, isNotEmpty);
      // Should mention morning or workout (from skill + memory)
      final lower = done.finalReply.toLowerCase();
      expect(
        lower.contains('morning') ||
            lower.contains('workout') ||
            lower.contains('exercise') ||
            lower.contains('fitness'),
        true,
        reason: 'Response should include fitness/morning content',
      );
    }, timeout: const Timeout(Duration(seconds: 120)));

    // ── L5: MCP prompt template ───────────────────────────────────────────

    test('L5: MCP prompt template can be applied', () async {
      final inProcess = InProcessMcpServer(toolRegistry: toolRegistry);
      inProcess.registerPrompt('fitness_greeting', (args) {
        final name = args['name'] as String? ?? 'Athlete';
        final goal = args['goal'] as String? ?? 'fitness';
        return 'Hello $name! Ready to work on your $goal goal?';
      });
      await mcpManager.connect(inProcess);

      final prompts = mcpManager.allPrompts();
      expect(prompts, isNotEmpty);
      expect(prompts.first.name, 'fitness_greeting');

      final result = await mcpManager.applyPrompt(
        'nudgee-builtin',
        'fitness_greeting',
        {'name': 'Henry', 'goal': 'weight loss'},
      );
      expect(result, 'Hello Henry! Ready to work on your weight loss goal?');

      print('\n  -> prompt result: $result');
    }, timeout: const Timeout(Duration(seconds: 30)));

    // ── L5: Multiple MCP servers ──────────────────────────────────────────

    test('L5: Multiple MCP servers coexist', () async {
      // Use a fresh McpManager to avoid interference from previous tests
      final multiManager = McpManager(toolRegistry: ToolRegistry());

      // Server 1: builtin tools
      final server1 = InProcessMcpServer(
        toolRegistry: toolRegistry,
        id: 'builtin',
      );

      // Server 2: custom tools
      final customRegistry = ToolRegistry();
      customRegistry.register(_CalculatorTool());
      final server2 = InProcessMcpServer(
        toolRegistry: customRegistry,
        id: 'calculator',
      );

      await multiManager.connect(server1);
      await multiManager.connect(server2);

      expect(multiManager.length, 2);
      expect(multiManager.serverIds, containsAll(['builtin', 'calculator']));

      // Tools from both servers
      final allTools = multiManager.allTools();
      expect(allTools.any((t) => t.serverId == 'builtin'), true);
      expect(allTools.any((t) => t.serverId == 'calculator'), true);
      expect(allTools.any((t) => t.name == 'calculate'), true);

      // Call tool from calculator server
      final result = await multiManager.callTool('calculator', 'calculate', {
        'expression': '2+3',
      });
      expect(result.success, true);
      expect(result.output, '5');

      // Call tool by name (should find it across servers)
      final result2 = await multiManager.callToolByName('calculate', {
        'expression': '10*2',
      });
      expect(result2.success, true);
      expect(result2.output, '20');

      print('\n  -> server 1 tools: ${server1.listTools().length}');
      print('  -> server 2 tools: ${server2.listTools().length}');
      print('  -> total MCP tools: ${allTools.length}');
      print('  -> calculate 2+3 = ${result.output}');
      print('  -> calculate 10*2 = ${result2.output}');

      await multiManager.disconnect('calculator');
      // disconnect doesn't unregister, so length is still 2
      // but calculator is no longer connected
      expect(multiManager.getServer('calculator')!.isConnected, false);
      final remainingTools = multiManager.allTools();
      expect(remainingTools.every((t) => t.serverId != 'calculator'), true);
      await multiManager.disconnectAll();
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}

/// A simple calculator tool for testing multi-server MCP.
class _CalculatorTool extends AgentTool {
  @override
  String get name => 'calculate';

  @override
  String get description => 'Evaluate a simple arithmetic expression';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'expression': {'type': 'string', 'description': 'Arithmetic expression'},
        },
        'required': ['expression'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final expr = args['expression'] as String? ?? '';
    try {
      // Very simple: only handles "a+b" and "a*b"
      final addMatch = RegExp(r'^(\d+)\+(\d+)$').firstMatch(expr);
      final mulMatch = RegExp(r'^(\d+)\*(\d+)$').firstMatch(expr);
      if (addMatch != null) {
        final a = int.parse(addMatch.group(1)!);
        final b = int.parse(addMatch.group(2)!);
        return ToolResult.success('${a + b}');
      } else if (mulMatch != null) {
        final a = int.parse(mulMatch.group(1)!);
        final b = int.parse(mulMatch.group(2)!);
        return ToolResult.success('${a * b}');
      }
      return ToolResult.error('Unsupported expression: $expr');
    } catch (e) {
      return ToolResult.error(e.toString());
    }
  }
}
