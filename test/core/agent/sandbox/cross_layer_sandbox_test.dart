import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent.dart';
import 'package:nudgee/core/agent/sandbox/sandbox.dart';

import '../memory/mock_memory_storage.dart';

const String qiniuApiKey = 'sk-c3qxB9P3y1hq9xuiqOduUg';
const String qiniuBaseUrl = 'https://llmapi.qiniu.io/v1';
const String qiniuModel = 'gpt-5.4-mini';

void main() {
  group('Cross-Layer Integration — Phase 6 (Sandbox + Full Stack)', () {
    late DeepSeekClient client;
    late ToolRegistry toolRegistry;
    late SandboxExecutor sandboxExecutor;
    late SandboxExecTool sandboxTool;

    setUpAll(() {
      client = DeepSeekClient(
        apiKey: qiniuApiKey,
        baseUrl: qiniuBaseUrl,
        defaultModel: qiniuModel,
      );
      toolRegistry = ToolRegistry();
      registerBuiltinTools(toolRegistry);
      sandboxExecutor = SandboxExecutor();
      sandboxTool = SandboxExecTool(executor: sandboxExecutor);
      toolRegistry.register(sandboxTool);
    });

    tearDownAll(() {
      client.dispose();
    });

    // ── L2+L6: Sandbox tool registered in ToolRegistry ────────────────────

    test('L2+L6: SandboxExecTool is registered and discoverable', () async {
      expect(toolRegistry.contains('sandbox.exec'), true);

      final searchResult = await toolRegistry.execute('tool.search', {
        'keyword': 'execute code',
      });
      expect(searchResult.success, true);
      expect(searchResult.output, contains('sandbox.exec'));
    });

    // ── L6: Sandbox executes math via tool ────────────────────────────────

    test('L6: SandboxExecTool executes arithmetic', () async {
      final result = await toolRegistry.execute('sandbox.exec', {
        'code': '1 + 2 * 3',
      });
      expect(result.success, true);
      expect(result.output, contains('7'));
    });

    test('L6: SandboxExecTool executes print', () async {
      final result = await toolRegistry.execute('sandbox.exec', {
        'code': 'print("Hello from sandbox!");',
      });
      expect(result.success, true);
      expect(result.output, contains('Hello from sandbox!'));
    });

    test('L6: SandboxExecTool rejects dangerous code', () async {
      final result = await toolRegistry.execute('sandbox.exec', {
        'code': "import 'dart:io';",
      });
      expect(result.success, false);
      expect(result.error, contains('rejected'));
    });

    test('L6: SandboxExecTool handles list operations', () async {
      final result = await toolRegistry.execute('sandbox.exec', {
        'code': '[1, 2, 3, 4, 5]',
      });
      expect(result.success, true);
      expect(result.output, contains('1'));
      expect(result.output, contains('5'));
    });

    test('L6: SandboxExecTool handles map operations', () async {
      final result = await toolRegistry.execute('sandbox.exec', {
        'code': '{"name": "Alice", "age": 30}',
      });
      expect(result.success, true);
      expect(result.output, contains('Alice'));
    });

    // ── L6: Bridge functions ──────────────────────────────────────────────

    test('L6: Bridge function accessible from sandbox', () async {
      sandboxTool.registerBridgeFunction('square', (args, kwargs) async {
        final n = (args[0] as num).toInt();
        return n * n;
      });

      final result = await toolRegistry.execute('sandbox.exec', {
        'code': 'square(7)',
      });
      expect(result.success, true);
      expect(result.output, contains('49'));
    });

    test('L6: Bridge function with string processing', () async {
      sandboxTool.registerBridgeFunction('uppercase', (args, kwargs) async {
        return (args[0] as String).toUpperCase();
      });

      final result = await toolRegistry.execute('sandbox.exec', {
        'code': 'uppercase("hello")',
      });
      expect(result.success, true);
      expect(result.output, contains('HELLO'));
    });

    // ── L1+L2+L6: Agent uses sandbox tool ─────────────────────────────────

    test('L1+L2+L6: Agent uses sandbox.exec for computation', () async {
      final config = AgentConfig(
        id: 'sandbox-agent',
        name: 'Sandbox Agent',
        systemPrompt:
            'You are a helpful assistant. You have a sandbox.exec tool '
            'to execute Dart code. Use it for calculations when asked.',
        model: qiniuModel,
        toolNames: const ['sandbox.exec', 'tool.search'],
        maxSteps: 5,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: ContextGovernor(
          systemPrompt: config.systemPrompt,
        ),
        permissionContext:
            PermissionContext.fixed(PermissionMode.bypassPermissions),
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(
        userInput: 'Calculate 15 * 37 using the sandbox.exec tool.',
      )) {
        events.add(event);
      }

      final done = events.whereType<DoneEvent>().first;
      expect(done.finalReply, isNotEmpty);

      // The agent should have called sandbox.exec
      final toolCalls = events.whereType<ToolCallEvent>();
      final sandboxCall = toolCalls.where((e) => e.call.name == 'sandbox.exec');
      print('\n  -> agent reply: ${done.finalReply}');
      print('  -> sandbox.exec calls: ${sandboxCall.length}');
      print('  -> all tool calls: ${toolCalls.map((e) => e.call.name).toList()}');

      // The reply should contain 555 (15 * 37 = 555)
      expect(
        done.finalReply.contains('555'),
        true,
        reason: 'Response should contain the calculation result 555',
      );
    }, timeout: const Timeout(Duration(seconds: 60)));

    // ── L1+L2+L6: Agent uses sandbox for string processing ───────────────

    test('L1+L2+L6: Agent uses sandbox for string manipulation', () async {
      final config = AgentConfig(
        id: 'string-agent',
        name: 'String Agent',
        systemPrompt:
            'You are a helpful assistant. Use the sandbox.exec tool '
            'to process strings when needed.',
        model: qiniuModel,
        toolNames: const ['sandbox.exec'],
        maxSteps: 5,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: ContextGovernor(
          systemPrompt: config.systemPrompt,
        ),
        permissionContext:
            PermissionContext.fixed(PermissionMode.bypassPermissions),
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(
        userInput: 'Use sandbox.exec to concatenate "Hello" and "World" '
            'with a space between them.',
      )) {
        events.add(event);
      }

      final done = events.whereType<DoneEvent>().first;
      print('\n  -> string agent reply: ${done.finalReply}');

      // The agent should mention hello or world in some form
      final lower = done.finalReply.toLowerCase();
      expect(
        lower.contains('hello') || lower.contains('world'),
        true,
        reason: 'Response should mention the string result',
      );
    }, timeout: const Timeout(Duration(seconds: 60)));

    // ── L6: Static analyzer + permissions ─────────────────────────────────

    test('L6: Static analyzer with compute permissions allows network code',
        () {
      const code = 'HttpClient().getUrl(Uri.parse("https://api.example.com"));';
      final report = sandboxExecutor.analyze(
        code,
        permissions: SandboxPermissions.compute,
      );
      // Network is allowed with compute permissions
      expect(
        report.issues
            .where((i) => i.type == SandboxSafetyIssueType.networkAccess),
        isEmpty,
      );
    });

    test('L6: Static analyzer blocks network without permissions', () {
      const code = 'HttpClient().getUrl(Uri.parse("https://api.example.com"));';
      final report = sandboxExecutor.analyze(code);
      expect(
        report.issues
            .any((i) => i.type == SandboxSafetyIssueType.networkAccess),
        true,
      );
    });

    // ── L6: Timeout enforcement ───────────────────────────────────────────

    test('L6: Timeout is enforced', () async {
      sandboxTool.registerBridgeFunction('slow', (args, kwargs) async {
        await Future.delayed(const Duration(seconds: 5));
        return 'done';
      });

      final result = await sandboxExecutor.execute(
        'slow()',
        permissions: const SandboxPermissions(timeout: Duration(seconds: 1)),
      );
      expect(result.success, false);
      expect(result.errorType, 'TimeoutException');
    });

    // ── L6: Full stack — agent + sandbox + memory ─────────────────────────

    test('L1+L2+L3+L6: Agent uses sandbox with memory context', () async {
      // Set up memory with user preference
      final storage = MockMemoryStorage();
      final memoryManager = MemoryManager(
        storage: storage,
        llmClient: client,
        llmModel: qiniuModel,
      );
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'pref.calc_style',
        category: MemoryCategory.preference,
        value: 'User prefers detailed step-by-step calculations',
        confidence: 0.9,
        source: 'test',
      ));

      final memoryCtx = memoryManager.buildMemoryContext();
      expect(memoryCtx, contains('step-by-step'));

      final config = AgentConfig(
        id: 'memory-sandbox-agent',
        name: 'Memory Sandbox Agent',
        systemPrompt:
            'You are a math assistant. The user prefers detailed '
            'step-by-step calculations. Use sandbox.exec tool to compute.',
        model: qiniuModel,
        toolNames: const ['sandbox.exec'],
        maxSteps: 5,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: ContextGovernor(
          systemPrompt: config.systemPrompt,
        ),
        permissionContext:
            PermissionContext.fixed(PermissionMode.bypassPermissions),
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(
        userInput: 'What is 25 * 16? Show the calculation.',
        extraSystemContext: '--- User Memory ---\n$memoryCtx',
      )) {
        events.add(event);
      }

      final done = events.whereType<DoneEvent>().first;
      print('\n  -> memory+sandbox reply:\n${done.finalReply}');

      expect(done.finalReply, isNotEmpty);
      expect(
        done.finalReply.contains('400'),
        true,
        reason: '25 * 16 = 400, should be in response',
      );
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
