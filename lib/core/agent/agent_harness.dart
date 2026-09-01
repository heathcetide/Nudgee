import 'dart:async';

import 'package:nudgee/core/agent/agent_config.dart';
import 'package:nudgee/core/agent/agent_event.dart';
import 'package:nudgee/core/agent/orchestrator.dart';
import 'package:nudgee/core/agent/permission/permission.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';
import 'package:nudgee/core/agent/tools/tool_registry.dart';

/// Agent harness — the top-level entry point for running Agents.
///
/// Combines:
/// - [LLMClient] for model access
/// - [ToolRegistry] for tool execution
/// - [PermissionContext] for authorization
/// - [Orchestrator] for Agent lifecycle
///
/// Usage:
/// ```dart
/// final harness = AgentHarness(
///   llmClient: DeepSeekClient(apiKey: '...'),
///   toolRegistry: registry,
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

  /// Permission context.
  final PermissionContext permissionContext;

  /// Underlying orchestrator.
  late final Orchestrator orchestrator;

  /// Creates an [AgentHarness].
  AgentHarness({
    required this.llmClient,
    required this.toolRegistry,
    required this.permissionContext,
  }) {
    orchestrator = Orchestrator(
      llmClient: llmClient,
      toolRegistry: toolRegistry,
      permissionContext: permissionContext,
    );
  }

  /// Registers an Agent configuration.
  void registerAgent(AgentConfig config) {
    orchestrator.registerAgent(config);
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
  }) {
    return orchestrator.runAgent(
      agentId: agentId,
      userInput: userInput,
      history: history,
      extraSystemContext: extraSystemContext,
    );
  }

  /// Runs the default Agent.
  Stream<AgentEvent> run({
    required String userInput,
    List<LlmMessage> history = const [],
    String? extraSystemContext,
  }) {
    return orchestrator.run(
      userInput: userInput,
      history: history,
      extraSystemContext: extraSystemContext,
    );
  }

  /// Releases resources.
  void dispose() {
    llmClient.dispose();
  }
}
