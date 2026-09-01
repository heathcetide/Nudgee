import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent.dart';
import 'package:nudgee/core/agent/memory/memory.dart';

import 'mock_memory_storage.dart';

import '../test_env.dart';

// LLM config from environment — tests skip if NUDGEE_LLM_API_KEY not set.
final String qiniuApiKey = TestEnv.llmApiKey ?? '';
final String qiniuBaseUrl = TestEnv.llmBaseUrl;
final String qiniuModel = TestEnv.llmModel;

void main() {
  if (!TestEnv.hasLlmKey) return; // Skip: no NUDGEE_LLM_API_KEY
  group('Cross-Layer Integration — Phase 1 + 2 + 3', () {
    late DeepSeekClient client;
    late ToolRegistry toolRegistry;
    late MockMemoryStorage storage;
    late MemoryManager memoryManager;
    late AgentTrace trace;

    setUpAll(() {
      // Skip setup if no API key — individual tests will also check.
      if (!TestEnv.hasLlmKey) return;
      client = DeepSeekClient(
        apiKey: qiniuApiKey,
        baseUrl: qiniuBaseUrl,
        defaultModel: qiniuModel,
      );
      toolRegistry = ToolRegistry();
      registerBuiltinTools(toolRegistry);
    });

    tearDownAll(() {
      client.dispose();
    });

    setUp(() {
      storage = MockMemoryStorage();
      memoryManager = MemoryManager(
        storage: storage,
        llmClient: client,
        llmModel: qiniuModel,
      );
      trace = AgentTrace();
    });

    // ── Layer 1+2: AgentCore + Tools ─────────────────────────────────────

    test('L1+L2: AgentCore uses builtin tools with trace recording', () async {
      final governor = ContextGovernor(
        systemPrompt: 'You are a helpful assistant. Use tools when asked.',
        contextWindow: 64000,
      );

      final config = AgentConfig(
        id: 'cross-l1-l2',
        name: 'Cross L1+L2',
        systemPrompt: 'You are a helpful assistant.',
        model: qiniuModel,
        toolNames: const ['todo.write', 'tool.search'],
        maxSteps: 10,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: governor,
        permissionContext:
            PermissionContext.fixed(PermissionMode.bypassPermissions),
        trace: trace,
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(
        userInput: 'Create a todo list with 2 items: buy groceries and call mom. '
            'Then search for tools related to "schedule".',
      )) {
        events.add(event);
      }

      // Verify Layer 1 (AgentCore) worked
      expect(events.whereType<DoneEvent>(), isNotEmpty);
      final done = events.whereType<DoneEvent>().first;
      expect(done.finalReply, isNotEmpty);

      // Verify Layer 2 (Tools) worked
      final toolCalls = events.whereType<ToolCallEvent>().toList();
      expect(toolCalls.length, greaterThanOrEqualTo(2));
      expect(toolCalls.any((e) => e.call.name == 'todo.write'), true);
      expect(toolCalls.any((e) => e.call.name == 'tool.search'), true);

      // Verify trace recorded everything
      expect(trace.isNotEmpty, true);
      expect(trace.findByType(TraceEntryType.runStart), hasLength(1));
      expect(trace.findByType(TraceEntryType.runEnd), hasLength(1));
      expect(trace.toolCalls.length, greaterThanOrEqualTo(2));
      expect(trace.toolResults.length, greaterThanOrEqualTo(2));
      // All tool results should be successful
      for (final tr in trace.toolResults) {
        expect(tr.data['success'], true,
            reason: 'Tool ${tr.data['toolName']} failed');
      }

      print('\n  -> events: ${events.length}');
      print('  -> tool calls: ${toolCalls.length}');
      print('  -> trace entries: ${trace.length}');
      print('  -> reply: ${done.finalReply}');
    }, timeout: const Timeout(Duration(seconds: 90)));

    // ── Layer 1+3: AgentCore + Memory injection ──────────────────────────

    test('L1+L3: AgentCore uses injected memory to personalize response',
        () async {
      // Pre-populate memory
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'fact.name',
        category: MemoryCategory.fact,
        value: 'The user\'s name is Charlie',
        confidence: 0.95,
        source: 'user_explicit',
      ));
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'preference.language',
        category: MemoryCategory.preference,
        value: 'The user prefers responses in Chinese',
        confidence: 0.9,
        source: 'user_explicit',
      ));

      final governor = ContextGovernor(
        systemPrompt: 'You are a personal assistant. '
            'Use the user memory to personalize responses. '
            'Follow the user\'s language preference.',
        memoryManager: memoryManager,
      );

      final config = AgentConfig(
        id: 'cross-l1-l3',
        name: 'Cross L1+L3',
        systemPrompt: 'You are a personal assistant.',
        model: qiniuModel,
        toolNames: const [],
        maxSteps: 1,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: ToolRegistry(),
        contextGovernor: governor,
        permissionContext:
            PermissionContext.fixed(PermissionMode.bypassPermissions),
        trace: trace,
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(userInput: 'Greet me by name.')) {
        events.add(event);
      }

      final done = events.whereType<DoneEvent>().first;
      print('\n  -> reply: ${done.finalReply}');

      // Should use the name from memory
      expect(done.finalReply.toLowerCase(), contains('charlie'));

      // Trace should show the system prompt included memory
      final llmReqs = trace.findByType(TraceEntryType.llmRequest);
      expect(llmReqs, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    // ── Layer 2+3: Memory extraction from tool-using conversation ────────

    test('L2+L3: Extract memory from a conversation that used tools',
        () async {
      // Simulate a conversation where tools were used
      final messages = [
        LlmMessage.user('I\'m a product manager. Add a task "Review Q3 roadmap" '
            'to my schedule for tomorrow at 2pm.'),
        LlmMessage.assistant(
            text: 'I\'ve added "Review Q3 roadmap" to your schedule for tomorrow '
                'at 2pm. As a product manager, this seems like an important task!',
            toolCalls: [
              ToolCall(
                id: 'call_1',
                name: 'schedule.add',
                arguments: {
                  'name': 'Review Q3 roadmap',
                  'date': '2026-09-02',
                  'startTime': '14:00',
                  'endTime': '15:00',
                },
              ),
            ],
        ),
        LlmMessage.tool(
          toolCallId: 'call_1',
          name: 'schedule.add',
          content: 'Schedule added: "Review Q3 roadmap" on 2026-09-02 '
              'from 14:00 to 15:00',
        ),
      ];

      // Extract long-term memory from this tool-using conversation
      final episode = await memoryManager.summarizeEpisode(
        messages: messages,
        sessionStart: DateTime.parse('2026-09-01T10:00:00'),
        stepCount: 1,
        toolsUsed: const ['schedule.add'],
      );

      print('\n  -> episode summary: ${episode.summary}');
      print('  -> topics: ${episode.topics}');
      print('  -> tools used: ${episode.toolsUsed}');

      expect(episode.summary, isNotEmpty);
      expect(episode.toolsUsed, contains('schedule.add'));

      // Now extract long-term memory
      final extracted = await memoryManager.extractLongTerm(
        messages: messages,
        episode: episode,
      );

      print('  -> extracted ${extracted.length} memory items:');
      for (final item in extracted) {
        print('      [${item.category.name}] ${item.key}: ${item.value}');
      }

      expect(extracted, isNotEmpty);

      // Should have extracted the occupation
      final allValues = extracted.map((m) => m.value.toLowerCase()).join(' ');
      expect(
        allValues.contains('product manager') ||
            allValues.contains('pm'),
        true,
        reason: 'Should extract occupation from conversation',
      );
    }, timeout: const Timeout(Duration(seconds: 60)));

    // ── Layer 1+2+3: Full stack — tools + memory + trace ─────────────────

    test('L1+L2+L3: Full stack — memory-informed tool usage with trace',
        () async {
      // Step 1: Pre-populate memory with user preferences
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'fact.occupation',
        category: MemoryCategory.fact,
        value: 'The user is a software engineer',
        confidence: 0.9,
        source: 'user_explicit',
      ));
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'preference.task_style',
        category: MemoryCategory.preference,
        value: 'The user likes to plan tasks before executing them',
        confidence: 0.8,
        source: 'llm_extract',
      ));

      // Step 2: Create agent with memory + tools + trace
      final governor = ContextGovernor(
        systemPrompt: 'You are a personal productivity assistant. '
            'Use the user memory to personalize. '
            'When the user asks to plan something, use todo.write to create a plan.',
        memoryManager: memoryManager,
      );

      final config = AgentConfig(
        id: 'cross-full',
        name: 'Cross Full Stack',
        systemPrompt: 'You are a personal productivity assistant.',
        model: qiniuModel,
        toolNames: const ['todo.write', 'tool.search'],
        maxSteps: 10,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: toolRegistry,
        contextGovernor: governor,
        permissionContext:
            PermissionContext.fixed(PermissionMode.bypassPermissions),
        trace: trace,
      );

      // Step 3: Run the agent
      final events = <AgentEvent>[];
      await for (final event in core.run(
        userInput: 'Help me plan my day. I need to review code and write documentation.',
      )) {
        events.add(event);
      }

      final done = events.whereType<DoneEvent>().first;
      print('\n  -> reply: ${done.finalReply}');

      // Layer 1: AgentCore completed
      expect(done.finalReply, isNotEmpty);

      // Layer 2: Tools were used
      final toolCalls = events.whereType<ToolCallEvent>().toList();
      expect(toolCalls, isNotEmpty);
      expect(toolCalls.any((e) => e.call.name == 'todo.write'), true);

      // Layer 3: Trace recorded the full chain
      expect(trace.isNotEmpty, true);
      expect(trace.findByType(TraceEntryType.runStart), hasLength(1));
      expect(trace.findByType(TraceEntryType.runEnd), hasLength(1));
      expect(trace.toolCalls, isNotEmpty);
      expect(trace.toolResults, isNotEmpty);

      // The system prompt should have included memory
      final llmReq = trace.findByType(TraceEntryType.llmRequest).first;
      expect(llmReq.data['messageCount'], greaterThan(0));

      // All tool results should be successful
      for (final tr in trace.toolResults) {
        expect(tr.data['success'], true,
            reason: 'Tool ${tr.data['toolName']} failed');
      }

      // Step 4: Now summarize this session and extract memory
      // Build the conversation messages from events
      final conversationMessages = <LlmMessage>[
        LlmMessage.user(
            'Help me plan my day. I need to review code and write documentation.'),
        LlmMessage.assistant(text: done.finalReply),
      ];

      final episode = await memoryManager.summarizeEpisode(
        messages: conversationMessages,
        sessionStart: DateTime.now(),
        stepCount: trace.findByType(TraceEntryType.stepStart).length,
        toolsUsed: toolCalls.map((e) => e.call.name).toSet().toList(),
      );

      print('\n  -> episode: ${episode.summary}');
      print('  -> tools used in episode: ${episode.toolsUsed}');

      expect(episode.summary, isNotEmpty);
      expect(episode.toolsUsed, contains('todo.write'));

      // Save episode
      await memoryManager.saveEpisode(episode);

      // Verify episode is stored
      final stored = await storage.loadEpisode(episode.id);
      expect(stored, isNotNull);
      expect(stored!.toolsUsed, contains('todo.write'));

      // Step 5: Verify memory context now includes the episode
      final memoryContext = memoryManager.buildMemoryContext();
      expect(memoryContext, contains('## Recent Sessions'));
      expect(memoryContext.toLowerCase(), contains('plan'));

      print('\n  -> full trace entries: ${trace.length}');
      print('  -> memory items: ${memoryManager.longTerm.length}');
      print('  -> episodes: ${memoryManager.episodes.length}');
      print('\n${trace.format()}');
    }, timeout: const Timeout(Duration(seconds: 120)));

    // ── Multi-session: memory persists across sessions ───────────────────

    test('Multi-session: memory from session 1 is used in session 2',
        () async {
      // Session 1: User tells the agent their name
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'fact.name',
        category: MemoryCategory.fact,
        value: 'The user\'s name is Diana',
        confidence: 0.95,
        source: 'user_explicit',
      ));
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'preference.reply_style',
        category: MemoryCategory.preference,
        value: 'The user prefers very short replies',
        confidence: 0.85,
        source: 'user_explicit',
      ));

      // Session 2: New agent instance, same memory
      final governor = ContextGovernor(
        systemPrompt: 'You are a personal assistant. '
            'Use user memory. Follow the user\'s reply style preference.',
        memoryManager: memoryManager,
      );

      final config = AgentConfig(
        id: 'multi-session-2',
        name: 'Session 2',
        systemPrompt: 'You are a personal assistant.',
        model: qiniuModel,
        toolNames: const [],
        maxSteps: 1,
      );

      final core = AgentCore(
        config: config,
        llmClient: client,
        toolRegistry: ToolRegistry(),
        contextGovernor: governor,
        permissionContext:
            PermissionContext.fixed(PermissionMode.bypassPermissions),
      );

      final events = <AgentEvent>[];
      await for (final event in core.run(
        userInput: 'What\'s my name? Answer briefly.',
      )) {
        events.add(event);
      }

      final done = events.whereType<DoneEvent>().first;
      print('\n  Session 2 reply: ${done.finalReply}');

      // Should recall the name from session 1's memory
      expect(done.finalReply.toLowerCase(), contains('diana'));
    }, timeout: const Timeout(Duration(seconds: 30)));

    // ── Memory + Sync: export/import round trip ──────────────────────────

    test('Memory + Sync: export -> import preserves all data', () async {
      // Populate with diverse memory items
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'fact.name',
        category: MemoryCategory.fact,
        value: 'Test user',
        confidence: 0.9,
      ));
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'preference.theme',
        category: MemoryCategory.preference,
        value: 'dark mode',
        confidence: 0.8,
      ));
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'skillMastery.dart',
        category: MemoryCategory.skillMastery,
        value: 'proficient',
        confidence: 0.85,
      ));
      await memoryManager.saveEpisode(EpisodeSummary(
        id: 'ep_sync_test',
        sessionStart: '2026-09-01T10:00:00',
        sessionEnd: '2026-09-01T11:00:00',
        summary: 'Sync test episode',
        topics: const ['sync', 'test'],
        toolsUsed: const ['todo.write'],
      ));

      // Export
      final exported = await storage.exportAll();
      expect(exported['memories'], isA<List>());
      expect((exported['memories'] as List).length, 3);
      expect(exported['episodes'], isA<List>());
      expect((exported['episodes'] as List).length, 1);

      // Import into a fresh storage
      final newStorage = MockMemoryStorage();
      final imported = await newStorage.importAll(exported);

      expect(imported, 4); // 3 memories + 1 episode

      // Verify data integrity
      final memories = await newStorage.loadAllMemories();
      expect(memories.length, 3);
      expect(memories.any((m) => m.key == 'fact.name'), true);
      expect(memories.any((m) => m.key == 'preference.theme'), true);
      expect(memories.any((m) => m.key == 'skillMastery.dart'), true);

      final episodes = await newStorage.loadAllEpisodes();
      expect(episodes.length, 1);
      expect(episodes[0].id, 'ep_sync_test');
      expect(episodes[0].toolsUsed, contains('todo.write'));

      print('\n  -> exported ${memories.length} memories + ${episodes.length} episodes');
      print('  -> imported $imported items successfully');
    }, timeout: const Timeout(Duration(seconds: 30)));

    // ── Memory merge: conflict resolution across "devices" ───────────────

    test('Memory merge: conflict resolution simulating two devices', () async {
      // Device A: saves preference at v1
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'preference.theme',
        category: MemoryCategory.preference,
        value: 'light mode',
        confidence: 0.7,
        version: 1,
      ));

      // Device B: saves same key at v2 (newer)
      final deviceBData = {
        'userId': 'default',
        'version': 1,
        'memories': [
          MemoryItem.now(
            key: 'preference.theme',
            category: MemoryCategory.preference,
            value: 'dark mode',
            confidence: 0.9,
            version: 2,
          ).toJson(),
        ],
        'episodes': [],
      };

      // Sync: import device B's data (should merge)
      final imported = await storage.importAll(deviceBData);
      expect(imported, 1);

      // The merged result should be v2 (dark mode) since it has higher version
      final merged = await storage.loadMemory('preference.theme');
      expect(merged!.version, 2);
      expect(merged.value, 'dark mode');

      print('\n  -> merged value: ${merged.value} (v${merged.version})');

      // Now verify the memory manager cache is updated
      await memoryManager.loadCache();
      final cached = memoryManager.getMemory('preference.theme');
      expect(cached!.value, 'dark mode');
      expect(cached.version, 2);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
