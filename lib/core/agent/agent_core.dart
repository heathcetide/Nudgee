import 'dart:async';

import 'package:nudgee/core/agent/agent_config.dart';
import 'package:nudgee/core/agent/agent_event.dart';
import 'package:nudgee/core/agent/agent_stats.dart';
import 'package:nudgee/core/agent/context/context_governor.dart';
import 'package:nudgee/core/agent/permission/permission.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';
import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_registry.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';
import 'package:nudgee/core/agent/trace/agent_trace.dart';

/// Agent core — implements the ReAct (Reason → Act → Observe) loop.
///
/// For each iteration:
/// 1. **Reason**: Call the LLM with the conversation history + tool definitions
/// 2. **Act**: If the LLM requests tool calls, execute them (with permission checks)
/// 3. **Observe**: Feed tool results back to the LLM
/// 4. Repeat until the LLM produces a final reply (no tool calls) or [maxSteps] is hit
///
/// Emits [AgentEvent]s as a stream for the UI to consume.
class AgentCore {
  /// The Agent configuration.
  final AgentConfig config;

  /// LLM client for model calls.
  final LLMClient llmClient;

  /// Tool registry for tool execution.
  final ToolRegistry toolRegistry;

  /// Context governor for context management.
  final ContextGovernor contextGovernor;

  /// Permission context for tool authorization.
  final PermissionContext permissionContext;

  /// Optional trace recorder. If provided, the agent will record
  /// structured trace entries during execution for debugging and observability.
  final AgentTrace? trace;

  /// Creates an [AgentCore].
  AgentCore({
    required this.config,
    required this.llmClient,
    required this.toolRegistry,
    required this.contextGovernor,
    required this.permissionContext,
    this.trace,
  });

