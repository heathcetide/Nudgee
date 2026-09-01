import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/memory/memory_models.dart';
import 'package:nudgee/core/agent/memory/memory_storage.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';

/// Manages the three-layer memory system for an agent.
///
/// Layer 1 — Working memory: current session messages (managed by
///   ContextGovernor, not here).
/// Layer 2 — Episodic memory: session summaries, generated at session
///   end via [summarizeEpisode].
/// Layer 3 — Semantic memory: long-term user preferences, facts, and
///   skill mastery, extracted via [extractLongTerm].
///
/// The manager also builds a memory context string that can be injected
/// into the system prompt via [buildMemoryContext].
class MemoryManager {
  final MemoryStorage storage;
  final LLMClient llmClient;

  /// Model to use for summarization and extraction.
  final String llmModel;

  /// Current user ID.
  String userId;

  /// In-memory cache of semantic memory items.
  List<MemoryItem> _memoryCache = const [];

  /// In-memory cache of recent episodes.
  List<EpisodeSummary> _episodeCache = const [];

  /// Whether the cache has been loaded.
  bool _cacheLoaded = false;

  /// Creates a [MemoryManager].
  MemoryManager({
    required this.storage,
    required this.llmClient,
    this.llmModel = 'gpt-5.4-mini',
    this.userId = 'default',
  });

  // ── Cache management ──────────────────────────────────────────────────

  /// Loads memory and episodes from storage into cache.
  /// Call once at startup (or when user changes).
  Future<void> loadCache() async {
    _memoryCache = await storage.loadAllMemories(userId: userId);
    _episodeCache = await storage.loadAllEpisodes(userId: userId);
    _cacheLoaded = true;
    debugPrint('[MemoryManager] cache loaded: '
        '${_memoryCache.length} memories, ${_episodeCache.length} episodes');
  }

  /// Whether the cache has been loaded.
  bool get isCacheLoaded => _cacheLoaded;

  /// Gets all semantic memory items (from cache).
  List<MemoryItem> get longTerm =>
      _cacheLoaded ? _memoryCache : const [];

  /// Gets recent episode summaries (from cache).
  List<EpisodeSummary> get episodes =>
      _cacheLoaded ? _episodeCache : const [];

  // ── Semantic memory CRUD ──────────────────────────────────────────────

  /// Saves a memory item (updates cache + storage).
  Future<void> saveMemory(MemoryItem item) async {
    await storage.saveMemory(item);
    // Mark cache as loaded (we're populating it directly)
    _cacheLoaded = true;
    // Update cache
    final idx = _memoryCache.indexWhere((m) => m.key == item.key);
    if (idx >= 0) {
      _memoryCache = List.from(_memoryCache)..[idx] = item;
    } else {
      _memoryCache = [..._memoryCache, item];
    }
  }

  /// Retrieves a memory item by key (from cache).
  MemoryItem? getMemory(String key) {
    return _memoryCache.where((m) => m.key == key).firstOrNull;
  }

  /// Deletes a memory item.
  Future<void> deleteMemory(String key) async {
    await storage.deleteMemory(key, userId: userId);
    _memoryCache = _memoryCache.where((m) => m.key != key).toList();
  }

  /// Gets memories by category.
  List<MemoryItem> getByCategory(MemoryCategory category) {
    return _memoryCache.where((m) => m.category == category).toList();
  }

  // ── Episodic memory ───────────────────────────────────────────────────

  /// Saves an episode summary.
  Future<void> saveEpisode(EpisodeSummary episode) async {
    await storage.saveEpisode(episode);
    _cacheLoaded = true;
    // Update cache (keep sorted newest first)
    _episodeCache = [..._episodeCache, episode]
      ..sort((a, b) => b.sessionStart.compareTo(a.sessionStart));
  }

  /// Gets the N most recent episodes.
  List<EpisodeSummary> getRecentEpisodes(int limit) {
    return _episodeCache.take(limit).toList();
  }

  // ── LLM-powered operations ────────────────────────────────────────────

