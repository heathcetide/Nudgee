import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/agent_event.dart';
import 'package:nudgee/core/agent/agent_harness.dart';
import 'package:nudgee/core/agent/agent_stats.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';

/// Sub-agent orchestrator — enables agent-to-agent delegation.
///
/// Allows a parent agent to delegate sub-tasks to specialized child agents.
/// Each sub-agent runs independently with its own config, tools, and context,
/// then returns its result to the parent.
///
/// Key features:
/// - **Delegate**: Run a sub-agent with a specific task and collect its result
/// - **Fan-out**: Run multiple sub-agents in parallel and merge results
/// - **Stats merging**: Sub-agent stats are merged into the parent's stats
/// - **Event forwarding**: Sub-agent events can be forwarded to the parent
///
/// Usage:
/// ```dart
/// final orchestrator = SubAgentOrchestrator(harness: harness);
/// final result = await orchestrator.delegate(
///   agentId: 'research-analyst',
///   task: 'Find recent papers on RAG optimization',
///   parentHistory: parentHistory,
/// );
/// print(result.reply);  // Sub-agent's final reply
/// print(result.stats);  // Merged stats
/// ```
class SubAgentOrchestrator {
  /// The parent harness that provides access to agents.
  final AgentHarness harness;

  /// Maximum depth of nested sub-agent calls (prevents infinite recursion).
  final int maxDepth;

  /// Current depth (0 for top-level).
  final int _currentDepth;

  /// Creates a [SubAgentOrchestrator].
  SubAgentOrchestrator({
    required this.harness,
    this.maxDepth = 3,
    int currentDepth = 0,
  }) : _currentDepth = currentDepth;

