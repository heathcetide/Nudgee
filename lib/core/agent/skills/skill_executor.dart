import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:nudgee/core/agent/agent_event.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';
import 'package:nudgee/core/agent/skills/agent_skill.dart';
import 'package:nudgee/core/agent/skills/skill_models.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';
import 'package:nudgee/core/agent/tools/tool_registry.dart';

/// Executes skills and bridges skill events to the agent event stream.
///
/// Given a matched [AgentSkill], this executor:
/// 1. Builds a [SkillContext] with access to tools and LLM
/// 2. Runs the skill's [execute] method
/// 3. Converts [SkillEvent]s into a stream of [SkillExecutionEvent]s
///    that the caller can observe
/// 4. Returns the final [SkillResult]
class SkillExecutor {
  final ToolRegistry toolRegistry;
  final LLMClient llmClient;
  final String llmModel;

  /// Creates a [SkillExecutor].
  SkillExecutor({
    required this.toolRegistry,
    required this.llmClient,
    this.llmModel = 'gpt-5.4-mini',
  });

  /// Executes a skill and returns a stream of events + final result.
  ///
  /// The [memoryContext] function is called to get the current memory
  /// context string (for personalization).
  Stream<SkillExecutionEvent> executeSkill({
    required AgentSkill skill,
    required String userInput,
    String Function()? memoryContext,
    String userId = 'default',
    Map<String, dynamic> params = const {},
  }) async* {
    debugPrint('[SkillExecutor] executing skill: ${skill.id}');

    // Build the skill context
    final context = SkillContext(
      runTool: (name, args) async {
        if (!skill.allowedTools.contains(name)) {
          return ToolResult.error(
              'Tool "$name" is not allowed by skill "${skill.id}". '
              'Allowed tools: ${skill.allowedTools.join(", ")}');
        }
        return toolRegistry.execute(name, args);
      },
      llmChat: (prompt, {String? systemPrompt}) async {
        try {
          final response = await llmClient.chat(
            messages: [LlmMessage.user(prompt)],
            model: llmModel,
            temperature: 0.5,
            maxTokens: 1000,
            systemPrompt: systemPrompt,
          );
          return response.content;
        } catch (e) {
          debugPrint('[SkillExecutor] LLM chat error: $e');
          return 'Error: $e';
        }
      },
      getMemoryContext: memoryContext ?? () => '',
      userId: userId,
    );

    // Execute and convert events
    SkillResult? finalResult;

    try {
      await for (final event in skill.execute(
        userInput: userInput,
        context: context,
        params: params,
      )) {
        switch (event) {
          case SkillStepEvent(:final description, :final stepNumber, :final totalSteps):
            yield SkillExecutionEvent.step(
              description,
              stepNumber: stepNumber,
              totalSteps: totalSteps,
            );
          case SkillToolCallEvent(:final call):
            yield SkillExecutionEvent.toolCall(call);
          case SkillToolResultEvent(:final toolName, :final success, :final output):
            yield SkillExecutionEvent.toolResult(toolName, success, output);
          case SkillOutputEvent(:final content):
            yield SkillExecutionEvent.output(content);
          case SkillDoneEvent(:final result):
            finalResult = result;
            yield SkillExecutionEvent.done(result);
          case SkillErrorEvent(:final message):
            finalResult = SkillResult.failed(message);
            yield SkillExecutionEvent.error(message);
        }
      }
    } catch (e) {
      finalResult = SkillResult.failed(e.toString());
      yield SkillExecutionEvent.error(e.toString());
    }

    // If no done event was emitted, create one
    if (finalResult == null) {
      finalResult = const SkillResult(
        success: false,
        summary: 'Skill ended without a result',
        error: 'No SkillDoneEvent was emitted',
      );
      yield SkillExecutionEvent.done(finalResult);
    }
  }
}

/// Events emitted by [SkillExecutor] during skill execution.
///
/// These are a clean representation of skill events for the caller
/// (e.g. AgentHarness or UI layer) to consume.
class SkillExecutionEvent {
  final SkillExecutionEventType type;
  final String? description;
  final int? stepNumber;
  final int? totalSteps;
  final ToolCall? toolCall;
  final String? toolName;
  final bool? toolSuccess;
  final String? toolOutput;
  final String? output;
  final SkillResult? result;
  final String? error;

  const SkillExecutionEvent._({
    required this.type,
    this.description,
    this.stepNumber,
    this.totalSteps,
    this.toolCall,
    this.toolName,
    this.toolSuccess,
    this.toolOutput,
    this.output,
    this.result,
    this.error,
  });

  const SkillExecutionEvent.step(
    String description, {
    int? stepNumber,
    int? totalSteps,
  }) : this._(
          type: SkillExecutionEventType.step,
          description: description,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
        );

  const SkillExecutionEvent.toolCall(ToolCall call)
      : this._(type: SkillExecutionEventType.toolCall, toolCall: call);

  const SkillExecutionEvent.toolResult(
      String toolName, bool success, String output)
      : this._(
          type: SkillExecutionEventType.toolResult,
          toolName: toolName,
          toolSuccess: success,
          toolOutput: output,
        );

  const SkillExecutionEvent.output(String content)
      : this._(type: SkillExecutionEventType.output, output: content);

  const SkillExecutionEvent.done(SkillResult result)
      : this._(type: SkillExecutionEventType.done, result: result);

  const SkillExecutionEvent.error(String message)
      : this._(type: SkillExecutionEventType.error, error: message);

  @override
  String toString() {
    switch (type) {
      case SkillExecutionEventType.step:
        final step = stepNumber != null && totalSteps != null
            ? ' ($stepNumber/$totalSteps)'
            : '';
        return 'SkillStep: $description$step';
      case SkillExecutionEventType.toolCall:
        return 'SkillToolCall: ${toolCall?.name}';
      case SkillExecutionEventType.toolResult:
        return 'SkillToolResult: $toolName -> ${toolSuccess == true ? "OK" : "FAIL"}';
      case SkillExecutionEventType.output:
        return 'SkillOutput: ${output != null ? output!.substring(0, output!.length > 60 ? 60 : output!.length) : ""}...';
      case SkillExecutionEventType.done:
        return 'SkillDone: ${result?.success == true ? "OK" : "FAIL"}';
      case SkillExecutionEventType.error:
        return 'SkillError: $error';
    }
  }
}

enum SkillExecutionEventType {
  step,
  toolCall,
  toolResult,
  output,
  done,
  error,
}
