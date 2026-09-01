import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/memory/memory_models.dart';
import 'package:nudgee/core/agent/memory/memory_manager.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';

import '../providers/mock_llm_client.dart';
import 'mock_memory_storage.dart';

void main() {
  group('MemoryManager', () {
    late MockMemoryStorage storage;
    late MockLLMClient llm;
    late MemoryManager manager;

    setUp(() {
      storage = MockMemoryStorage();
      llm = MockLLMClient();
      manager = MemoryManager(
        storage: storage,
        llmClient: llm,
        llmModel: 'mock-model',
      );
    });

    test('loadCache loads from storage', () async {
      await storage.saveMemory(MemoryItem.now(
        key: 'fact.job',
        category: MemoryCategory.fact,
        value: 'engineer',
      ));
      await storage.saveMemory(MemoryItem.now(
        key: 'pref.style',
        category: MemoryCategory.preference,
        value: 'concise',
      ));

      await manager.loadCache();

      expect(manager.isCacheLoaded, true);
      expect(manager.longTerm, hasLength(2));
    });

    test('saveMemory updates cache and storage', () async {
      await manager.loadCache();
      expect(manager.longTerm, isEmpty);

      await manager.saveMemory(MemoryItem.now(
        key: 'test.key',
        category: MemoryCategory.context,
        value: 'test value',
      ));

      expect(manager.longTerm, hasLength(1));
      expect(manager.getMemory('test.key')?.value, 'test value');
      final stored = await storage.loadMemory('test.key');
      expect(stored?.value, 'test value');
    });

    test('saveMemory replaces existing key in cache', () async {
      await manager.saveMemory(MemoryItem.now(
        key: 'test.key',
        category: MemoryCategory.context,
        value: 'old',
      ));
      await manager.saveMemory(MemoryItem.now(
        key: 'test.key',
        category: MemoryCategory.context,
        value: 'new',
      ));

      expect(manager.longTerm, hasLength(1));
      expect(manager.getMemory('test.key')?.value, 'new');
    });

    test('deleteMemory removes from cache and storage', () async {
      await manager.saveMemory(MemoryItem.now(
        key: 'test.key',
        category: MemoryCategory.context,
        value: 'test',
      ));
      expect(manager.longTerm, hasLength(1));

      await manager.deleteMemory('test.key');

      expect(manager.longTerm, isEmpty);
      expect(await storage.loadMemory('test.key'), null);
    });

    test('getByCategory filters correctly', () async {
      await manager.saveMemory(MemoryItem.now(
        key: 'fact.job',
        category: MemoryCategory.fact,
        value: 'engineer',
      ));
      await manager.saveMemory(MemoryItem.now(
        key: 'pref.style',
        category: MemoryCategory.preference,
        value: 'concise',
      ));
      await manager.saveMemory(MemoryItem.now(
        key: 'fact.location',
        category: MemoryCategory.fact,
        value: 'Shanghai',
      ));

      expect(manager.getByCategory(MemoryCategory.fact), hasLength(2));
      expect(manager.getByCategory(MemoryCategory.preference), hasLength(1));
      expect(manager.getByCategory(MemoryCategory.skillMastery), isEmpty);
    });

    test('saveEpisode updates cache', () async {
      final episode = EpisodeSummary(
        id: 'ep1',
        sessionStart: '2026-09-01T10:00:00',
        sessionEnd: '2026-09-01T11:00:00',
        summary: 'Test session',
      );

      await manager.saveEpisode(episode);

      expect(manager.episodes, hasLength(1));
      expect(manager.getRecentEpisodes(1)[0].id, 'ep1');
    });

    test('summarizeEpisode calls LLM and parses JSON', () async {
      llm.enqueueContent(
        '{"summary": "User discussed morning routine planning", '
        '"topics": ["routine", "planning", "health"]}',
      );

      final messages = [
        LlmMessage.user('Help me plan my morning routine'),
        LlmMessage.assistant(text: 'Sure! Let\'s create a morning routine for you.'),
        LlmMessage.user('I want to exercise at 7am'),
      ];

      final episode = await manager.summarizeEpisode(
        messages: messages,
        sessionStart: DateTime.parse('2026-09-01T10:00:00'),
        stepCount: 3,
        toolsUsed: const ['todo.write'],
      );

      expect(episode.summary, 'User discussed morning routine planning');
      expect(episode.topics, hasLength(3));
      expect(episode.topics, contains('routine'));
      expect(episode.messageCount, 3);
      expect(episode.stepCount, 3);
      expect(episode.toolsUsed, ['todo.write']);
    });

    test('summarizeEpisode handles empty messages', () async {
      final episode = await manager.summarizeEpisode(
        messages: [],
        sessionStart: DateTime.parse('2026-09-01T10:00:00'),
        stepCount: 0,
      );

      expect(episode.summary, 'Empty session.');
      expect(episode.messageCount, 0);
    });

    test('summarizeEpisode falls back on LLM error', () async {
      llm.enqueueError('LLM unavailable');

      final messages = [
        LlmMessage.user('Help me plan my day'),
        LlmMessage.assistant(text: 'Sure! What do you need?'),
      ];

      final episode = await manager.summarizeEpisode(
        messages: messages,
        sessionStart: DateTime.parse('2026-09-01T10:00:00'),
        stepCount: 1,
      );

      expect(episode.summary, isNotEmpty);
      expect(episode.messageCount, 2);
    });

    test('extractLongTerm parses and saves memory items', () async {
      llm.enqueueContent(
        '[{"key": "preference.reply_style", "category": "preference", '
        '"value": "prefers concise replies", "confidence": 0.8}, '
        '{"key": "fact.occupation", "category": "fact", '
        '"value": "frontend engineer", "confidence": 0.9}]',
      );

      final messages = [
        LlmMessage.user('I\'m a frontend engineer and I like short answers'),
        LlmMessage.assistant(text: 'Got it! I\'ll keep my replies concise.'),
      ];

      final episode = EpisodeSummary(
        id: 'ep1',
        sessionStart: '2026-09-01T10:00:00',
        sessionEnd: '2026-09-01T11:00:00',
        summary: 'User stated preferences',
      );

      final saved = await manager.extractLongTerm(
        messages: messages,
        episode: episode,
      );

      expect(saved, hasLength(2));
      expect(manager.getMemory('preference.reply_style')?.value,
          'prefers concise replies');
      expect(manager.getMemory('fact.occupation')?.value, 'frontend engineer');
      expect(manager.getMemory('fact.occupation')?.source, 'llm_extract');
    });

    test('extractLongTerm bumps version on update', () async {
      // Pre-populate with v1
      await manager.saveMemory(MemoryItem.now(
        key: 'preference.reply_style',
        category: MemoryCategory.preference,
        value: 'old preference',
        version: 1,
      ));

      llm.enqueueContent(
        '[{"key": "preference.reply_style", "category": "preference", '
        '"value": "new preference", "confidence": 0.9}]',
      );

      final episode = EpisodeSummary(
        id: 'ep1',
        sessionStart: '2026-09-01T10:00:00',
        sessionEnd: '2026-09-01T11:00:00',
        summary: 'Updated preferences',
      );

      final saved = await manager.extractLongTerm(
        messages: [LlmMessage.user('I now prefer detailed answers')],
        episode: episode,
      );

      expect(saved, hasLength(1));
      expect(saved[0].version, 2);
      expect(saved[0].value, 'new preference');
    });

    test('extractLongTerm handles empty messages', () async {
      final episode = EpisodeSummary(
        id: 'ep1',
        sessionStart: '2026-09-01T10:00:00',
        sessionEnd: '2026-09-01T11:00:00',
        summary: 'Empty',
      );

      final saved = await manager.extractLongTerm(
        messages: [],
        episode: episode,
      );

      expect(saved, isEmpty);
    });

    test('extractLongTerm handles LLM error gracefully', () async {
      llm.enqueueError('LLM unavailable');

      final episode = EpisodeSummary(
        id: 'ep1',
        sessionStart: '2026-09-01T10:00:00',
        sessionEnd: '2026-09-01T11:00:00',
        summary: 'Test',
      );

      final saved = await manager.extractLongTerm(
        messages: [LlmMessage.user('test')],
        episode: episode,
      );

      expect(saved, isEmpty);
    });

    test('buildMemoryContext returns empty when no memory', () async {
      await manager.loadCache();
      expect(manager.buildMemoryContext(), isEmpty);
    });

    test('buildMemoryContext formats all categories', () async {
      await manager.saveMemory(MemoryItem.now(
        key: 'fact.occupation',
        category: MemoryCategory.fact,
        value: 'frontend engineer',
      ));
      await manager.saveMemory(MemoryItem.now(
        key: 'preference.reply_style',
        category: MemoryCategory.preference,
        value: 'concise',
      ));
      await manager.saveMemory(MemoryItem.now(
        key: 'skillMastery.react',
        category: MemoryCategory.skillMastery,
        value: 'proficient',
      ));
      await manager.saveMemory(MemoryItem.now(
        key: 'context.current_project',
        category: MemoryCategory.context,
        value: 'planning a trip to Japan',
      ));
      await manager.saveEpisode(EpisodeSummary(
        id: 'ep1',
        sessionStart: '2026-09-01T10:00:00',
        sessionEnd: '2026-09-01T11:00:00',
        summary: 'Discussed morning routine',
      ));

      final context = manager.buildMemoryContext();

      expect(context, contains('## User Profile'));
      expect(context, contains('Occupation: frontend engineer'));
      expect(context, contains('## Preferences'));
      expect(context, contains('Reply style: concise'));
      expect(context, contains('## Skills'));
      expect(context, contains('React: proficient'));
      expect(context, contains('## Current Context'));
      expect(context, contains('planning a trip to Japan'));
      expect(context, contains('## Recent Sessions'));
      expect(context, contains('Discussed morning routine'));
    });

    test('buildMemoryContext respects maxItems and maxEpisodes', () async {
      for (var i = 0; i < 10; i++) {
        await manager.saveMemory(MemoryItem.now(
          key: 'context.item_$i',
          category: MemoryCategory.context,
          value: 'context $i',
        ));
      }
      for (var i = 0; i < 5; i++) {
        await manager.saveEpisode(EpisodeSummary(
          id: 'ep_$i',
          sessionStart: '2026-09-0${i + 1}T10:00:00',
          sessionEnd: '2026-09-0${i + 1}T11:00:00',
          summary: 'Episode $i',
        ));
      }

      final context = manager.buildMemoryContext(maxItems: 3, maxEpisodes: 2);

      // Should only have 3 context items
      final contextLines =
          context.split('\n').where((l) => l.startsWith('- context')).length;
      expect(contextLines, lessThanOrEqualTo(3));

      // Should only have 2 recent sessions
      final episodeLines =
          context.split('\n').where((l) => l.startsWith('- 2026')).length;
      expect(episodeLines, 2);
    });
  });
}
