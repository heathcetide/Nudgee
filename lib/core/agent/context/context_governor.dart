import 'package:nudgee/core/agent/agent_config.dart';
import 'package:nudgee/core/agent/compaction/microcompact.dart';
import 'package:nudgee/core/agent/memory/memory_manager.dart';
import 'package:nudgee/core/agent/providers/llm_client.dart';
import 'package:nudgee/core/agent/sanitize/message_sanitizer.dart';

/// Context governor — assembles and manages the LLM's context window.
///
/// Responsibilities:
/// 1. Prepend the system prompt
/// 2. Inject knowledge/memory (Phase 3)
/// 3. Apply microcompact to compress old tool results
/// 4. Sanitize messages to fix structural issues
/// 5. Enforce context window limits
class ContextGovernor {
  /// System prompt for the Agent.
  final String systemPrompt;

  /// Maximum context window size in tokens (model-dependent).
  final int contextWindow;

  /// Microcompact instance for local compression.
  final Microcompact _microcompact;

  /// Message sanitizer for fixing broken history.
  final MessageSanitizer _sanitizer;

  /// Optional memory manager for injecting long-term memory into the prompt.
  final MemoryManager? memoryManager;

  /// Creates a [ContextGovernor].
  ContextGovernor({
    required this.systemPrompt,
    this.contextWindow = 64000,
    Microcompact? microcompact,
    MessageSanitizer? sanitizer,
    this.memoryManager,
  })  : _microcompact = microcompact ?? Microcompact(),
        _sanitizer = sanitizer ?? MessageSanitizer();

  /// Creates from [AgentConfig].
  factory ContextGovernor.fromConfig(
    AgentConfig config, {
    MemoryManager? memoryManager,
  }) {
    return ContextGovernor(
      systemPrompt: config.systemPrompt,
      contextWindow: 64000,  // DeepSeek default
      memoryManager: memoryManager,
    );
  }

  /// Builds the final message list to send to the LLM.
  ///
  /// Steps:
  /// 1. Sanitize the conversation history
  /// 2. Apply microcompact
  /// 3. Return messages (system prompt is passed separately to LLM client)
  List<LlmMessage> buildContext(List<LlmMessage> history) {
    // 1. Sanitize
    var messages = _sanitizer.sanitize(history);

    // 2. Microcompact
    messages = _microcompact.compact(messages);

    // 3. Enforce window (rough estimate)
    final tokens = _microcompact.estimateTotalTokens(messages);
    if (tokens > contextWindow) {
      // Aggressive: drop oldest messages (keep last 10)
      final keepCount = messages.length > 10 ? 10 : messages.length;
      messages = messages.sublist(messages.length - keepCount);
    }

    return messages;
  }

  /// Returns the system prompt augmented with memory and extra context.
  ///
  /// Memory injection order:
  /// 1. Base system prompt
  /// 2. Long-term memory (user profile, preferences, recent sessions)
  /// 3. Extra context (passed by caller)
  String buildSystemPrompt({String? extraContext}) {
    var prompt = systemPrompt;

    // Inject memory context (Phase 3)
    if (memoryManager != null && memoryManager!.isCacheLoaded) {
      final memoryContext = memoryManager!.buildMemoryContext();
      if (memoryContext.isNotEmpty) {
        prompt = '$prompt\n\n--- User Memory ---\n$memoryContext';
      }
    }

    if (extraContext != null && extraContext.isNotEmpty) {
      prompt = '$prompt\n\n$extraContext';
    }
    return prompt;
  }

  /// Estimates the current token usage of [history].
  int estimateTokens(List<LlmMessage> history) {
    final systemTokens = _estimateString(systemPrompt);
    final messageTokens = _microcompact.estimateTotalTokens(history);
    return systemTokens + messageTokens;
  }

  int _estimateString(String text) {
    if (text.isEmpty) return 0;
    return (text.length + 3) ~/ 4;
  }
}
