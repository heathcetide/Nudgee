import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/agent_config.dart';
import 'package:nudgee/core/agent/agent_event.dart';
import 'package:nudgee/core/agent/cost_tracker.dart';
import 'package:nudgee/core/agent/guard/guard_rails.dart';
import 'package:nudgee/core/agent/memory/memory_manager.dart';
import 'package:nudgee/core/agent/orchestrator.dart';
import 'package:nudgee/core/agent/permission/permission.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';
import 'package:nudgee/core/agent/skills/agent_skill.dart';
import 'package:nudgee/core/agent/skills/skill_executor.dart';
import 'package:nudgee/core/agent/skills/skill_models.dart';
import 'package:nudgee/core/agent/skills/skill_registry.dart';
import 'package:nudgee/core/agent/tools/tool_registry.dart';
import 'package:nudgee/core/agent/trace/agent_trace.dart';

/// Agent harness — the top-level entry point for running Agents.
///
/// Combines:
/// - [LLMClient] for model access
/// - [ToolRegistry] for tool execution
/// - [SkillRegistry] for skill matching and execution
/// - [PermissionContext] for authorization
/// - [MemoryManager] for long-term memory injection
/// - [AgentTrace] for execution observability
/// - [Orchestrator] for Agent lifecycle
///
/// When a skill is matched, the harness first executes the skill workflow,
/// then feeds the skill output into the agent's context for final response.
///
/// Usage:
/// ```dart
/// final harness = AgentHarness(
///   llmClient: DeepSeekClient(apiKey: '...'),
///   toolRegistry: registry,
///   skillRegistry: skillRegistry,
///   memoryManager: memoryManager,
///   permissionContext: PermissionContext.fixed(PermissionMode.normal),
/// );
/// harness.registerAgent(defaultAgentConfig);
///
/// await for (final event in harness.run(userInput: 'Plan my week')) {
///   switch (event) {
///     case ContentEvent(:final delta): print(delta);
///     case DoneEvent(:final finalReply): print('Done: $finalReply');
///     case ErrorEvent(:final message): print('Error: $message');
///     case _: {}
///   }
/// }
/// ```
class AgentHarness {
  /// LLM client.
  final LLMClient llmClient;

  /// Tool registry.
  final ToolRegistry toolRegistry;

  /// Skill registry (optional, Phase 4).
  final SkillRegistry? skillRegistry;

  /// Permission context.
  final PermissionContext permissionContext;

  /// Optional memory manager for long-term memory injection.
  final MemoryManager? memoryManager;

  /// Optional trace factory — called per run to create a fresh trace.
  final AgentTrace Function()? traceFactory;

  /// Optional confirmation handler for interactive permission prompts.
  final Future<bool> Function(ToolCall call, String reason)? onConfirmation;

  /// Optional guardrails for safety checks.
  final GuardRails? guardRails;

  /// Optional cost tracker for budget enforcement.
  final CostTracker? costTracker;

  /// Underlying orchestrator.
  late final Orchestrator orchestrator;

  /// Skill executor (lazy-init if skillRegistry is set).
  late SkillExecutor? skillExecutor;

  /// Skill matcher (lazy-init if skillRegistry is set).
  late SkillMatcher? skillMatcher;

  /// LLM model for skill matching and execution.
  String llmModel;

  /// Creates an [AgentHarness].
  AgentHarness({
    required this.llmClient,
    required this.toolRegistry,
    required this.permissionContext,
    this.skillRegistry,
    this.memoryManager,
    this.traceFactory,
    this.onConfirmation,
    this.guardRails,
    this.costTracker,
    this.llmModel = 'gpt-5.4-mini',
  }) {
    orchestrator = Orchestrator(
      llmClient: llmClient,
      toolRegistry: toolRegistry,
      permissionContext: permissionContext,
      memoryManager: memoryManager,
      traceFactory: traceFactory,
      onConfirmation: onConfirmation,
      guardRails: guardRails,
      costTracker: costTracker,
    );

    if (skillRegistry != null) {
      skillExecutor = SkillExecutor(
        toolRegistry: toolRegistry,
        llmClient: llmClient,
        llmModel: llmModel,
      );
      skillMatcher = SkillMatcher(
        llmClient: llmClient,
        registry: skillRegistry!,
        model: llmModel,
      );
    } else {
      skillExecutor = null;
      skillMatcher = null;
    }
  }

  /// Registers an Agent configuration.
  void registerAgent(AgentConfig config) {
    orchestrator.registerAgent(config);
  }

  /// Updates the LLM model used for skill matching and execution.
  /// Recreates the skill matcher and executor with the new model.
  void updateLlmModel(String model) {
    llmModel = model;
    if (skillRegistry != null) {
      skillExecutor = SkillExecutor(
        toolRegistry: toolRegistry,
        llmClient: llmClient,
        llmModel: model,
      );
      skillMatcher = SkillMatcher(
        llmClient: llmClient,
        registry: skillRegistry!,
        model: model,
      );
    }
  }

  /// Registers multiple Agent configurations.
  void registerAllAgents(List<AgentConfig> configs) {
    orchestrator.registerAllAgents(configs);
  }

  /// Gets an Agent configuration by ID.
  AgentConfig? getAgent(String id) => orchestrator.getAgent(id);

  /// All registered Agent configurations.
  List<AgentConfig> get agents => orchestrator.agents;

