import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent.dart';
import 'package:nudgee/core/agent/skills/skills.dart';

const String qiniuApiKey = 'sk-c3qxB9P3y1hq9xuiqOduUg';
const String qiniuBaseUrl = 'https://llmapi.qiniu.io/v1';
const String qiniuModel = 'gpt-5.4-mini';

void main() {
  group('Phase 4 — Skill System Integration (Real API)', () {
    late DeepSeekClient client;
    late ToolRegistry toolRegistry;
    late SkillRegistry skillRegistry;
    late SkillMatcher skillMatcher;
    late SkillExecutor skillExecutor;

    setUpAll(() {
      client = DeepSeekClient(
        apiKey: qiniuApiKey,
        baseUrl: qiniuBaseUrl,
        defaultModel: qiniuModel,
      );
      toolRegistry = ToolRegistry();
      registerBuiltinTools(toolRegistry);
      skillRegistry = SkillRegistry();
      registerBuiltinSkills(skillRegistry);
      skillMatcher = SkillMatcher(
        llmClient: client,
        registry: skillRegistry,
        model: qiniuModel,
      );
      skillExecutor = SkillExecutor(
        toolRegistry: toolRegistry,
        llmClient: client,
        llmModel: qiniuModel,
      );
    });

    tearDownAll(() {
      client.dispose();
    });

    // ── LLM-based skill matching ──────────────────────────────────────────

    test('1. SkillMatcher matches weekly_planner via LLM', () async {
      final skill = await skillMatcher.match('Help me plan my upcoming week');
      expect(skill, isNotNull);
      expect(skill!.id, 'weekly_planner');
      print('\n  -> matched: ${skill.id} (${skill.name})');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('2. SkillMatcher matches fitness_plan via LLM', () async {
      final skill = await skillMatcher.match(
          'I want to start exercising and create a workout routine');
      expect(skill, isNotNull);
      expect(skill!.id, 'fitness_plan');
      print('\n  -> matched: ${skill.id} (${skill.name})');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('3. SkillMatcher matches daily_briefing via LLM', () async {
      final skill =
          await skillMatcher.match('Give me a morning briefing for today');
      expect(skill, isNotNull);
      expect(skill!.id, 'daily_briefing');
      print('\n  -> matched: ${skill.id} (${skill.name})');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('4. SkillMatcher returns null for unrelated input', () async {
      final skill = await skillMatcher.match('What is the capital of France?');
      expect(skill, isNull);
      print('\n  -> no skill matched (expected)');
    }, timeout: const Timeout(Duration(seconds: 30)));

    // ── Skill execution ───────────────────────────────────────────────────

    test('5. WeeklyPlannerSkill executes and produces a plan', () async {
      final events = <SkillExecutionEvent>[];
      await for (final event in skillExecutor.executeSkill(
        skill: skillRegistry.getById('weekly_planner')!,
        userInput: 'Plan my week with focus on productivity',
      )) {
        events.add(event);
      }

      // Should have step events
      final steps = events.where((e) => e.type == SkillExecutionEventType.step);
      expect(steps.length, greaterThanOrEqualTo(3));

      // Should have output events
      final outputs =
          events.where((e) => e.type == SkillExecutionEventType.output);
      expect(outputs, isNotEmpty);

      // Should end with done
      final done =
          events.where((e) => e.type == SkillExecutionEventType.done).first;
      expect(done.result, isNotNull);
      expect(done.result!.success, true);
      expect(done.result!.stepsCompleted, greaterThanOrEqualTo(3));
      expect(done.result!.toolsUsed, contains('schedule.query'));

      // The plan should mention days of the week
      final allOutput = outputs.map((e) => e.output ?? '').join(' ');
      expect(allOutput.length, greaterThan(50));

      print('\n  -> events: ${events.length}');
      print('  -> steps: ${steps.length}');
      print('  -> tools used: ${done.result!.toolsUsed}');
      print('  -> result: ${done.result!.summary}');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('6. FitnessPlanSkill executes and produces a workout plan', () async {
      final events = <SkillExecutionEvent>[];
      await for (final event in skillExecutor.executeSkill(
        skill: skillRegistry.getById('fitness_plan')!,
        userInput: 'I want to lose weight and build muscle',
      )) {
        events.add(event);
      }

      final done =
          events.where((e) => e.type == SkillExecutionEventType.done).first;
      expect(done.result!.success, true);
      expect(done.result!.stepsCompleted, greaterThanOrEqualTo(3));

      final outputs =
          events.where((e) => e.type == SkillExecutionEventType.output);
      final allOutput = outputs.map((e) => e.output ?? '').join(' ');

      // Should mention fitness-related terms
      final lower = allOutput.toLowerCase();
      expect(
        lower.contains('workout') ||
            lower.contains('exercise') ||
            lower.contains('training') ||
            lower.contains('fitness') ||
            lower.contains('cardio') ||
            lower.contains('strength'),
        true,
        reason: 'Plan should mention fitness terms',
      );

      print('\n  -> result: ${done.result!.summary}');
      print('  -> tools used: ${done.result!.toolsUsed}');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('7. DailyBriefingSkill executes and produces a briefing', () async {
      final events = <SkillExecutionEvent>[];
      await for (final event in skillExecutor.executeSkill(
        skill: skillRegistry.getById('daily_briefing')!,
        userInput: 'Good morning, what do I have today?',
      )) {
        events.add(event);
      }

      final done =
          events.where((e) => e.type == SkillExecutionEventType.done).first;
      expect(done.result!.success, true);
      expect(done.result!.toolsUsed, contains('schedule.query'));

      final outputs =
          events.where((e) => e.type == SkillExecutionEventType.output);
      final allOutput = outputs.map((e) => e.output ?? '').join(' ');
      expect(allOutput.length, greaterThan(20));

      print('\n  -> result: ${done.result!.summary}');
      print('  -> briefing preview: ${allOutput.substring(0, allOutput.length > 100 ? 100 : allOutput.length)}...');
    }, timeout: const Timeout(Duration(seconds: 60)));

    // ── SkillExecutor tool restriction ────────────────────────────────────

    test('8. SkillExecutor blocks disallowed tools', () async {
      // Create a mock skill that tries to use a disallowed tool
      final restrictedSkill = _RestrictedSkill();

      final events = <SkillExecutionEvent>[];
      await for (final event in skillExecutor.executeSkill(
        skill: restrictedSkill,
        userInput: 'test',
      )) {
        events.add(event);
      }

      // Should have a tool result event with failure
      final toolResults = events
          .where((e) => e.type == SkillExecutionEventType.toolResult)
          .toList();
      expect(toolResults, isNotEmpty);
      expect(toolResults.first.toolSuccess, false);
      expect(
        toolResults.first.toolOutput,
        contains('not allowed'),
      );

      print('\n  -> tool blocked: ${toolResults.first.toolOutput}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    // ── AgentHarness with skills ──────────────────────────────────────────

    test('9. AgentHarness.matchSkill matches via LLM', () async {
      final harness = AgentHarness(
        llmClient: client,
        toolRegistry: toolRegistry,
        skillRegistry: skillRegistry,
        permissionContext:
            PermissionContext.fixed(PermissionMode.bypassPermissions),
        llmModel: qiniuModel,
      );

      final skill = await harness.matchSkill('Plan my week ahead');
      expect(skill, isNotNull);
      expect(skill!.id, 'weekly_planner');

      print('\n  -> harness matched: ${skill.id}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('10. AgentHarness.executeSkill runs daily_briefing', () async {
      final harness = AgentHarness(
        llmClient: client,
        toolRegistry: toolRegistry,
        skillRegistry: skillRegistry,
        permissionContext:
            PermissionContext.fixed(PermissionMode.bypassPermissions),
        llmModel: qiniuModel,
      );

      final events = <SkillExecutionEvent>[];
      await for (final event in harness.executeSkill(
        skillId: 'daily_briefing',
        userInput: 'What do I have today?',
      )) {
        events.add(event);
      }

      final done =
          events.where((e) => e.type == SkillExecutionEventType.done).first;
      expect(done.result!.success, true);

      print('\n  -> harness executed skill, result: ${done.result!.summary}');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('11. AgentHarness.runWithSkills — full skill-then-agent flow',
        () async {
      final harness = AgentHarness(
        llmClient: client,
        toolRegistry: toolRegistry,
        skillRegistry: skillRegistry,
        permissionContext:
            PermissionContext.fixed(PermissionMode.bypassPermissions),
        llmModel: qiniuModel,
      );
      harness.registerAgent(AgentConfig(
        id: 'skill-agent',
        name: 'Skill Agent',
        systemPrompt: 'You are a personal assistant. '
            'When skill output is provided, use it to give a helpful response.',
        model: qiniuModel,
        toolNames: const [],
        maxSteps: 1,
      ));

      final events = <AgentEvent>[];
      await for (final event in harness.runWithSkills(
        userInput: 'Give me a daily briefing for today',
      )) {
        events.add(event);
      }

      final done = events.whereType<DoneEvent>().first;
      expect(done.finalReply, isNotEmpty);

      print('\n  -> final reply: ${done.finalReply}');

      // The reply should be a briefing (not just a generic response)
      final lower = done.finalReply.toLowerCase();
      expect(
        lower.contains('today') ||
            lower.contains('schedule') ||
            lower.contains('briefing') ||
            lower.contains('morning') ||
            lower.contains('plan'),
        true,
        reason: 'Reply should be briefing-related',
      );
    }, timeout: const Timeout(Duration(seconds: 90)));
  });
}

/// A test skill that tries to use a disallowed tool.
class _RestrictedSkill extends AgentSkill {
  @override
  String get id => 'restricted_test';

  @override
  String get name => 'Restricted Test';

  @override
  String get summary => 'Test skill for tool restriction';

  @override
  String get fullDescription => 'Test skill';

  @override
  List<String> get keywords => const ['restricted_test'];

  @override
  List<String> get allowedTools => const ['schedule.query']; // only this allowed

  @override
  String get terminationCriteria => 'immediate';

  @override
  Stream<SkillEvent> execute({
    required String userInput,
    required SkillContext context,
    Map<String, dynamic> params = const {},
  }) async* {
    yield const SkillEvent.step('Trying disallowed tool...', stepNumber: 1, totalSteps: 1);

    // Try to use a tool that's NOT in allowedTools
    final result = await context.runTool('todo.write', {'todos': []});
    yield SkillEvent.toolResult('todo.write', result.success, result.toLlmContent());

    yield SkillEvent.done(SkillResult.ok(
      'Test complete',
      stepsCompleted: 1,
      toolsUsed: const [],
    ));
  }
}
