import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/memory/memory_models.dart';
import 'package:nudgee/core/agent/memory/memory_storage.dart';

/// In-memory mock of [MemoryStorage] for testing.
///
/// Uses plain Maps instead of Hive. Safe to use in unit tests and
/// integration tests without platform initialization.
class MockMemoryStorage implements MemoryStorage {
  final Map<String, MemoryItem> _memories = {};
  final Map<String, EpisodeSummary> _episodes = {};

  @override
  Future<void> saveMemory(MemoryItem item) async {
    _memories['${item.userId}:${item.key}'] = item;
  }

  @override
  Future<MemoryItem?> loadMemory(String key, {String userId = 'default'}) async {
    return _memories['$userId:$key'];
  }

  @override
  Future<List<MemoryItem>> loadAllMemories({String userId = 'default'}) async {
    return _memories.values.where((m) => m.userId == userId).toList();
  }

  @override
  Future<List<MemoryItem>> loadMemoriesByCategory(
    MemoryCategory category, {
    String userId = 'default',
  }) async {
    return _memories.values
        .where((m) => m.userId == userId && m.category == category)
        .toList();
  }

  @override
  Future<void> deleteMemory(String key, {String userId = 'default'}) async {
    _memories.remove('$userId:$key');
  }

  @override
  Future<void> clearAllMemories({String userId = 'default'}) async {
    _memories.removeWhere((k, _) => k.startsWith('$userId:'));
  }

  @override
  Future<void> saveEpisode(EpisodeSummary episode) async {
    _episodes['${episode.userId}:${episode.id}'] = episode;
  }

  @override
  Future<EpisodeSummary?> loadEpisode(String id,
      {String userId = 'default'}) async {
    return _episodes['$userId:$id'];
  }

  @override
  Future<List<EpisodeSummary>> loadAllEpisodes(
      {String userId = 'default'}) async {
    final list = _episodes.values.where((e) => e.userId == userId).toList();
    list.sort((a, b) => b.sessionStart.compareTo(a.sessionStart));
    return list;
  }

  @override
  Future<List<EpisodeSummary>> loadRecentEpisodes(
    int limit, {
    String userId = 'default',
  }) async {
    final all = await loadAllEpisodes(userId: userId);
    return all.take(limit).toList();
  }

  @override
  Future<void> deleteEpisode(String id, {String userId = 'default'}) async {
    _episodes.remove('$userId:$id');
  }

  @override
  Future<Map<String, dynamic>> exportAll({String userId = 'default'}) async {
    final memories = await loadAllMemories(userId: userId);
    final episodes = await loadAllEpisodes(userId: userId);
    return {
      'userId': userId,
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'memories': memories.map((m) => m.toJson()).toList(),
      'episodes': episodes.map((e) => e.toJson()).toList(),
    };
  }

  @override
  Future<int> importAll(
    Map<String, dynamic> data, {
    String userId = 'default',
  }) async {
    var imported = 0;
    final memoriesRaw = data['memories'] as List?;
    if (memoriesRaw != null) {
      for (final raw in memoriesRaw) {
        final incoming = MemoryItem.fromJson(raw as Map<String, dynamic>);
        final existing = await loadMemory(incoming.key, userId: userId);
        final merged = MemoryMerger.merge(incoming, existing);
        if (merged != null) {
          await saveMemory(merged);
          imported++;
        }
      }
    }
    final episodesRaw = data['episodes'] as List?;
    if (episodesRaw != null) {
      for (final raw in episodesRaw) {
        final incoming = EpisodeSummary.fromJson(raw as Map<String, dynamic>);
        final existing = await loadEpisode(incoming.id, userId: userId);
        if (existing == null || incoming.version > existing.version) {
          await saveEpisode(incoming);
          imported++;
        }
      }
    }
    return imported;
  }
}