  /// Runs an Agent by ID.
  Stream<AgentEvent> runAgent({
    required String agentId,
    required String userInput,
    List<LlmMessage> history = const [],
    String? extraSystemContext,
    List<String>? images,
  }) {
    return orchestrator.runAgent(
      agentId: agentId,
      userInput: userInput,
      history: history,
      extraSystemContext: extraSystemContext,
      images: images,
    );
  }

  /// Runs a specific Agent by ID (or the default if [agentId] is null).
  Stream<AgentEvent> run({
    required String userInput,
    List<LlmMessage> history = const [],
    String? extraSystemContext,
    List<String>? images,
    String? agentId,
  }) {
    if (agentId != null) {
      return orchestrator.runAgent(
        agentId: agentId,
        userInput: userInput,
        history: history,
        extraSystemContext: extraSystemContext,
        images: images,
      );
    }
    return orchestrator.run(
      userInput: userInput,
      history: history,
      extraSystemContext: extraSystemContext,
      images: images,
    );
  }

  /// Matches a skill for the given user input.
  ///
  /// Returns the matched [AgentSkill], or null if no skill matches.
  /// Uses LLM-based matching with rule-based fallback.
  Future<AgentSkill?> matchSkill(String userInput) async {
    if (skillMatcher == null) return null;
    return skillMatcher!.match(userInput);
  }

  /// Executes a skill by ID and returns a stream of execution events.
  ///
  /// The [memoryContext] function is called to get the current memory
  /// context string for personalization.
  Stream<SkillExecutionEvent> executeSkill({
    required String skillId,
    required String userInput,
    String Function()? memoryContext,
    String userId = 'default',
    Map<String, dynamic> params = const {},
  }) async* {
    if (skillRegistry == null || skillExecutor == null) {
      yield SkillExecutionEvent.error('Skill system not initialized');
      yield SkillExecutionEvent.done(
        const SkillResult(
          success: false,
          summary: 'Skill system not initialized',
          error: 'No SkillRegistry provided',
        ),
      );
      return;
    }

    final skill = skillRegistry!.getById(skillId);
    if (skill == null) {
      yield SkillExecutionEvent.error('Skill not found: $skillId');
      yield SkillExecutionEvent.done(
        SkillResult.failed('Skill not found: $skillId'),
      );
      return;
    }

    yield* skillExecutor!.executeSkill(
      skill: skill,
      userInput: userInput,
      memoryContext: memoryContext,
      userId: userId,
      params: params,
    );
  }

  /// Runs the agent with skill matching.
  ///
  /// This is the full Phase 4 flow:
  /// 1. Match a skill for the user input (if skillRegistry is set)
  /// 2. If a skill is matched, execute it and collect the output
  /// 3. Run the agent with the skill output as extra context
  /// 4. Stream agent events
  ///
  /// If no skill is matched, falls back to normal agent execution.
  Stream<AgentEvent> runWithSkills({
    required String userInput,
    List<LlmMessage> history = const [],
    String Function()? memoryContext,
    String userId = 'default',
    String? extraSystemContext,
    List<String>? images,
    List<String>? allowedSkillIds,
    String? agentId,
  }) async* {
    // Step 1: Try to match a skill
    AgentSkill? matchedSkill;
    if (skillMatcher != null) {
      try {
        matchedSkill = await skillMatcher!.match(userInput);
        // Filter by allowed skill IDs if specified
        if (matchedSkill != null && allowedSkillIds != null) {
          if (!allowedSkillIds.contains(matchedSkill.id)) {
            debugPrint('[AgentHarness] skill "${matchedSkill.id}" not in '
                'allowedSkillIds, skipping');
            matchedSkill = null;
          }
        }
      } catch (e) {
        debugPrint('[AgentHarness] skill match error: $e');
      }
    }

    if (matchedSkill == null) {
      // No skill matched — run agent normally
      yield* run(
        userInput: userInput,
        history: history,
        extraSystemContext: extraSystemContext,
        images: images,
        agentId: agentId,
      );
      return;
    }

    // Step 2: Execute the skill
    debugPrint('[AgentHarness] matched skill: ${matchedSkill.id}');
    final skillOutputs = <String>[];
    SkillResult? skillResult;

    await for (final event in skillExecutor!.executeSkill(
      skill: matchedSkill,
      userInput: userInput,
      memoryContext: memoryContext,
      userId: userId,
    )) {
      if (event.type == SkillExecutionEventType.output && event.output != null) {
        skillOutputs.add(event.output!);
      }
      if (event.type == SkillExecutionEventType.done && event.result != null) {
        skillResult = event.result;
      }
    }

    // Step 3: Build extra context from skill output
    final skillContext = StringBuffer();
    skillContext.writeln('--- Skill: ${matchedSkill.name} ---');
    skillContext.writeln(matchedSkill.fullDescription);
    if (skillOutputs.isNotEmpty) {
      skillContext.writeln('\nSkill output:');
      for (final output in skillOutputs) {
        skillContext.writeln(output);
      }
    }
    if (skillResult != null) {
      skillContext.writeln('\nSkill result: ${skillResult.summary}');
    }

    // Step 4: Run agent with skill context + caller's extra context
    final combinedContext = extraSystemContext != null
        ? '${skillContext.toString()}\n\n$extraSystemContext'
        : skillContext.toString();
    yield* run(
      userInput: userInput,
      history: history,
      extraSystemContext: combinedContext,
      images: images,
      agentId: agentId,
    );
  }

  /// Releases resources.
  void dispose() {
    llmClient.dispose();
  }
}