  /// Summarizes a conversation session into an [EpisodeSummary].
  ///
  /// Calls the LLM to generate a concise summary of the conversation,
  /// extract key topics, and list tools used.
  Future<EpisodeSummary> summarizeEpisode({
    required List<LlmMessage> messages,
    required DateTime sessionStart,
    required int stepCount,
    List<String> toolsUsed = const [],
  }) async {
    final sessionEnd = DateTime.now();

    if (messages.isEmpty) {
      return EpisodeSummary(
        id: 'episode_${sessionStart.millisecondsSinceEpoch}',
        userId: userId,
        sessionStart: sessionStart.toIso8601String(),
        sessionEnd: sessionEnd.toIso8601String(),
        summary: 'Empty session.',
        messageCount: 0,
        stepCount: stepCount,
        toolsUsed: toolsUsed,
      );
    }

    // Build a compact transcript for the LLM
    final transcript = _buildTranscript(messages);

    final systemPrompt = 'You are a conversation summarizer. '
        'Summarize the following conversation in 2-3 sentences. '
        'Also extract 1-5 key topics as a JSON array of strings. '
        'Respond in JSON format: '
        '{"summary": "...", "topics": ["topic1", "topic2"]}';

    final userPrompt = 'Conversation transcript:\n$transcript\n\n'
        'Generate a JSON summary with "summary" and "topics" fields.';

    try {
      final response = await llmClient.chat(
        messages: [LlmMessage.user(userPrompt)],
        model: llmModel,
        temperature: 0.3,
        maxTokens: 500,
        systemPrompt: systemPrompt,
      );

      final (summary, topics) = _parseSummaryResponse(response.content);

      return EpisodeSummary(
        id: 'episode_${sessionStart.millisecondsSinceEpoch}',
        userId: userId,
        sessionStart: sessionStart.toIso8601String(),
        sessionEnd: sessionEnd.toIso8601String(),
        summary: summary,
        topics: topics,
        messageCount: messages.length,
        stepCount: stepCount,
        toolsUsed: toolsUsed,
      );
    } catch (e) {
      debugPrint('[MemoryManager] summarizeEpisode error: $e');
      // Fallback: simple truncation
      final fallbackSummary = _buildFallbackSummary(messages);
      return EpisodeSummary(
        id: 'episode_${sessionStart.millisecondsSinceEpoch}',
        userId: userId,
        sessionStart: sessionStart.toIso8601String(),
        sessionEnd: sessionEnd.toIso8601String(),
        summary: fallbackSummary,
        messageCount: messages.length,
        stepCount: stepCount,
        toolsUsed: toolsUsed,
      );
    }
  }

  /// Extracts long-term memory items from a conversation.
  ///
  /// Calls the LLM to identify user preferences, facts, and skill
  /// mastery from the conversation. Returns a list of [MemoryItem]s
  /// that were saved.
  Future<List<MemoryItem>> extractLongTerm({
    required List<LlmMessage> messages,
    required EpisodeSummary episode,
  }) async {
    if (messages.isEmpty) return [];

    final transcript = _buildTranscript(messages);

    final systemPrompt = 'You are a memory extractor. Analyze the conversation '
        'and extract long-term facts about the user. Focus on:\n'
        '- Preferences (e.g. "prefers concise replies", "likes morning routines")\n'
        '- Facts (e.g. "is a frontend engineer", "lives in Shanghai")\n'
        '- Skill mastery (e.g. "proficient in React", "beginner in Python")\n\n'
        'Only extract things that are clearly stated or strongly implied. '
        'Do not guess. Respond as a JSON array:\n'
        '[{"key": "preference.reply_style", "category": "preference", '
        '"value": "prefers concise replies", "confidence": 0.8}]\n\n'
        'Categories: "preference", "fact", "skillMastery", "context". '
        'Keys should use dot notation: category.specific_name.';

    final userPrompt = 'Conversation summary: ${episode.summary}\n\n'
        'Conversation transcript:\n$transcript\n\n'
        'Extract long-term memory items as a JSON array.';

    try {
      final response = await llmClient.chat(
        messages: [LlmMessage.user(userPrompt)],
        model: llmModel,
        temperature: 0.2,
        maxTokens: 800,
        systemPrompt: systemPrompt,
      );

      final extracted = _parseExtractionResponse(response.content);

      // Save each extracted item
      final saved = <MemoryItem>[];
      for (final item in extracted) {
        // Check if we already have this key
        final existing = getMemory(item.key);
        final merged = MemoryMerger.merge(item, existing);
        if (merged != null) {
          // Bump version if updating
          final toSave = existing != null
              ? merged.copyWith(
                  version: existing.version + 1,
                  updatedAt: DateTime.now().toIso8601String(),
                )
              : merged;
          await saveMemory(toSave);
          saved.add(toSave);
        }
      }

      debugPrint('[MemoryManager] extracted ${saved.length} memory items');
      return saved;
    } catch (e) {
      debugPrint('[MemoryManager] extractLongTerm error: $e');
      return [];
    }
  }

  // ── Memory context injection ──────────────────────────────────────────

