import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent_event.dart';
import 'package:nudgee/core/agent/skills/skills.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

void main() {
  group('SkillModels', () {
    test('SkillResult.ok creates successful result', () {
      final result = SkillResult.ok(
        'Plan generated',
        data: {'plan': 'test'},
        stepsCompleted: 3,
        toolsUsed: const ['schedule.query'],
      );

      expect(result.success, true);
      expect(result.summary, 'Plan generated');
      expect(result.data, {'plan': 'test'});
      expect(result.stepsCompleted, 3);
      expect(result.toolsUsed, ['schedule.query']);
      expect(result.error, isNull);
    });

    test('SkillResult.failed creates error result', () {
      final result = SkillResult.failed('Something went wrong',
          stepsCompleted: 1, toolsUsed: const ['schedule.query']);

      expect(result.success, false);
      expect(result.summary, 'Skill failed: Something went wrong');
      expect(result.error, 'Something went wrong');
      expect(result.stepsCompleted, 1);
    });

    test('SkillResult toString', () {
      expect(
        SkillResult.ok('ok', stepsCompleted: 2, toolsUsed: const ['t1'])
            .toString(),
        'SkillResult(ok, 2 steps, 1 tools)',
      );
      expect(
        SkillResult.failed('err').toString(),
        'SkillResult(fail, 0 steps, 0 tools)',
      );
    });
  });

  group('SkillEvent', () {
    test('SkillEvent.step creates step event', () {
      const event = SkillEvent.step('Step 1', stepNumber: 1, totalSteps: 3);
      expect(event, isA<SkillStepEvent>());
      final step = event as SkillStepEvent;
      expect(step.description, 'Step 1');
      expect(step.stepNumber, 1);
      expect(step.totalSteps, 3);
    });

    test('SkillEvent.toolCall creates tool call event', () {
      const call = ToolCall(
          id: 'call_1', name: 'schedule.query', arguments: {});
      final event = SkillEvent.toolCall(call);
      expect(event, isA<SkillToolCallEvent>());
      expect((event as SkillToolCallEvent).call.name, 'schedule.query');
    });

    test('SkillEvent.toolResult creates tool result event', () {
      const event = SkillEvent.toolResult('schedule.query', true, 'OK');
      expect(event, isA<SkillToolResultEvent>());
      final tr = event as SkillToolResultEvent;
      expect(tr.toolName, 'schedule.query');
      expect(tr.success, true);
      expect(tr.output, 'OK');
    });

    test('SkillEvent.output creates output event', () {
      const event = SkillEvent.output('Plan ready');
      expect(event, isA<SkillOutputEvent>());
      expect((event as SkillOutputEvent).content, 'Plan ready');
    });

    test('SkillEvent.done creates done event', () {
      final result = SkillResult.ok('Done');
      final event = SkillEvent.done(result);
      expect(event, isA<SkillDoneEvent>());
      expect((event as SkillDoneEvent).result.success, true);
    });

    test('SkillEvent.error creates error event', () {
      const event = SkillEvent.error('Failed');
      expect(event, isA<SkillErrorEvent>());
      expect((event as SkillErrorEvent).message, 'Failed');
    });
  });

  group('SkillSummary', () {
    test('creates summary with all fields', () {
      const summary = SkillSummary(
        id: 'weekly_planner',
        name: 'Weekly Planner',
        summary: 'Plan your week',
        keywords: ['week', 'plan'],
      );

      expect(summary.id, 'weekly_planner');
      expect(summary.name, 'Weekly Planner');
      expect(summary.summary, 'Plan your week');
      expect(summary.keywords, ['week', 'plan']);
    });

    test('toString returns id and name', () {
      const summary = SkillSummary(
          id: 'fitness', name: 'Fitness', summary: 'Workout plan');
      expect(summary.toString(), 'SkillSummary(fitness: Fitness)');
    });
  });

  group('SkillRegistry', () {
    late SkillRegistry registry;

    setUp(() {
      registry = SkillRegistry();
      registerBuiltinSkills(registry);
    });

    test('registers all builtin skills', () {
      expect(registry.length, 3);
      expect(registry.contains('weekly_planner'), true);
      expect(registry.contains('fitness_plan'), true);
      expect(registry.contains('daily_briefing'), true);
    });

    test('getById returns skill', () {
      final skill = registry.getById('weekly_planner');
      expect(skill, isNotNull);
      expect(skill!.id, 'weekly_planner');
      expect(skill.name, 'Weekly Planner');
    });

    test('getById returns null for unknown id', () {
      expect(registry.getById('unknown'), isNull);
    });

    test('all returns all skills', () {
      expect(registry.all.length, 3);
    });

    test('summaries returns all summaries', () {
      final summaries = registry.summaries();
      expect(summaries.length, 3);
      expect(summaries.any((s) => s.id == 'weekly_planner'), true);
      expect(summaries.any((s) => s.id == 'fitness_plan'), true);
      expect(summaries.any((s) => s.id == 'daily_briefing'), true);
    });

    test('matchByRules matches weekly planner keywords', () {
      final matches = registry.matchByRules('Help me plan my week');
      expect(matches, isNotEmpty);
      expect(matches.any((s) => s.id == 'weekly_planner'), true);
    });

    test('matchByRules matches fitness keywords', () {
      final matches =
          registry.matchByRules('I want to start working out and get fit');
      expect(matches, isNotEmpty);
      expect(matches.any((s) => s.id == 'fitness_plan'), true);
    });

    test('matchByRules matches daily briefing keywords', () {
      final matches =
          registry.matchByRules('Give me a morning briefing for today');
      expect(matches, isNotEmpty);
      expect(matches.any((s) => s.id == 'daily_briefing'), true);
    });

    test('matchByRules returns empty for unrelated input', () {
      final matches = registry.matchByRules('What is 2 + 2?');
      expect(matches, isEmpty);
    });

    test('unregister removes skill', () {
      registry.unregister('weekly_planner');
      expect(registry.length, 2);
      expect(registry.contains('weekly_planner'), false);
    });

    test('clear removes all skills', () {
      registry.clear();
      expect(registry.length, 0);
    });

    test('registerAll registers multiple skills', () {
      registry.clear();
      registry.registerAll([
        WeeklyPlannerSkill(),
        FitnessPlanSkill(),
      ]);
      expect(registry.length, 2);
    });
  });

  group('AgentSkill — isApplicable', () {
    test('WeeklyPlannerSkill matches planning keywords', () {
      final skill = WeeklyPlannerSkill();
      expect(skill.isApplicable('plan my week'), true);
      expect(skill.isApplicable('organize my schedule'), true);
      expect(skill.isApplicable('what is the weather'), false);
    });

    test('FitnessPlanSkill matches fitness keywords', () {
      final skill = FitnessPlanSkill();
      expect(skill.isApplicable('I want to exercise'), true);
      expect(skill.isApplicable('create a workout plan'), true);
      expect(skill.isApplicable('plan my week'), false);
    });

    test('DailyBriefingSkill matches briefing keywords', () {
      final skill = DailyBriefingSkill();
      expect(skill.isApplicable('give me a daily briefing'), true);
      expect(skill.isApplicable("what's on today"), true);
      expect(skill.isApplicable('good morning'), true);
      expect(skill.isApplicable('add a schedule item'), false);
    });

    test('skillSummary returns correct summary', () {
      final skill = WeeklyPlannerSkill();
      final summary = skill.skillSummary;
      expect(summary.id, 'weekly_planner');
      expect(summary.name, 'Weekly Planner');
      expect(summary.keywords, isNotEmpty);
    });

    test('allowedTools are correct', () {
      expect(WeeklyPlannerSkill().allowedTools,
          containsAll(['schedule.query', 'schedule.add']));
      expect(FitnessPlanSkill().allowedTools,
          containsAll(['schedule.query', 'schedule.add', 'notification.schedule']));
      expect(DailyBriefingSkill().allowedTools, ['schedule.query']);
    });
  });

  group('SkillContext', () {
    test('creates context with all fields', () {
      const context = SkillContext(
        runTool: _dummyRunTool,
        llmChat: _dummyLlmChat,
        getMemoryContext: _dummyGetMemory,
        userId: 'test_user',
      );

      expect(context.userId, 'test_user');
    });
  });
}

Future<ToolResult> _dummyRunTool(String name, Map<String, dynamic> args) async {
  return const ToolResult.success('dummy');
}

Future<String> _dummyLlmChat(String prompt, {String? systemPrompt}) async {
  return 'dummy response';
}

String _dummyGetMemory() => 'dummy memory';