  /// Delegates a [task] to a sub-agent identified by [agentId].
  ///
  /// The sub-agent runs with its own config but shares the same LLM client,
  /// tool registry, and permission context as the parent.
  ///
  /// Parameters:
  /// - [agentId]: The ID of the sub-agent to run (must be registered in [harness]).
  /// - [task]: The task description for the sub-agent.
  /// - [parentHistory]: The parent's conversation history (for context).
  /// - [extraContext]: Additional context to inject into the sub-agent.
  ///
  /// Returns a [SubAgentResult] with the sub-agent's reply and stats.
  Future<SubAgentResult> delegate({
    required String agentId,
    required String task,
    List<LlmMessage>? parentHistory,
    String? extraContext,
  }) async {
    if (_currentDepth >= maxDepth) {
      return SubAgentResult(
        reply: 'Sub-agent delegation depth limit reached ($maxDepth). '
            'Cannot delegate further.',
        stats: const AgentRunStats(
          steps: 0,
          inputTokens: 0,
          outputTokens: 0,
          thinkingTokens: 0,
          toolCalls: 0,
          skillUses: 0,
          duration: Duration.zero,
        ),
        success: false,
        error: 'Max depth exceeded',
      );
    }

    final config = harness.orchestrator.getAgent(agentId);
    if (config == null) {
      return SubAgentResult(
        reply: 'Sub-agent "$agentId" not found.',
        stats: const AgentRunStats(
          steps: 0,
          inputTokens: 0,
          outputTokens: 0,
          thinkingTokens: 0,
          toolCalls: 0,
          skillUses: 0,
          duration: Duration.zero,
        ),
        success: false,
        error: 'Agent not found: $agentId',
      );
    }

    debugPrint('[SubAgent] delegating to "$agentId" '
        '(depth=${_currentDepth + 1}): ${task.substring(0, task.length.clamp(0, 80))}');

    // Build context for the sub-agent
    final subHistory = <LlmMessage>[];
    if (parentHistory != null && parentHistory.isNotEmpty) {
      // Pass a summary of parent context (last few messages)
      final recentCount = parentHistory.length > 5 ? 5 : parentHistory.length;
      subHistory.addAll(parentHistory.sublist(parentHistory.length - recentCount));
    }

    // Add delegation context
    final delegationContext = extraContext != null
        ? 'Delegated by parent agent. Context: $extraContext'
        : 'Delegated by parent agent.';

    // Collect events and result
    final events = <AgentEvent>[];
    String finalReply = '';
    AgentRunStats? stats;

    try {
      final eventStream = harness.orchestrator.runAgent(
        agentId: agentId,
        userInput: task,
        history: subHistory,
        extraSystemContext: delegationContext,
      );

      await for (final event in eventStream) {
        events.add(event);
        switch (event) {
          case DoneEvent():
            finalReply = event.finalReply;
            stats = event.stats;
          case ErrorEvent():
            debugPrint('[SubAgent] error from "$agentId": ${event.message}');
          default:
            // Forward other events if needed
            break;
        }
      }

      if (stats == null) {
        stats = const AgentRunStats(
          steps: 0,
          inputTokens: 0,
          outputTokens: 0,
          thinkingTokens: 0,
          toolCalls: 0,
          skillUses: 0,
          duration: Duration.zero,
        );
      }

      debugPrint('[SubAgent] "$agentId" completed: '
          '${stats.steps} steps, ${stats.toolCalls} tool calls, '
          '${stats.duration.inSeconds}s');

      return SubAgentResult(
        reply: finalReply,
        stats: stats,
        success: true,
        events: events,
      );
    } catch (e) {
      debugPrint('[SubAgent] "$agentId" failed: $e');
      return SubAgentResult(
        reply: 'Sub-agent "$agentId" failed: $e',
        stats: const AgentRunStats(
          steps: 0,
          inputTokens: 0,
          outputTokens: 0,
          thinkingTokens: 0,
          toolCalls: 0,
          skillUses: 0,
          duration: Duration.zero,
        ),
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Runs multiple sub-agents in parallel (fan-out pattern).
  ///
  /// Each [delegate] call runs concurrently, and results are collected
  /// as they complete. Returns all results once all sub-agents finish.
  ///
  /// Example:
  /// ```dart
  /// final results = await orchestrator.delegateParallel([
  ///   DelegateRequest(agentId: 'research-analyst', task: 'Search for X'),
  ///   DelegateRequest(agentId: 'code-assistant', task: 'Analyze code Y'),
  /// ]);
  /// ```
  Future<List<SubAgentResult>> delegateParallel(
    List<DelegateRequest> requests, {
    List<LlmMessage>? parentHistory,
  }) async {
    final futures = requests.map((req) => delegate(
          agentId: req.agentId,
          task: req.task,
          parentHistory: parentHistory,
          extraContext: req.extraContext,
        ));

    return Future.wait(futures);
  }

  /// Runs sub-agents sequentially, passing each result to the next.
  ///
  /// This creates a pipeline where each sub-agent's output becomes
  /// part of the next sub-agent's context.
  ///
  /// Example:
  /// ```dart
  /// final result = await orchestrator.delegatePipeline([
  ///   DelegateRequest(agentId: 'research-analyst', task: 'Find papers on X'),
  ///   DelegateRequest(agentId: 'code-assistant', task: 'Summarize findings'),
  /// ]);
  /// ```
  Future<SubAgentResult> delegatePipeline(
    List<DelegateRequest> requests, {
    List<LlmMessage>? parentHistory,
  }) async {
    if (requests.isEmpty) {
      return SubAgentResult(
        reply: 'No sub-agents to run.',
        stats: const AgentRunStats(
          steps: 0,
          inputTokens: 0,
          outputTokens: 0,
          thinkingTokens: 0,
          toolCalls: 0,
          skillUses: 0,
          duration: Duration.zero,
        ),
        success: true,
      );
    }

    var currentHistory = parentHistory ?? <LlmMessage>[];
    var mergedStats = const AgentRunStats(
      steps: 0,
      inputTokens: 0,
      outputTokens: 0,
      thinkingTokens: 0,
      toolCalls: 0,
      skillUses: 0,
      duration: Duration.zero,
    );
    var lastResult = SubAgentResult(
      reply: '',
      stats: mergedStats,
      success: true,
    );

    for (final req in requests) {
      final result = await delegate(
        agentId: req.agentId,
        task: req.task,
        parentHistory: currentHistory,
        extraContext: req.extraContext,
      );

      mergedStats = mergedStats.merge(result.stats);

      if (!result.success) {
        return SubAgentResult(
          reply: result.reply,
          stats: mergedStats,
          success: false,
          error: result.error,
        );
      }

      // Add sub-agent's reply to history for the next sub-agent
      currentHistory = [...currentHistory, LlmMessage.assistant(text: result.reply)];
      lastResult = result;
    }

    return SubAgentResult(
      reply: lastResult.reply,
      stats: mergedStats,
      success: true,
    );
  }

  /// Creates a child orchestrator with increased depth.
  SubAgentOrchestrator child() => SubAgentOrchestrator(
        harness: harness,
        maxDepth: maxDepth,
        currentDepth: _currentDepth + 1,
      );
}

/// A delegation request for sub-agent execution.
class DelegateRequest {
  /// The sub-agent ID to run.
  final String agentId;

  /// The task for the sub-agent.
  final String task;

  /// Optional extra context.
  final String? extraContext;

  /// Creates a [DelegateRequest].
  const DelegateRequest({
    required this.agentId,
    required this.task,
    this.extraContext,
  });
}

/// Result from a sub-agent delegation.
class SubAgentResult {
  /// The sub-agent's final reply.
  final String reply;

  /// The sub-agent's run statistics.
  final AgentRunStats stats;

  /// Whether the delegation succeeded.
  final bool success;

  /// Error message if [success] is false.
  final String? error;

  /// All events emitted by the sub-agent.
  final List<AgentEvent> events;

  /// Creates a [SubAgentResult].
  const SubAgentResult({
    required this.reply,
    required this.stats,
    required this.success,
    this.error,
    this.events = const [],
  });

  @override
  String toString() =>
      'SubAgentResult(${success ? "ok" : "error"}, ${stats.steps} steps, '
      '${stats.toolCalls} tool calls)';
}
