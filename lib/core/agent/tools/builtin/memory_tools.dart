import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/memory/memory_models.dart';
import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';
import 'package:nudgee/core/di/injector.dart';
import 'package:nudgee/core/services/agent_service.dart';
import 'package:nudgee/core/services/shared_prefs_service.dart';
import 'package:nudgee/core/services/user_storage_service.dart';

/// Tool: user.profile
///
/// Reads the current user's profile information (name, avatar, etc.).
/// Read-only tool — use this to personalize responses.
class UserProfileTool extends AgentTool {
  @override
  String get name => 'user.profile';

  @override
  String get description =>
      'Get the current user\'s profile information including name, avatar, '
      'and any saved preferences. Use this to personalize responses '
      'and to learn about the user.';

  @override
  Map<String, dynamic> get parametersSchema => {'type': 'object'};

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    try {
      final userStorage = sl<UserStorageService>();
      final profile = userStorage.getProfile();
      final userId = await userStorage.getUserId();

      if (profile == null && userId == null) {
        return const ToolResult.success(
            'No user profile found. The user may not be logged in.');
      }

      final info = <String, dynamic>{
        if (userId != null) 'userId': userId,
        if (profile != null) ...profile,
      };

      return ToolResult.success(
          'User profile: ${const JsonEncoder.withIndent('  ').convert(info)}');
    } catch (e) {
      return ToolResult.error('Failed to get user profile: $e');
    }
  }
}

/// Tool: memory.save
///
/// Saves a key-value memory item that persists across sessions.
/// The agent can use this to remember user preferences, facts, or context.
///
/// Mutation tool — requires confirmation.
class MemorySaveTool extends AgentTool {
  @override
  String get name => 'memory.save';

  @override
  String get description =>
      'Save a piece of information to long-term memory that persists across '
      'conversations. Use this to remember user preferences (e.g. "user '
      'prefers concise replies"), facts (e.g. "user is a frontend engineer"), '
      'or any important context. Provide a key and a value.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'key': {
            'type': 'string',
            'description':
                'A unique key for this memory item, e.g. "preference.reply_style"',
          },
          'value': {
            'type': 'string',
            'description': 'The value to remember',
          },
          'category': {
            'type': 'string',
            'description':
                'Category of memory: "preference", "fact", or "context"',
          },
        },
        'required': ['key', 'value'],
      };

  @override
  bool get isMutation => true;

  @override
  bool get requiresConfirmation => true;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final key = args['key'] as String?;
    final value = args['value'] as String?;
    final category = args['category'] as String? ?? 'context';

    if (key == null || value == null) {
      return const ToolResult.error('Missing required fields: key, value');
    }

    try {
      // 1. Save to MemoryManager (Hive) — used by buildMemoryContext()
      //    for system prompt injection.
      final agentService = sl<AgentService>();
      final memoryManager = agentService.memoryManager;
      if (memoryManager != null) {
        final memCategory = _parseCategory(category);
        final item = MemoryItem.now(
          key: key,
          category: memCategory,
          value: value,
          confidence: 0.9,
          source: 'user_explicit',
          userId: memoryManager.userId,
        );
        await memoryManager.saveMemory(item);
        debugPrint('[MemorySaveTool] Saved to MemoryManager: $key');
      }

      // 2. Also save to SharedPreferences as backup
      final prefs = sl<SharedPrefsService>();
      final storageKey = 'agent_memory_$key';
      final memoryEntry = jsonEncode({
        'key': key,
        'value': value,
        'category': category,
        'savedAt': DateTime.now().toIso8601String(),
      });
      prefs.setString(storageKey, memoryEntry);

      return ToolResult.success(
          'Saved to memory: [$category] $key = "${_truncate(value, 60)}"');
    } catch (e) {
      return ToolResult.error('Failed to save memory: $e');
    }
  }

  MemoryCategory _parseCategory(String name) {
    return MemoryCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => MemoryCategory.context,
    );
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}...';
}

/// Tool: memory.query
///
/// Retrieves a saved memory item by key, or lists all memory items.
/// Read-only tool.
class MemoryQueryTool extends AgentTool {
  @override
  String get name => 'memory.query';

  @override
  String get description =>
      'Retrieve a saved memory item by key, or list all saved memory items. '
      'Use this to recall user preferences, facts, or context that was '
      'previously saved with memory.save.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'key': {
            'type': 'string',
            'description':
                'The memory key to retrieve. If omitted, lists all saved memories.',
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    try {
      final key = args['key'] as String?;

      // 1. Try MemoryManager (Hive) first — this is the primary store
      final agentService = sl<AgentService>();
      final memoryManager = agentService.memoryManager;

      if (key != null) {
        // Retrieve specific memory
        if (memoryManager != null) {
          final item = memoryManager.getMemory(key);
          if (item != null) {
            return ToolResult.success(
                'Memory [$key]: ${item.value} '
                '(category: ${item.category.name}, saved: ${item.updatedAt})');
          }
        }
        // Fallback to SharedPreferences
        final prefs = sl<SharedPrefsService>();
        final storageKey = 'agent_memory_$key';
        final raw = prefs.getString(storageKey);
        if (raw == null) {
          return ToolResult.success('No memory found for key: "$key"');
        }
        final entry = jsonDecode(raw) as Map<String, dynamic>;
        return ToolResult.success(
            'Memory [$key]: ${entry['value']} '
            '(category: ${entry['category']}, saved: ${entry['savedAt']})');
      } else {
        // List all memories
        final lines = <String>[];

        // From MemoryManager
        if (memoryManager != null && memoryManager.isCacheLoaded) {
          for (final item in memoryManager.longTerm) {
            lines.add('- [${item.category.name}] ${item.key}: ${_truncate(item.value, 80)}');
          }
        }

        // Also from SharedPreferences (for items saved before the fix)
        final prefs = sl<SharedPrefsService>();
        final allKeys = prefs.getKeys();
        for (final k in allKeys) {
          if (k.startsWith('agent_memory_')) {
            final raw = prefs.getString(k);
            if (raw != null) {
              try {
                final entry = jsonDecode(raw) as Map<String, dynamic>;
                final memKey = entry['key'] as String? ?? k.substring('agent_memory_'.length);
                // Skip if already listed from MemoryManager
                if (memoryManager != null && memoryManager.getMemory(memKey) != null) {
                  continue;
                }
                lines.add('- [${entry['category'] ?? 'context'}] $memKey: ${_truncate(entry['value'] as String? ?? '', 80)}');
              } catch (_) {}
            }
          }
        }

        if (lines.isEmpty) {
          return const ToolResult.success('No memories saved yet.');
        }
        return ToolResult.success(
            'Saved memories (${lines.length}):\n${lines.join('\n')}');
      }
    } catch (e) {
      return ToolResult.error('Failed to query memory: $e');
    }
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}...';
}
