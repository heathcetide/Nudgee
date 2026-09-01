import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/memory/memory_models.dart';
import 'package:nudgee/core/services/local_database_service.dart';

/// Persistent storage for agent memory items.
///
/// Uses [LocalDatabaseService] (Hive) for local persistence. Each user
/// has their own set of memory items stored in a dedicated Hive box.
///
/// Box naming convention:
/// - Semantic memory: `agent_memory_<userId>`
/// - Episodic memory: `agent_episodes_<userId>`
class MemoryStorage {
  final LocalDatabaseService _db;

  /// Creates a [MemoryStorage].
  MemoryStorage(this._db);

  /// Box name for semantic memory items.
  String _memoryBox(String userId) => 'agent_memory_$userId';

  /// Box name for episodic memory (session summaries).
  String _episodeBox(String userId) => 'agent_episodes_$userId';

  // ── Semantic memory (MemoryItem) ──────────────────────────────────────

  /// Saves a [MemoryItem] to local storage.
  Future<void> saveMemory(MemoryItem item) async {
    try {
      final box = _memoryBox(item.userId);
      await _db.put(box, item.key, jsonEncode(item.toJson()));
    } catch (e) {
      debugPrint('[MemoryStorage] saveMemory error: $e');
      rethrow;
    }
  }

  /// Loads a [MemoryItem] by key.
  Future<MemoryItem?> loadMemory(String key, {String userId = 'default'}) async {
    try {
      final box = _memoryBox(userId);
      final raw = await _db.get<String>(box, key);
      if (raw == null) return null;
      return MemoryItem.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[MemoryStorage] loadMemory error: $e');
      return null;
    }
  }

  /// Loads all memory items for a user.
  Future<List<MemoryItem>> loadAllMemories({String userId = 'default'}) async {
    try {
      final box = _memoryBox(userId);
      final keys = await _db.getKeys(box);
      final items = <MemoryItem>[];
      for (final key in keys) {
        final raw = await _db.get<String>(box, key);
        if (raw != null) {
          items.add(MemoryItem.fromJson(jsonDecode(raw) as Map<String, dynamic>));
        }
      }
      return items;
    } catch (e) {
      debugPrint('[MemoryStorage] loadAllMemories error: $e');
      return [];
    }
  }

  /// Loads memory items by category.
  Future<List<MemoryItem>> loadMemoriesByCategory(
    MemoryCategory category, {
    String userId = 'default',
  }) async {
    final all = await loadAllMemories(userId: userId);
    return all.where((m) => m.category == category).toList();
  }

  /// Deletes a memory item.
  Future<void> deleteMemory(String key, {String userId = 'default'}) async {
    try {
      await _db.delete(_memoryBox(userId), key);
    } catch (e) {
      debugPrint('[MemoryStorage] deleteMemory error: $e');
    }
  }

  /// Clears all memory items for a user.
  Future<void> clearAllMemories({String userId = 'default'}) async {
    try {
      await _db.clear(_memoryBox(userId));
    } catch (e) {
      debugPrint('[MemoryStorage] clearAllMemories error: $e');
    }
  }

  // ── Episodic memory (EpisodeSummary) ──────────────────────────────────

  /// Saves an [EpisodeSummary].
  Future<void> saveEpisode(EpisodeSummary episode) async {
    try {
      final box = _episodeBox(episode.userId);
      await _db.put(box, episode.id, jsonEncode(episode.toJson()));
    } catch (e) {
      debugPrint('[MemoryStorage] saveEpisode error: $e');
      rethrow;
    }
  }

  /// Loads an episode by ID.
  Future<EpisodeSummary?> loadEpisode(String id, {String userId = 'default'}) async {
    try {
      final box = _episodeBox(userId);
      final raw = await _db.get<String>(box, id);
      if (raw == null) return null;
      return EpisodeSummary.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[MemoryStorage] loadEpisode error: $e');
      return null;
    }
  }

