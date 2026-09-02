import 'dart:async';

import 'package:nudgee/core/agent/agent_config.dart';
import 'package:nudgee/core/agent/agent_core.dart';
import 'package:nudgee/core/agent/agent_event.dart';
import 'package:nudgee/core/agent/context/context_governor.dart';
import 'package:nudgee/core/agent/memory/memory_manager.dart';
import 'package:nudgee/core/agent/permission/permission.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';
import 'package:nudgee/core/agent/tools/tool_registry.dart';
import 'package:nudgee/core/agent/trace/agent_trace.dart';

/// Orchestrator — manages the Agent execution lifecycle.
///
/// Wraps [AgentCore] with:
/// - Agent selection (multiple AgentConfigs)
/// - Session management
/// - Stats aggregation
/// - Error recovery
/// - Memory injection (via [MemoryManager])
/// - Execution tracing (via [AgentTrace])
class Orchestrator {
  /// LLM client shared across all Agents.
  final LLMClient llmClient;

  /// Tool registry shared across all Agents.
  final ToolRegistry toolRegistry;

  /// Permission context.
  final PermissionContext permissionContext;

  /// Optional memory manager for long-term memory injection.
  final MemoryManager? memoryManager;

  /// Optional trace recorder. A fresh [AgentTrace] is created per run
  /// if this factory is set, so each run gets its own trace.
  final AgentTrace Function()? traceFactory;

  /// Optional confirmation handler for interactive permission prompts.
  final Future<bool> Function(ToolCall call, String reason)? onConfirmation;

  /// Registered Agent configurations, keyed by ID.
  final Map<String, AgentConfig> _agents = {};

  /// Creates an [Orchestrator].
  Orchestrator({
    required this.llmClient,
    required this.toolRegistry,
    required this.permissionContext,
    this.memoryManager,
    this.traceFactory,
    this.onConfirmation,
  });

  /// Registers an Agent configuration.
  void registerAgent(AgentConfig config) {
    _agents[config.id] = config;
  }

  /// Registers multiple Agent configurations.
  void registerAllAgents(List<AgentConfig> configs) {
    for (final c in configs) {
      registerAgent(c);
    }
  }

  /// Gets an Agent configuration by ID.
  AgentConfig? getAgent(String id) => _agents[id];

  /// All registered Agent configurations.
  List<AgentConfig> get agents => _agents.values.toList();

  /// Runs an Agent with [agentId].
  ///
  /// Yields [AgentEvent]s from the Agent's ReAct loop.
  /// Throws [StateError] if the agent is not registered.
  Stream<AgentEvent> runAgent({
    required String agentId,
    required String userInput,
    List<LlmMessage> history = const [],
    String? extraSystemContext,
    List<String>? images,
  }) async* {
    final config = _agents[agentId];
    if (config == null) {
      yield AgentEvent.error('Agent "$agentId" not registered');
      return;
    }

    final trace = traceFactory?.call();

    final core = AgentCore(
      config: config,
      llmClient: llmClient,
      toolRegistry: toolRegistry,
      contextGovernor: ContextGovernor.fromConfig(
        config,
        memoryManager: memoryManager,
      ),
      permissionContext: permissionContext,
      trace: trace,
      onConfirmation: onConfirmation,
    );

    yield* core.run(
      userInput: userInput,
      history: history,
      extraSystemContext: extraSystemContext,
      images: images,
    );
  }

  /// Runs the default Agent (first registered).
  Stream<AgentEvent> run({
    required String userInput,
    List<LlmMessage> history = const [],
    String? extraSystemContext,
    List<String>? images,
  }) async* {
    if (_agents.isEmpty) {
      yield AgentEvent.error('No agents registered');
      return;
    }
    final defaultAgent = _agents.values.first;
    yield* runAgent(
      agentId: defaultAgent.id,
      userInput: userInput,
      history: history,
      extraSystemContext: extraSystemContext,
      images: images,
    );
  }
}