  /// Runs the ReAct loop with [userInput] and conversation [history].
  ///
  /// Yields [AgentEvent]s as they occur:
  /// - [ThinkingEvent]: reasoning deltas
  /// - [ContentEvent]: reply text deltas
  /// - [ToolCallEvent]: the LLM requested a tool call
  /// - [ToolResultEvent]: a tool finished executing
  /// - [HumanConfirmationEvent]: a tool needs user confirmation
  /// - [LoopWarningEvent]: possible infinite loop
  /// - [DoneEvent]: the run completed
  /// - [ErrorEvent]: an error occurred
  Stream<AgentEvent> run({
    required String userInput,
    List<LlmMessage> history = const [],
    String? extraSystemContext,
  }) async* {
    final stopwatch = Stopwatch()..start();
    var stats = AgentRunStats(
      steps: 0,
      inputTokens: 0,
      outputTokens: 0,
      toolCalls: 0,
      skillUses: 0,
      duration: Duration.zero,
    );

    // Build tool definitions for the LLM
    final toolDefs = _buildToolDefinitions();
    final llmToolDefs = toolDefs
        .map((d) => LlmToolDefinition(
              name: d.name,
              description: d.description,
              parametersSchema: d.parametersSchema,
            ))
        .toList();

    // Build conversation: history + new user input
    final messages = <LlmMessage>[...history, LlmMessage.user(userInput)];

    // Track seen tool call signatures for loop detection
    final seenSignatures = <String>{};

    // Record run start
    trace?.recordRunStart(
      input: userInput,
      agentId: config.id,
      model: config.model,
      toolNames: config.toolNames,
      maxSteps: config.maxSteps,
    );

    try {
      for (var step = 0; step < config.maxSteps; step++) {
        stats = stats.copyWith(steps: step + 1);
        trace?.recordStepStart(step: step + 1);

        // Build context (sanitize + microcompact)
        final contextMessages = contextGovernor.buildContext(messages);
        final systemPrompt = contextGovernor.buildSystemPrompt(
          extraContext: extraSystemContext,
        );

        final toolCalls = <ToolCall>[];
        final contentBuffer = StringBuffer();

        if (llmToolDefs.isNotEmpty) {
          // ── Tool mode: use non-streaming chat ──
          trace?.recordLlmRequest(
            messageCount: contextMessages.length,
            toolCount: llmToolDefs.length,
            model: config.model,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            streaming: false,
          );

          final llmStopwatch = Stopwatch()..start();
          final response = await llmClient.chat(
            messages: contextMessages,
            model: config.model,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            tools: llmToolDefs,
            systemPrompt: systemPrompt,
          );
          llmStopwatch.stop();

          trace?.recordLlmResponse(
            response: response,
            durationMs: llmStopwatch.elapsedMilliseconds,
          );

          if (response.usage != null) {
            stats = stats.copyWith(
              inputTokens: stats.inputTokens + response.usage!.inputTokens,
              outputTokens: stats.outputTokens + response.usage!.outputTokens,
              thinkingTokens:
                  stats.thinkingTokens + response.usage!.thinkingTokens,
            );
          }

          // Emit content if any
          if (response.content.isNotEmpty) {
            yield AgentEvent.content(response.content);
            contentBuffer.write(response.content);
          }

          if (!response.hasToolCalls) {
            // No tool calls — we're done
            stopwatch.stop();
            stats = stats.copyWith(duration: stopwatch.elapsed);
            trace?.recordRunEnd(stats: stats, finalReply: response.content);
            yield AgentEvent.done(response.content, stats);
            return;
          }

          toolCalls.addAll(response.toolCalls);

          // Add assistant message with tool calls to history
          messages.add(LlmMessage.assistant(
            text: response.content,
            toolCalls: response.toolCalls,
          ));
        } else {
          // ── Pure chat mode: use streaming ──
          trace?.recordLlmRequest(
            messageCount: contextMessages.length,
            toolCount: 0,
            model: config.model,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            streaming: true,
          );

          await for (final chunk in llmClient.streamChat(
            messages: contextMessages,
            model: config.model,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            systemPrompt: systemPrompt,
          )) {
            if (chunk.hasThinking) {
              yield AgentEvent.thinking(chunk.thinkingDelta!);
            }
            if (chunk.hasContent) {
              contentBuffer.write(chunk.contentDelta);
              yield AgentEvent.content(chunk.contentDelta!);
            }
            if (chunk.isDone && chunk.usage != null) {
              stats = stats.copyWith(
                inputTokens: stats.inputTokens + chunk.usage!.inputTokens,
                outputTokens: stats.outputTokens + chunk.usage!.outputTokens,
                thinkingTokens:
                    stats.thinkingTokens + chunk.usage!.thinkingTokens,
              );
            }
          }

          if (contentBuffer.isEmpty) {
            stopwatch.stop();
            stats = stats.copyWith(duration: stopwatch.elapsed);
            trace?.recordRunEnd(stats: stats, finalReply: '');
            yield AgentEvent.done('', stats);
            return;
          }

          messages.add(LlmMessage.assistant(text: contentBuffer.toString()));
          stopwatch.stop();
          stats = stats.copyWith(duration: stopwatch.elapsed);
          trace?.recordRunEnd(stats: stats, finalReply: contentBuffer.toString());
          yield AgentEvent.done(contentBuffer.toString(), stats);
          return;
        }

        // Loop detection
        final signature = _toolCallSignature(toolCalls);
        if (seenSignatures.contains(signature)) {
          yield AgentEvent.loopWarning(step + 1);
          // Allow one repeat, but if we see it again, stop
          if (seenSignatures.where((s) => s == signature).length >= 2) {
            stopwatch.stop();
            stats = stats.copyWith(duration: stopwatch.elapsed);
            yield AgentEvent.error(
              'Loop detected: Agent is repeating the same tool calls',
              severity: ErrorSeverity.warning,
            );
            yield AgentEvent.done(
              'I seem to be stuck in a loop. Let me know if you want me to try a different approach.',
              stats,
            );
            return;
          }
        }
        seenSignatures.add(signature);

        // Execute tool calls
        for (final call in toolCalls) {
          yield AgentEvent.toolCall(call);
          trace?.recordToolCall(call);
          stats = stats.copyWith(toolCalls: stats.toolCalls + 1);

          // Permission check
          final toolDef = toolDefs.where((d) => d.name == call.name).firstOrNull;
          final decision = permissionContext.check(
            toolName: call.name,
            requiresConfirmation: toolDef?.requiresConfirmation ?? false,
            isMutation: toolDef?.isMutation ?? false,
          );

          trace?.recordPermissionCheck(
            toolName: call.name,
            decision: decision.isAllow ? 'allow' : decision.isDeny ? 'deny' : 'ask',
            mode: permissionContext.mode.name,
          );

          if (decision.isDeny) {
            yield AgentEvent.humanConfirmation(call, decision.message);
            trace?.recordPermissionDenied(toolName: call.name, reason: decision.message);
            // Feed denial back to LLM
            messages.add(LlmMessage.tool(
              toolCallId: call.id,
              name: call.name,
              content: 'Permission denied: ${decision.message}',
              isError: true,
            ));
            yield AgentEvent.toolResult(
              call.name,
              ToolResult.error('Permission denied: ${decision.message}'),
            );
            trace?.recordToolResult(
              toolName: call.name,
              toolCallId: call.id,
              success: false,
              error: 'Permission denied',
            );
            continue;
          }

          if (decision.isAsk) {
            yield AgentEvent.humanConfirmation(call, decision.message);
            trace?.recordPermissionDenied(toolName: call.name, reason: 'Confirmation required (headless mode)');
            // In Phase 1, we auto-deny (no interactive UI yet)
            // Phase 2 will add a real confirmation dialog
            messages.add(LlmMessage.tool(
              toolCallId: call.id,
              name: call.name,
              content: 'Confirmation required but not available in headless mode. '
                  'Please proceed without this tool or ask the user directly.',
              isError: true,
            ));
            yield AgentEvent.toolResult(
              call.name,
              ToolResult.error('Confirmation required'),
            );
            trace?.recordToolResult(
              toolName: call.name,
              toolCallId: call.id,
              success: false,
              error: 'Confirmation required',
            );
            continue;
          }

          // Execute the tool
          final toolStopwatch = Stopwatch()..start();
          final result = await toolRegistry.execute(call.name, call.arguments);
          toolStopwatch.stop();

          yield AgentEvent.toolResult(call.name, result);
          trace?.recordToolResult(
            toolName: call.name,
            toolCallId: call.id,
            success: result.success,
            output: result.output?.toString(),
            error: result.error,
            durationMs: toolStopwatch.elapsedMilliseconds,
          );

          // Feed result back to LLM
          messages.add(LlmMessage.tool(
            toolCallId: call.id,
            name: call.name,
            content: result.toLlmContent(),
            isError: !result.success,
          ));
        }
      }

      // Max steps reached
      stopwatch.stop();
      stats = stats.copyWith(duration: stopwatch.elapsed);
      trace?.recordWarning('Maximum steps (${config.maxSteps}) reached');
      trace?.recordRunEnd(stats: stats, finalReply: 'Max steps reached');
      yield AgentEvent.error(
        'Maximum steps (${config.maxSteps}) reached',
        severity: ErrorSeverity.warning,
      );
      yield AgentEvent.done(
        'I reached the maximum number of steps. '
        'Let me know if you want me to continue.',
        stats,
      );
    } catch (e) {
      stopwatch.stop();
      stats = stats.copyWith(duration: stopwatch.elapsed);
      trace?.recordError('Agent error: $e');
      trace?.recordRunEnd(stats: stats, finalReply: '');
      yield AgentEvent.error('Agent error: $e', severity: ErrorSeverity.error);
      yield AgentEvent.done('', stats);
    }
  }

  /// Builds tool definitions for the LLM from the config's allowed tools.
  List<ToolDefinition> _buildToolDefinitions() {
    if (config.toolNames.isEmpty) return [];
    return toolRegistry.definitionsFor(config.toolNames);
  }

  /// Creates a signature for loop detection.
  String _toolCallSignature(List<ToolCall> calls) {
    if (calls.isEmpty) return 'no-tools';
    return calls.map((c) => '${c.name}:${c.arguments.toString()}').join('|');
  }
}