  /// Loads all episodes for a user, sorted by session start (newest first).
  Future<List<EpisodeSummary>> loadAllEpisodes({String userId = 'default'}) async {
    try {
      final box = _episodeBox(userId);
      final keys = await _db.getKeys(box);
      final episodes = <EpisodeSummary>[];
      for (final key in keys) {
        final raw = await _db.get<String>(box, key);
        if (raw != null) {
          episodes
              .add(EpisodeSummary.fromJson(jsonDecode(raw) as Map<String, dynamic>));
        }
      }
      episodes.sort((a, b) => b.sessionStart.compareTo(a.sessionStart));
      return episodes;
    } catch (e) {
      debugPrint('[MemoryStorage] loadAllEpisodes error: $e');
      return [];
    }
  }

  /// Loads recent N episodes.
  Future<List<EpisodeSummary>> loadRecentEpisodes(
    int limit, {
    String userId = 'default',
  }) async {
    final all = await loadAllEpisodes(userId: userId);
    return all.take(limit).toList();
  }

  /// Deletes an episode.
  Future<void> deleteEpisode(String id, {String userId = 'default'}) async {
    try {
      await _db.delete(_episodeBox(userId), id);
    } catch (e) {
      debugPrint('[MemoryStorage] deleteEpisode error: $e');
    }
  }

  // ── Export / Import (for cloud sync) ──────────────────────────────────

  /// Exports all memory items as a JSON-serializable map.
  ///
  /// Used by [AgentSyncManager] to upload to Qiniu cloud.
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

  /// Imports memory data from a JSON map (from cloud sync).
  ///
  /// Uses [MemoryMerger] to resolve conflicts with existing local data.
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
        // Episodes: keep the one with higher version
        if (existing == null || incoming.version > existing.version) {
          await saveEpisode(incoming);
          imported++;
        }
      }
    }

    return imported;
  }
}

/// Conflict resolution strategies for merging memory items.
///
/// Different [MemoryCategory] types use different merge strategies:
/// - [MemoryCategory.preference]: last-write-wins by updatedAt
/// - [MemoryCategory.fact]: most specific (longer value) wins
/// - [MemoryCategory.skillMastery]: highest confidence wins
/// - [MemoryCategory.context]: last-write-wins by updatedAt
class MemoryMerger {
  /// Merges an incoming item with an existing local item.
  ///
  /// Returns the merged result, or null if neither should be kept.
  /// If [incoming] is null, returns [existing]. If [existing] is null,
  /// returns [incoming].
  static MemoryItem? merge(MemoryItem? incoming, MemoryItem? existing) {
    if (incoming == null && existing == null) return null;
    if (incoming == null) return existing;
    if (existing == null) return incoming;

    // Same item — resolve by category-specific strategy
    switch (incoming.category) {
      case MemoryCategory.preference:
      case MemoryCategory.context:
        return _lastWriteWins(incoming, existing);
      case MemoryCategory.fact:
        return _mostSpecificWins(incoming, existing);
      case MemoryCategory.skillMastery:
        return _highestConfidenceWins(incoming, existing);
    }
  }

  /// Last-write-wins: compare by updatedAt timestamp.
  static MemoryItem _lastWriteWins(MemoryItem incoming, MemoryItem existing) {
    // If versions differ, higher version wins
    if (incoming.version != existing.version) {
      return incoming.version > existing.version ? incoming : existing;
    }
    // Same version: compare by updatedAt
    return incoming.updatedAt.compareTo(existing.updatedAt) >= 0
        ? incoming
        : existing;
  }

  /// Most specific wins: longer value preferred, tie-break by version.
  static MemoryItem _mostSpecificWins(MemoryItem incoming, MemoryItem existing) {
    if (incoming.value.length != existing.value.length) {
      return incoming.value.length > existing.value.length ? incoming : existing;
    }
    return _lastWriteWins(incoming, existing);
  }

  /// Highest confidence wins, tie-break by version.
  static MemoryItem _highestConfidenceWins(MemoryItem incoming, MemoryItem existing) {
    if (incoming.confidence != existing.confidence) {
      return incoming.confidence > existing.confidence ? incoming : existing;
    }
    return _lastWriteWins(incoming, existing);
  }
}
