import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/memory/memory_models.dart';

void main() {
  group('MemoryItem', () {
    test('now() creates item with current timestamp', () {
      final item = MemoryItem.now(
        key: 'preference.reply_style',
        category: MemoryCategory.preference,
        value: 'concise',
      );

      expect(item.key, 'preference.reply_style');
      expect(item.category, MemoryCategory.preference);
      expect(item.value, 'concise');
      expect(item.confidence, 0.5);
      expect(item.source, 'inferred');
      expect(item.version, 1);
      expect(item.userId, 'default');
      expect(item.createdAt, isNotEmpty);
      expect(item.updatedAt, isNotEmpty);
      expect(item.createdAt, item.updatedAt);
    });

    test('toJson / fromJson round trip', () {
      final original = MemoryItem(
        key: 'fact.occupation',
        category: MemoryCategory.fact,
        value: 'frontend engineer',
        confidence: 0.9,
        source: 'user_explicit',
        version: 3,
        createdAt: '2026-09-01T10:00:00',
        updatedAt: '2026-09-01T12:00:00',
        userId: 'user123',
      );

      final json = original.toJson();
      expect(json['key'], 'fact.occupation');
      expect(json['category'], 'fact');
      expect(json['confidence'], 0.9);
      expect(json['version'], 3);
      expect(json['userId'], 'user123');

      final restored = MemoryItem.fromJson(json);
      expect(restored.key, original.key);
      expect(restored.category, original.category);
      expect(restored.value, original.value);
      expect(restored.confidence, original.confidence);
      expect(restored.source, original.source);
      expect(restored.version, original.version);
      expect(restored.userId, original.userId);
    });

    test('copyWith updates only specified fields', () {
      final original = MemoryItem.now(
        key: 'test.key',
        category: MemoryCategory.context,
        value: 'old value',
      );

      final updated = original.copyWith(
        value: 'new value',
        version: 2,
      );

      expect(updated.key, 'test.key');
      expect(updated.value, 'new value');
      expect(updated.version, 2);
      expect(updated.category, original.category);
      expect(updated.confidence, original.confidence);
    });

    test('equality by key and userId', () {
      final a = MemoryItem.now(
        key: 'same.key',
        category: MemoryCategory.fact,
        value: 'a',
        userId: 'user1',
      );
      final b = MemoryItem.now(
        key: 'same.key',
        category: MemoryCategory.fact,
        value: 'b',
        userId: 'user1',
      );
      final c = MemoryItem.now(
        key: 'same.key',
        category: MemoryCategory.fact,
        value: 'c',
        userId: 'user2',
      );

      expect(a == b, true);
      expect(a == c, false);
      expect(a.hashCode, b.hashCode);
    });

    test('category name serialization', () {
      expect(MemoryCategory.preference.name, 'preference');
      expect(MemoryCategory.fact.name, 'fact');
      expect(MemoryCategory.skillMastery.name, 'skillMastery');
      expect(MemoryCategory.context.name, 'context');
    });
  });

  group('EpisodeSummary', () {
    test('toJson / fromJson round trip', () {
      final original = EpisodeSummary(
        id: 'episode_123',
        userId: 'user1',
        sessionStart: '2026-09-01T10:00:00',
        sessionEnd: '2026-09-01T11:00:00',
        summary: 'Discussed morning routine planning',
        topics: const ['routine', 'planning', 'health'],
        toolsUsed: const ['schedule.add', 'todo.write'],
        messageCount: 15,
        stepCount: 5,
        version: 2,
      );

      final json = original.toJson();
      expect(json['id'], 'episode_123');
      expect(json['topics'], isA<List>());
      expect((json['topics'] as List).length, 3);

      final restored = EpisodeSummary.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.summary, original.summary);
      expect(restored.topics, original.topics);
      expect(restored.toolsUsed, original.toolsUsed);
      expect(restored.messageCount, original.messageCount);
      expect(restored.stepCount, original.stepCount);
    });

    test('fromJson handles missing fields gracefully', () {
      final restored = EpisodeSummary.fromJson({});
      expect(restored.id, '');
      expect(restored.userId, 'default');
      expect(restored.topics, isEmpty);
      expect(restored.toolsUsed, isEmpty);
      expect(restored.messageCount, 0);
    });
  });
}
