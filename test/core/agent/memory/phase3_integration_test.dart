import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent.dart';
import 'package:nudgee/core/agent/memory/memory.dart';

import 'mock_memory_storage.dart';

const String qiniuApiKey = 'sk-c3qxB9P3y1hq9xuiqOduUg';
const String qiniuBaseUrl = 'https://llmapi.qiniu.io/v1';
const String qiniuModel = 'gpt-5.4-mini';

void main() {
  group('Phase 3 — Memory System Integration (Real API)', () {
    late DeepSeekClient client;
    late MockMemoryStorage storage;
    late MemoryManager manager;

    setUpAll(() {
      client = DeepSeekClient(
        apiKey: qiniuApiKey,
        baseUrl: qiniuBaseUrl,
        defaultModel: qiniuModel,
      );
    });

    tearDownAll(() {
      client.dispose();
    });

    setUp(() {
      storage = MockMemoryStorage();
      manager = MemoryManager(
        storage: storage,
        llmClient: client,
        llmModel: qiniuModel,
      );
    });

    test('1. summarizeEpisode generates summary from real conversation',
        () async {
      final messages = [
        LlmMessage.user('Help me plan my morning routine. I want to exercise at 7am.'),
        LlmMessage.assistant(
            text: 'Great idea! A morning routine with exercise at 7am is a healthy start. '
                'Would you like me to add it to your schedule?'),
        LlmMessage.user('Yes, please add it. Also add meditation at 8am.'),
        LlmMessage.assistant(
            text: 'Done! I\'ve added morning exercise at 7am and meditation at 8am '
                'to your schedule for tomorrow.'),
      ];

      final episode = await manager.summarizeEpisode(
        messages: messages,
        sessionStart: DateTime.parse('2026-09-01T10:00:00'),
        stepCount: 2,
        toolsUsed: const ['schedule.add'],
      );

      print('\n  -> summary: ${episode.summary}');
      print('  -> topics: ${episode.topics}');

      expect(episode.summary, isNotEmpty);
      expect(episode.summary.length, lessThan(500));
      expect(episode.messageCount, 4);
      expect(episode.stepCount, 2);
      expect(episode.toolsUsed, ['schedule.add']);
      // The LLM should extract some topics
      expect(episode.topics, isNotEmpty);
      // Topics should be relevant
      final topicsLower = episode.topics.join(' ').toLowerCase();
      expect(
        topicsLower.contains('routine') ||
            topicsLower.contains('exercise') ||
            topicsLower.contains('morning') ||
            topicsLower.contains('meditation') ||
            topicsLower.contains('schedule') ||
            topicsLower.contains('health'),
        true,
        reason: 'Topics should be relevant to the conversation: ${episode.topics}',
      );
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('2. extractLongTerm extracts preferences from conversation', () async {
      final messages = [
        LlmMessage.user('I\'m a frontend engineer working with React. '
            'I prefer concise replies and I like dark mode.'),
        LlmMessage.assistant(
            text: 'Got it! I\'ll keep my replies concise and remember you\'re a '
                'frontend engineer who likes dark mode.'),
      ];

      final episode = EpisodeSummary(
        id: 'ep_test',
        sessionStart: '2026-09-01T10:00:00',
        sessionEnd: '2026-09-01T11:00:00',
        summary: 'User introduced themselves and their preferences.',
      );

      final saved = await manager.extractLongTerm(
        messages: messages,
        episode: episode,
      );

      print('\n  -> extracted ${saved.length} items:');
      for (final item in saved) {
        print('    - [${item.category.name}] ${item.key}: ${item.value} '
            '(conf=${item.confidence})');
      }

      expect(saved, isNotEmpty);
      expect(saved.length, greaterThanOrEqualTo(2));

      // Should have at least one preference or fact
      final hasPreference = saved.any((m) =>
          m.category == MemoryCategory.preference ||
          m.category == MemoryCategory.fact);
      expect(hasPreference, true);

      // Check that items were saved to storage
      final allMemories = await storage.loadAllMemories();
      expect(allMemories.length, greaterThanOrEqualTo(2));

      // Should mention something about the user's profession or preferences
      final allValues = saved.map((m) => m.value.toLowerCase()).join(' ');
      expect(
        allValues.contains('engineer') ||
            allValues.contains('frontend') ||
            allValues.contains('react') ||
            allValues.contains('concise') ||
            allValues.contains('dark mode'),
        true,
        reason: 'Extracted values should relate to the conversation',
      );
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('3. buildMemoryContext produces injectable context', () async {
      // Populate memory with various items
      await manager.saveMemory(MemoryItem.now(
        key: 'fact.occupation',
        category: MemoryCategory.fact,
        value: 'frontend engineer',
        confidence: 0.9,
        source: 'user_explicit',
      ));
      await manager.saveMemory(MemoryItem.now(
        key: 'preference.reply_style',
        category: MemoryCategory.preference,
        value: 'prefers concise replies',
        confidence: 0.8,
        source: 'llm_extract',
      ));
      await manager.saveMemory(MemoryItem.now(
        key: 'skillMastery.react',
        category: MemoryCategory.skillMastery,
        value: 'proficient in React',
        confidence: 0.85,
        source: 'user_explicit',
      ));
      await manager.saveEpisode(EpisodeSummary(
        id: 'ep_recent',
        sessionStart: '2026-09-01T10:00:00',
        sessionEnd: '2026-09-01T11:00:00',
        summary: 'Discussed morning routine planning and schedule setup.',
        topics: const ['routine', 'schedule'],
      ));

      final context = manager.buildMemoryContext();

      print('\n  -> memory context:\n$context');

      expect(context, isNotEmpty);
      expect(context, contains('## User Profile'));
      expect(context, contains('frontend engineer'));
      expect(context, contains('## Preferences'));
      expect(context, contains('concise'));
      expect(context, contains('## Skills'));
      expect(context, contains('React'));
      expect(context, contains('## Recent Sessions'));
      expect(context, contains('morning routine'));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('4. ContextGovernor injects memory into system prompt', () async {
      await manager.saveMemory(MemoryItem.now(
        key: 'fact.name',
        category: MemoryCategory.fact,
        value: 'User\'s name is Alice',
        confidence: 0.95,
        source: 'user_explicit',
      ));

      final governor = ContextGovernor(
        systemPrompt: 'You are a helpful assistant.',
        memoryManager: manager,
      );

      final prompt = governor.buildSystemPrompt();

      print('\n  -> system prompt:\n$prompt');

      expect(prompt, contains('You are a helpful assistant.'));
      expect(prompt, contains('--- User Memory ---'));
      expect(prompt, contains('Alice'));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('5. Agent uses injected memory in conversation', () async {
      // Pre-populate memory with user's name
      await manager.saveMemory(MemoryItem.now(
        key: 'fact.name',
        category: MemoryCategory.fact,
        value: 'The user\'s name is Alice',
        confidence: 0.95,
        source: 'user_explicit',
      ));
      await manager.saveMemory(MemoryItem.now(
        key: 'preference.reply_style',
        category: MemoryCategory.preference,
        value: 'prefers short and direct replies',
        confidence: 0.8,
        source: 'user_explicit',
      ));

      final governor = ContextGovernor(
        systemPrompt: 'You are a personal assistant. '
            'Use the user memory to personalize your responses.',
        memoryManager: manager,
      );

      final config = AgentConfig(
        id: 'memory-agent',
        name: 'Memory Agent',
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
      await for (final event
          in core.run(userInput: 'Do you know my name? What do you know about me?')) {
        events.add(event);
      }

      final done = events.whereType<DoneEvent>().first;
      print('\n  -> reply: ${done.finalReply}');

      expect(done.finalReply, isNotEmpty);
      // The agent should use the user's name from memory
      expect(
        done.finalReply.toLowerCase().contains('alice'),
        true,
        reason: 'Agent should use the name "Alice" from injected memory',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('6. Full memory lifecycle: extract -> save -> inject -> recall',
        () async {
      // Step 1: Simulate a conversation where the user shares info
      final messages = [
        LlmMessage.user('My name is Bob and I\'m a data scientist. '
            'I prefer Python over R.'),
        LlmMessage.assistant(
            text: 'Nice to meet you, Bob! I\'ve noted that you\'re a data scientist '
                'who prefers Python.'),
      ];

      // Step 2: Extract long-term memory
      final episode = EpisodeSummary(
        id: 'ep_lifecycle',
        sessionStart: '2026-09-01T10:00:00',
        sessionEnd: '2026-09-01T11:00:00',
        summary: 'User introduced themselves as Bob, a data scientist who prefers Python.',
      );

      final extracted = await manager.extractLongTerm(
        messages: messages,
        episode: episode,
      );

      print('\n  Step 1: extracted ${extracted.length} memory items');
      for (final item in extracted) {
        print('    - [${item.category.name}] ${item.key}: ${item.value}');
      }
      expect(extracted, isNotEmpty);

      // Step 3: Build memory context
      final context = manager.buildMemoryContext();
      print('\n  Step 2: memory context:\n$context');
      expect(context, isNotEmpty);

      // Step 4: Use memory in a new conversation
      final governor = ContextGovernor(
        systemPrompt: 'You are a personal assistant. Use user memory.',
        memoryManager: manager,
      );

      final config = AgentConfig(
        id: 'lifecycle-agent',
        name: 'Lifecycle Agent',
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
        userInput: 'What programming language do I prefer?',
      )) {
        events.add(event);
      }

      final done = events.whereType<DoneEvent>().first;
      print('\n  Step 3: agent reply: ${done.finalReply}');

      expect(done.finalReply, isNotEmpty);
      // The agent should recall the user prefers Python
      expect(
        done.finalReply.toLowerCase().contains('python'),
        true,
        reason: 'Agent should recall from memory that user prefers Python',
      );
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('7. Episode summary is saved and retrievable', () async {
      final messages = [
        LlmMessage.user('I need to organize my week. I have meetings on Monday '
            'and Wednesday, and a deadline on Friday.'),
        LlmMessage.assistant(
            text: 'Let me help you organize your week. I\'ll note your meetings '
                'and the Friday deadline.'),
      ];

      final episode = await manager.summarizeEpisode(
        messages: messages,
        sessionStart: DateTime.parse('2026-09-01T14:00:00'),
        stepCount: 1,
      );

      // Save the episode
      await manager.saveEpisode(episode);

      // Retrieve it
      final retrieved = await storage.loadEpisode(episode.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.summary, episode.summary);
      expect(retrieved.topics, episode.topics);

      // Check it appears in recent episodes
      final recent = manager.getRecentEpisodes(5);
      expect(recent, isNotEmpty);
      expect(recent[0].id, episode.id);

      print('\n  -> saved episode: ${episode.id}');
      print('  -> summary: ${episode.summary}');
      print('  -> topics: ${episode.topics}');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
