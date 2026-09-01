import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/memory/memory_models.dart';
import 'package:nudgee/core/agent/memory/memory_storage.dart';

void main() {
  group('MemoryMerger', () {
    MemoryItem makeItem({
      required String key,
      MemoryCategory category = MemoryCategory.context,
      String value = 'value',
      double confidence = 0.5,
      int version = 1,
      String updatedAt = '2026-09-01T10:00:00',
    }) {
      return MemoryItem(
        key: key,
        category: category,
        value: value,
        confidence: confidence,
        version: version,
        createdAt: '2026-09-01T09:00:00',
        updatedAt: updatedAt,
      );
    }

    test('returns incoming if existing is null', () {
      final incoming = makeItem(key: 'test');
      final result = MemoryMerger.merge(incoming, null);
      expect(result, incoming);
    });

    test('returns existing if incoming is null', () {
      final existing = makeItem(key: 'test');
      final result = MemoryMerger.merge(null, existing);
      expect(result, existing);
    });

    test('returns null if both are null', () {
      final result = MemoryMerger.merge(null, null);
      expect(result, null);
    });

    test('preference: last-write-wins by updatedAt', () {
      final older = makeItem(
        key: 'pref',
        category: MemoryCategory.preference,
        value: 'old',
        updatedAt: '2026-09-01T10:00:00',
      );
      final newer = makeItem(
        key: 'pref',
        category: MemoryCategory.preference,
        value: 'new',
        updatedAt: '2026-09-01T12:00:00',
      );

      expect(MemoryMerger.merge(newer, older)?.value, 'new');
      expect(MemoryMerger.merge(older, newer)?.value, 'new');
    });

    test('preference: higher version wins regardless of timestamp', () {
      final v1 = makeItem(
        key: 'pref',
        category: MemoryCategory.preference,
        value: 'v1',
        version: 1,
        updatedAt: '2026-09-01T12:00:00',
      );
      final v2 = makeItem(
        key: 'pref',
        category: MemoryCategory.preference,
        value: 'v2',
        version: 2,
        updatedAt: '2026-09-01T10:00:00',
      );

      expect(MemoryMerger.merge(v1, v2)?.value, 'v2');
      expect(MemoryMerger.merge(v2, v1)?.value, 'v2');
    });

    test('fact: longer value wins', () {
      final short = makeItem(
        key: 'fact',
        category: MemoryCategory.fact,
        value: 'engineer',
      );
      final long = makeItem(
        key: 'fact',
        category: MemoryCategory.fact,
        value: 'senior frontend engineer at a tech company',
      );

      expect(MemoryMerger.merge(short, long)?.value, long.value);
      expect(MemoryMerger.merge(long, short)?.value, long.value);
    });

    test('fact: same length falls back to version', () {
      final v1 = makeItem(
        key: 'fact',
        category: MemoryCategory.fact,
        value: 'engineer',
        version: 1,
      );
      final v2 = makeItem(
        key: 'fact',
        category: MemoryCategory.fact,
        value: 'developer',
        version: 2,
      );

      expect(MemoryMerger.merge(v1, v2)?.value, 'developer');
    });

    test('skillMastery: higher confidence wins', () {
      final low = makeItem(
        key: 'skill',
        category: MemoryCategory.skillMastery,
        value: 'beginner',
        confidence: 0.3,
      );
      final high = makeItem(
        key: 'skill',
        category: MemoryCategory.skillMastery,
        value: 'expert',
        confidence: 0.9,
      );

      expect(MemoryMerger.merge(low, high)?.value, 'expert');
      expect(MemoryMerger.merge(high, low)?.value, 'expert');
    });

    test('skillMastery: same confidence falls back to version', () {
      final v1 = makeItem(
        key: 'skill',
        category: MemoryCategory.skillMastery,
        value: 'beginner',
        confidence: 0.5,
        version: 1,
      );
      final v2 = makeItem(
        key: 'skill',
        category: MemoryCategory.skillMastery,
        value: 'intermediate',
        confidence: 0.5,
        version: 2,
      );

      expect(MemoryMerger.merge(v1, v2)?.value, 'intermediate');
    });

    test('context: last-write-wins', () {
      final older = makeItem(
        key: 'ctx',
        category: MemoryCategory.context,
        value: 'planning trip',
        updatedAt: '2026-09-01T10:00:00',
      );
      final newer = makeItem(
        key: 'ctx',
        category: MemoryCategory.context,
        value: 'trip booked',
        updatedAt: '2026-09-01T14:00:00',
      );

      expect(MemoryMerger.merge(older, newer)?.value, 'trip booked');
    });
  });
}
