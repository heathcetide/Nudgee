import 'package:nudgee/core/agent/skills/skill_models.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

/// Context provided to skills during execution.
///
/// Contains references to the services the skill needs:
/// - [runTool]: executes a tool by name with arguments
/// - [llmChat]: calls the LLM with a prompt and returns the response
/// - [memoryContext]: current memory context string (from MemoryManager)
class SkillContext {
  /// Executes a tool by name.
  final Future<ToolResult> Function(String name, Map<String, dynamic> args) runTool;

  /// Calls the LLM with a prompt and returns the text response.
  final Future<String> Function(String prompt, {String? systemPrompt}) llmChat;

  /// Current memory context string (if available).
  final String Function() getMemoryContext;

  /// User ID for this execution.
  final String userId;

  /// Creates a [SkillContext].
  const SkillContext({
    required this.runTool,
    required this.llmChat,
    required this.getMemoryContext,
    this.userId = 'default',
  });
}

/// A reusable programmatic capability — higher-level than a tool.
///
/// While a [AgentTool] is an atomic operation (e.g. "add a schedule item"),
/// a skill is a multi-step workflow (e.g. "plan a week of fitness activities"
/// = query schedule + analyze free time + generate plan + batch add + notify).
///
/// Skills use progressive disclosure:
/// - [summary] is shown to the LLM first (for matching)
/// - [fullDescription] is loaded only when the skill is selected
///
/// Skills are matched by:
/// 1. Rule-based keyword matching ([keywords] + [isApplicable])
/// 2. LLM-based judgment (via [SkillMatcher])
abstract class AgentSkill {
  /// Unique skill ID (e.g. "weekly_planner").
  String get id;

  /// Human-readable name (visible to LLM for trigger judgment).
  String get name;

  /// Short description for progressive disclosure.
  String get summary;

  /// Full description (loaded after skill is selected).
  String get fullDescription;

  /// Keywords for rule-based matching.
  List<String> get keywords;

  /// Tools this skill is allowed to use.
  List<String> get allowedTools;

  /// Termination criteria (when to stop).
  String get terminationCriteria;

  /// Returns a [SkillSummary] for progressive disclosure.
  SkillSummary get skillSummary => SkillSummary(
        id: id,
        name: name,
        summary: summary,
        keywords: keywords,
      );

  /// Rule-based applicability check.
  ///
  /// Override this for fast keyword matching. For LLM-based matching,
  /// use [SkillMatcher] which calls the LLM with all skill summaries.
  bool isApplicable(String userInput) {
    final lower = userInput.toLowerCase();
    return keywords.any((k) => lower.contains(k.toLowerCase()));
  }

  /// Executes the skill, emitting a stream of [SkillEvent]s.
  ///
  /// The skill should:
  /// 1. Emit [SkillStepEvent] for each workflow step
  /// 2. Call [context.runTool] to execute tools
  /// 3. Emit [SkillOutputEvent] for intermediate results
  /// 4. Emit [SkillDoneEvent] when complete
  Stream<SkillEvent> execute({
    required String userInput,
    required SkillContext context,
    Map<String, dynamic> params = const {},
  });
}