  /// Builds a memory context string for injection into the system prompt.
  ///
  /// Format:
  /// ```
  /// ## User Profile
  /// - Occupation: frontend engineer
  /// - Location: Shanghai
  ///
  /// ## Preferences
  /// - Reply style: concise
  ///
  /// ## Recent Context
  /// - Currently planning a trip to Japan
  ///
  /// ## Recent Sessions
  /// - 2026-09-01: Discussed morning routine planning
  /// ```
  String buildMemoryContext({int maxItems = 20, int maxEpisodes = 3}) {
    if (!_cacheLoaded || (_memoryCache.isEmpty && _episodeCache.isEmpty)) {
      return '';
    }

    final sections = <String>[];

    // Facts
    final facts = getByCategory(MemoryCategory.fact).take(5).toList();
    if (facts.isNotEmpty) {
      sections.add('## User Profile');
      for (final f in facts) {
        sections.add('- ${_humanizeKey(f.key)}: ${f.value}');
      }
    }

    // Preferences
    final prefs = getByCategory(MemoryCategory.preference).take(5).toList();
    if (prefs.isNotEmpty) {
      sections.add('## Preferences');
      for (final p in prefs) {
        sections.add('- ${_humanizeKey(p.key)}: ${p.value}');
      }
    }

    // Skill mastery
    final skills = getByCategory(MemoryCategory.skillMastery).take(5).toList();
    if (skills.isNotEmpty) {
      sections.add('## Skills');
      for (final s in skills) {
        sections.add('- ${_humanizeKey(s.key)}: ${s.value}');
      }
    }

    // Context
    final contexts = getByCategory(MemoryCategory.context).take(maxItems).toList();
    if (contexts.isNotEmpty) {
      sections.add('## Current Context');
      for (final c in contexts) {
        sections.add('- ${c.value}');
      }
    }

    // Recent episodes
    final recent = getRecentEpisodes(maxEpisodes);
    if (recent.isNotEmpty) {
      sections.add('## Recent Sessions');
      for (final e in recent) {
        final date = e.sessionStart.substring(0, 10);
        sections.add('- $date: ${e.summary}');
      }
    }

    return sections.join('\n');
  }

  // ── Private helpers ───────────────────────────────────────────────────

  String _buildTranscript(List<LlmMessage> messages) {
    final lines = <String>[];
    for (final msg in messages) {
      final role = msg.role == 'user'
          ? 'User'
          : msg.role == 'assistant'
              ? 'Assistant'
              : msg.role == 'tool'
                  ? 'Tool'
                  : msg.role;
      final content = msg.content ?? '';
      if (content.isNotEmpty) {
        lines.add('$role: $content');
      }
    }
    // Limit to ~2000 chars to avoid token overflow
    final transcript = lines.join('\n');
    if (transcript.length > 2000) {
      return '${transcript.substring(0, 2000)}...[truncated]';
    }
    return transcript;
  }

  String _buildFallbackSummary(List<LlmMessage> messages) {
    final userMessages = messages.where((m) => m.role == 'user').toList();
    if (userMessages.isEmpty) return 'Session with no user messages.';
    final first = userMessages.first.content ?? '';
    return 'Session about: ${first.substring(0, first.length > 100 ? 100 : first.length)}';
  }

  (String, List<String>) _parseSummaryResponse(String content) {
    try {
      // Try to extract JSON from the response
      final jsonStr = _extractJson(content);
      if (jsonStr != null) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final summary = json['summary'] as String? ?? content;
        final topicsRaw = json['topics'] as List?;
        final topics = topicsRaw?.map((e) => e.toString()).toList() ?? <String>[];
        return (summary, topics);
      }
    } catch (_) {
      // Fall through
    }
    // Fallback: use the raw content as summary
    return (content, <String>[]);
  }

  List<MemoryItem> _parseExtractionResponse(String content) {
    try {
      final jsonStr = _extractJson(content, preferArray: true);
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          return decoded
              .map((e) {
                final map = e as Map<String, dynamic>;
                return MemoryItem.now(
                  key: map['key'] as String? ?? '',
                  category: _parseCategory(map['category'] as String? ?? 'context'),
                  value: map['value'] as String? ?? '',
                  confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
                  source: 'llm_extract',
                  userId: userId,
                );
              })
              .where((m) => m.key.isNotEmpty && m.value.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {
      // Fall through
    }
    return [];
  }

  String? _extractJson(String content, {bool preferArray = false}) {
    // Try to find JSON in the response (may be wrapped in markdown)
    if (preferArray) {
      // For extraction responses, look for array first
      final arrStart = content.indexOf('[');
      final arrEnd = content.lastIndexOf(']');
      if (arrStart >= 0 && arrEnd > arrStart) {
        return content.substring(arrStart, arrEnd + 1);
      }
    }
    // Try object
    final jsonStart = content.indexOf('{');
    final jsonEnd = content.lastIndexOf('}');
    if (jsonStart >= 0 && jsonEnd > jsonStart) {
      return content.substring(jsonStart, jsonEnd + 1);
    }
    // Try array
    final arrStart = content.indexOf('[');
    final arrEnd = content.lastIndexOf(']');
    if (arrStart >= 0 && arrEnd > arrStart) {
      return content.substring(arrStart, arrEnd + 1);
    }
    return null;
  }

  String _humanizeKey(String key) {
    // "preference.reply_style" -> "Reply style"
    final parts = key.split('.');
    if (parts.length < 2) return key;
    final name = parts.last.replaceAll('_', ' ');
    return name[0].toUpperCase() + name.substring(1);
  }

  MemoryCategory _parseCategory(String name) {
    return MemoryCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => MemoryCategory.context,
    );
  }
}
