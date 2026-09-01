import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/providers/llm_client.dart';
import 'package:nudgee/core/agent/skills/agent_skill.dart';
import 'package:nudgee/core/agent/skills/skill_models.dart';

/// Registry for managing and matching skills.
///
/// Responsibilities:
/// 1. Register/unregister skills
/// 2. Progressive disclosure: return summaries for LLM matching
/// 3. Rule-based matching via [AgentSkill.isApplicable]
/// 4. LLM-based matching via [SkillMatcher]
class SkillRegistry {
  final Map<String, AgentSkill> _skills = {};

  /// Registers a skill.
  void register(AgentSkill skill) {
    _skills[skill.id] = skill;
  }

  /// Registers multiple skills.
  void registerAll(List<AgentSkill> skills) {
    for (final s in skills) {
      register(s);
    }
  }

  /// Unregisters a skill by ID.
  void unregister(String id) {
    _skills.remove(id);
  }

  /// Gets a skill by ID.
  AgentSkill? getById(String id) => _skills[id];

  /// Gets all registered skills.
  List<AgentSkill> get all => _skills.values.toList();

  /// Number of registered skills.
  int get length => _skills.length;

  /// Whether a skill with the given ID is registered.
  bool contains(String id) => _skills.containsKey(id);

  /// Returns summaries for all skills (progressive disclosure).
  List<SkillSummary> summaries() {
    return _skills.values.map((s) => s.skillSummary).toList();
  }

  /// Rule-based matching: returns skills whose [isApplicable] returns true.
  List<AgentSkill> matchByRules(String userInput) {
    return _skills.values.where((s) => s.isApplicable(userInput)).toList();
  }

  /// Clears all registered skills.
  void clear() {
    _skills.clear();
  }
}

/// LLM-based skill matcher.
///
/// Uses the LLM to determine which skill (if any) is most applicable
/// to the user's input. This is more accurate than rule-based matching
/// but requires an LLM call.
class SkillMatcher {
  final LLMClient llmClient;
  final SkillRegistry registry;

  /// Model to use for matching.
  final String model;

  /// Creates a [SkillMatcher].
  SkillMatcher({
    required this.llmClient,
    required this.registry,
    this.model = 'gpt-5.4-mini',
  });

  /// Matches the user input to the best skill using LLM judgment.
  ///
  /// Returns the matched [AgentSkill], or null if no skill is applicable.
  /// Falls back to rule-based matching if the LLM call fails.
  Future<AgentSkill?> match(String userInput) async {
    // Fast path: if only 0 or 1 skills, skip LLM
    if (registry.length == 0) return null;
    if (registry.length == 1) {
      final skill = registry.all.first;
      return skill.isApplicable(userInput) ? skill : null;
    }

    // Try LLM-based matching
    try {
      final summaries = registry.summaries();
      final systemPrompt = 'You are a skill matcher. Given a user message and '
          'a list of available skills, determine which skill (if any) is most '
          'relevant. Respond with ONLY the skill ID, or "none" if no skill matches.\n\n'
          'Available skills:\n${summaries.map((s) => '- ${s.id}: ${s.summary}').join('\n')}';

      final response = await llmClient.chat(
        messages: [
          LlmMessage.user('User message: "$userInput"\n\n'
              'Which skill ID matches? Respond with only the ID or "none".'),
        ],
        model: model,
        temperature: 0.0,
        maxTokens: 50,
        systemPrompt: systemPrompt,
      );

      final content = response.content.trim().toLowerCase();

      if (content == 'none' || content.isEmpty) {
        return null;
      }

      // Extract skill ID (LLM might add extra text)
      final skillId = _extractSkillId(content, summaries);
      if (skillId != null) {
        return registry.getById(skillId);
      }

      // Fallback to rule-based
      return _fallbackMatch(userInput);
    } catch (e) {
      debugPrint('[SkillMatcher] LLM match error: $e, falling back to rules');
      return _fallbackMatch(userInput);
    }
  }

  /// Rule-based fallback matching.
  AgentSkill? _fallbackMatch(String userInput) {
    final matches = registry.matchByRules(userInput);
    if (matches.isEmpty) return null;
    // Return the first match (or the one with most keyword hits)
    return matches.first;
  }

  /// Extracts a skill ID from the LLM response.
  String? _extractSkillId(String content, List<SkillSummary> summaries) {
    // Direct match
    for (final s in summaries) {
      if (content == s.id.toLowerCase()) return s.id;
    }
    // Contains match
    for (final s in summaries) {
      if (content.contains(s.id.toLowerCase())) return s.id;
    }
    return null;
  }
}
