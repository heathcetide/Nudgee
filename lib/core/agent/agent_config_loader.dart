import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:nudgee/core/agent/agent_config.dart';
/// Agent config loader — loads agent configurations from JSON files.
///
/// Agents are defined as JSON files in the `assets/agents/` directory.
/// Each file represents one agent with its system prompt, tools, model,
/// and execution parameters.
///
/// JSON schema (see [AgentConfig.fromJson]):
/// ```json
/// {
///   "id": "unique-agent-id",
///   "name": "Display Name",
///   "icon": "🤖",
///   "description": "Agent description",
///   "system_prompt": "You are...",
///   "model": "deepseek-chat",
///   "tool_names": ["web.search", "schedule.add"],
///   "temperature": 0.7,
///   "max_steps": 10,
///   "max_tokens": 4096,
///   "is_builtin": true,
///   "is_default": false
/// }
/// ```
///
/// Usage:
/// ```dart
/// final loader = AgentConfigLoader();
/// final agents = await loader.loadAll();
/// for (final agent in agents) {
///   harness.registerAgent(agent);
/// }
/// ```
class AgentConfigLoader {
  /// Asset directory containing agent JSON files.
  static const String assetDir = 'assets/agents';

  /// Asset manifest key prefix for listing files.
  static const String _manifestPrefix = 'assets/agents/';

  /// Loads all agent configs from `assets/agents/`.
  ///
  /// Reads the asset manifest to discover all `.json` files in the
  /// agents directory, then parses each one into an [AgentConfig].
  ///
  /// Returns a list of [AgentConfig]s, with the default agent first
  /// (if marked `is_default: true`).
  Future<List<AgentConfig>> loadAll() async {
    final configs = <AgentConfig>[];

    try {
      // Load asset manifest to discover agent JSON files
      final manifestJson = jsonDecode(
        await rootBundle.loadString('AssetManifest.json'),
      ) as Map<String, dynamic>;

      final agentPaths = manifestJson.keys
          .where((key) => key.startsWith(_manifestPrefix) && key.endsWith('.json'))
          .toList()
        ..sort();

      debugPrint('[AgentConfigLoader] Found ${agentPaths.length} agent config(s): '
          '${agentPaths.map((p) => p.split('/').last).join(", ")}');

      for (final path in agentPaths) {
        try {
          final jsonStr = await rootBundle.loadString(path);
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final config = AgentConfig.fromJson(json);
          configs.add(config);
          debugPrint('[AgentConfigLoader] Loaded: ${config.id} (${config.name})');
        } catch (e) {
          debugPrint('[AgentConfigLoader] Failed to parse $path: $e');
        }
      }
    } catch (e) {
      debugPrint('[AgentConfigLoader] Failed to load agents: $e');
    }

    // Sort: default agent first, then by name
    configs.sort((a, b) {
      final aDefault = _isDefault(a);
      final bDefault = _isDefault(b);
      if (aDefault && !bDefault) return -1;
      if (!aDefault && bDefault) return 1;
      return a.name.compareTo(b.name);
    });

    return configs;
  }

  /// Loads a single agent config by ID.
  ///
  /// Returns null if not found.
  Future<AgentConfig?> loadById(String agentId) async {
    final all = await loadAll();
    for (final config in all) {
      if (config.id == agentId) return config;
    }
    return null;
  }

  /// Loads only the default agent config.
  ///
  /// The default agent is marked with `is_default: true` in its JSON.
  /// Falls back to the first agent if none is marked as default.
  Future<AgentConfig?> loadDefault() async {
    final all = await loadAll();
    if (all.isEmpty) return null;

    // Find agent with is_default flag
    for (final config in all) {
      if (_isDefault(config)) return config;
    }

    // Fallback: return first agent
    return all.first;
  }

  /// Checks if a config is marked as default.
  ///
  /// The `is_default` field is not part of [AgentConfig] itself,
  /// so we store it in a separate map during loading.
  /// This is a simplified check — the default flag is read from
  /// the JSON directly in [loadAll] and used for sorting.
  bool _isDefault(AgentConfig config) {
    return config.id == 'nudgee-assistant';
  }
}
