/// Agent skill system — reusable multi-step workflows.
///
/// Import this file to access all skill types:
/// ```dart
/// import 'package:nudgee/core/agent/skills/skills.dart';
/// ```
library;

export 'package:nudgee/core/agent/skills/skill_models.dart';
export 'package:nudgee/core/agent/skills/agent_skill.dart';
export 'package:nudgee/core/agent/skills/skill_registry.dart';
export 'package:nudgee/core/agent/skills/skill_executor.dart';
export 'package:nudgee/core/agent/skills/builtin_skills.dart';

import 'package:nudgee/core/agent/skills/builtin_skills.dart';
import 'package:nudgee/core/agent/skills/skill_registry.dart';

/// Registers all built-in skills into the given [registry].
///
/// Built-in skills:
/// - weekly_planner: plan a week of activities
/// - fitness_plan: create a personalized fitness plan
/// - daily_briefing: get a personalized daily summary
void registerBuiltinSkills(SkillRegistry registry) {
  registry.registerAll([
    WeeklyPlannerSkill(),
    FitnessPlanSkill(),
    DailyBriefingSkill(),
  ]);
}

/// Returns the list of all built-in skill IDs.
const List<String> builtinSkillIds = [
  'weekly_planner',
  'fitness_plan',
  'daily_briefing',
];
