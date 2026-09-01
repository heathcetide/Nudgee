import 'dart:async';

import 'package:nudgee/core/agent/skills/agent_skill.dart';
import 'package:nudgee/core/agent/skills/skill_models.dart';

/// Skill: weekly_planner
///
/// Plans a week of activities by:
/// 1. Querying the user's existing schedule
/// 2. Asking the LLM to analyze free time and suggest a plan
/// 3. Presenting the plan to the user
///
/// Uses tools: schedule.query
class WeeklyPlannerSkill extends AgentSkill {
  @override
  String get id => 'weekly_planner';

  @override
  String get name => 'Weekly Planner';

  @override
  String get summary =>
      'Plan a week of activities by analyzing your existing schedule '
      'and suggesting tasks for free time slots.';

  @override
  String get fullDescription =>
      'This skill helps you plan your week. It will:\n'
      '1. Query your current schedule for the upcoming week\n'
      '2. Analyze free time slots\n'
      '3. Use AI to suggest activities based on your preferences\n'
      '4. Present a weekly plan for your approval\n'
      '5. Optionally add suggested items to your schedule\n\n'
      'Use this when the user wants to plan their week, organize their '
      'schedule, or fill in free time with productive activities.';

  @override
  List<String> get keywords => [
        'weekly', 'week', 'plan', 'planner', 'schedule', 'organize',
        'plan my week', 'weekly plan',
      ];

  @override
  List<String> get allowedTools => ['schedule.query', 'schedule.add'];

  @override
  String get terminationCriteria =>
      'The skill completes when a weekly plan has been presented to the user.';

  @override
  Stream<SkillEvent> execute({
    required String userInput,
    required SkillContext context,
    Map<String, dynamic> params = const {},
  }) async* {
    final stepsCompleted = <String>[];
    final toolsUsed = <String>[];

    // Step 1: Query existing schedule
    yield const SkillEvent.step('Querying your current schedule...',
        stepNumber: 1, totalSteps: 4);
    stepsCompleted.add('query_schedule');

    final scheduleResult = await context.runTool('schedule.query', {});
    toolsUsed.add('schedule.query');
    yield SkillEvent.toolResult(
        'schedule.query', scheduleResult.success, scheduleResult.output ?? '');
    yield SkillEvent.output('Current schedule:\n${scheduleResult.output}');

    // Step 2: Analyze with LLM
    yield const SkillEvent.step('Analyzing free time and generating plan...',
        stepNumber: 2, totalSteps: 4);
    stepsCompleted.add('analyze');

    final memoryCtx = context.getMemoryContext();
    final analysisPrompt = 'You are a weekly planner. Based on the user\'s '
        'current schedule and preferences, suggest a plan for the week.\n\n'
        'Current schedule:\n${scheduleResult.output}\n\n'
        '${memoryCtx.isNotEmpty ? "User memory:\n$memoryCtx\n\n" : ""}'
        'User request: $userInput\n\n'
        'Generate a concise weekly plan with specific activities for each day. '
        'Format as a bullet list.';

    final analysis = await context.llmChat(analysisPrompt);
    yield SkillEvent.output(analysis);

    // Step 3: Present the plan
    yield const SkillEvent.step('Presenting your weekly plan...',
        stepNumber: 3, totalSteps: 4);
    stepsCompleted.add('present');

    yield SkillEvent.output('Here is your suggested weekly plan:\n\n$analysis');

    // Step 4: Done
    yield const SkillEvent.step('Weekly plan ready!', stepNumber: 4, totalSteps: 4);
    yield SkillEvent.done(SkillResult.ok(
      'Generated a weekly plan based on your current schedule.',
      data: {
        'plan': analysis,
        'scheduleSnapshot': scheduleResult.output,
      },
      stepsCompleted: stepsCompleted.length,
      toolsUsed: toolsUsed,
    ));
  }
}

/// Skill: fitness_plan
///
/// Creates a fitness plan by:
/// 1. Asking the user for their fitness goal (via LLM prompt)
/// 2. Generating a workout schedule
/// 3. Suggesting schedule items
class FitnessPlanSkill extends AgentSkill {
  @override
  String get id => 'fitness_plan';

  @override
  String get name => 'Fitness Plan';

  @override
  String get summary =>
      'Create a personalized fitness plan with workout schedules '
      'and reminders based on your goals.';

  @override
  String get fullDescription =>
      'This skill helps you create a fitness plan. It will:\n'
      '1. Understand your fitness goals (weight loss, muscle gain, etc.)\n'
      '2. Check your schedule for available time slots\n'
      '3. Generate a workout plan with specific exercises\n'
      '4. Suggest schedule items for workouts\n'
      '5. Recommend notification reminders\n\n'
      'Use this when the user wants to start exercising, create a workout '
      'routine, or plan fitness activities.';

  @override
  List<String> get keywords => [
        'fitness', 'workout', 'exercise', 'gym', 'running', 'muscle',
        'weight loss', 'health', 'training', 'fitness plan', 'get fit',
        'working out', 'work out',
      ];

  @override
  List<String> get allowedTools => [
        'schedule.query', 'schedule.add', 'notification.schedule',
      ];

  @override
  String get terminationCriteria =>
      'The skill completes when a fitness plan has been presented.';

  @override
  Stream<SkillEvent> execute({
    required String userInput,
    required SkillContext context,
    Map<String, dynamic> params = const {},
  }) async* {
    final stepsCompleted = <String>[];
    final toolsUsed = <String>[];

    // Step 1: Understand goals
    yield const SkillEvent.step('Understanding your fitness goals...',
        stepNumber: 1, totalSteps: 4);
    stepsCompleted.add('understand_goals');

    final memoryCtx = context.getMemoryContext();
    final goalPrompt = 'You are a fitness planner. The user said: "$userInput"\n\n'
        '${memoryCtx.isNotEmpty ? "User memory:\n$memoryCtx\n\n" : ""}'
        'Analyze the user\'s fitness goal and create a 3-day-per-week '
        'workout plan. Include specific exercises, durations, and suggested '
        'times. Keep it concise and actionable.';

    final plan = await context.llmChat(goalPrompt);
    yield SkillEvent.output(plan);

    // Step 2: Query schedule
    yield const SkillEvent.step('Checking your schedule for available times...',
        stepNumber: 2, totalSteps: 4);
    stepsCompleted.add('query_schedule');

    final scheduleResult = await context.runTool('schedule.query', {});
    toolsUsed.add('schedule.query');
    yield SkillEvent.output('Schedule checked: ${scheduleResult.output}');

    // Step 3: Generate final plan
    yield const SkillEvent.step('Generating your fitness plan...',
        stepNumber: 3, totalSteps: 4);
    stepsCompleted.add('generate');

    final finalPrompt = 'Based on this fitness plan:\n$plan\n\n'
        'And the user\'s schedule:\n${scheduleResult.output}\n\n'
        'Suggest 3 specific time slots this week for workouts. '
        'Format as: "Day HH:mm-HH:mm: activity"';

    final finalPlan = await context.llmChat(finalPrompt);
    yield SkillEvent.output('Your fitness plan:\n\n$finalPlan');

    // Step 4: Done
    yield const SkillEvent.step('Fitness plan ready!', stepNumber: 4, totalSteps: 4);
    yield SkillEvent.done(SkillResult.ok(
      'Generated a 3-day-per-week fitness plan with suggested time slots.',
      data: {
        'plan': plan,
        'suggestedSlots': finalPlan,
      },
      stepsCompleted: stepsCompleted.length,
      toolsUsed: toolsUsed,
    ));
  }
}

/// Skill: daily_briefing
///
/// Generates a daily briefing by:
/// 1. Querying today's schedule
/// 2. Using memory for personalization
/// 3. Generating a summary with LLM
class DailyBriefingSkill extends AgentSkill {
  @override
  String get id => 'daily_briefing';

  @override
  String get name => 'Daily Briefing';

  @override
  String get summary =>
      'Get a personalized daily briefing with your schedule, priorities, '
      'and a summary of what to focus on today.';

  @override
  String get fullDescription =>
      'This skill generates a daily briefing. It will:\n'
      '1. Query today\'s schedule\n'
      '2. Review your memory (preferences, recent sessions)\n'
      '3. Generate a personalized briefing with priorities\n'
      '4. Present a concise summary\n\n'
      'Use this when the user asks for a daily summary, morning briefing, '
      '"what\'s on today", or wants to know their schedule.';

  @override
  List<String> get keywords => [
        'briefing', 'daily', 'today', 'morning', 'summary',
        "what's on", 'agenda', 'daily briefing', 'good morning',
      ];

  @override
  List<String> get allowedTools => ['schedule.query'];

  @override
  String get terminationCriteria =>
      'The skill completes when the daily briefing has been presented.';

  @override
  Stream<SkillEvent> execute({
    required String userInput,
    required SkillContext context,
    Map<String, dynamic> params = const {},
  }) async* {
    final stepsCompleted = <String>[];
    final toolsUsed = <String>[];

    // Step 1: Query today's schedule
    yield const SkillEvent.step('Checking today\'s schedule...',
        stepNumber: 1, totalSteps: 3);
    stepsCompleted.add('query_schedule');

    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final scheduleResult =
        await context.runTool('schedule.query', {'date': dateStr});
    toolsUsed.add('schedule.query');
    yield SkillEvent.output('Today\'s schedule: ${scheduleResult.output}');

    // Step 2: Generate briefing with LLM
    yield const SkillEvent.step('Generating your personalized briefing...',
        stepNumber: 2, totalSteps: 3);
    stepsCompleted.add('generate_briefing');

    final memoryCtx = context.getMemoryContext();
    final briefingPrompt = 'You are a daily briefing generator. Create a concise, '
        'motivating morning briefing for the user.\n\n'
        'Today\'s schedule:\n${scheduleResult.output}\n\n'
        '${memoryCtx.isNotEmpty ? "User memory:\n$memoryCtx\n\n" : ""}'
        'Generate a briefing with:\n'
        '1. A brief greeting\n'
        '2. Today\'s key tasks (from schedule)\n'
        '3. One priority focus for the day\n'
        'Keep it under 150 words.';

    final briefing = await context.llmChat(briefingPrompt);
    yield SkillEvent.output(briefing);

    // Step 3: Done
    yield const SkillEvent.step('Daily briefing ready!', stepNumber: 3, totalSteps: 3);
    yield SkillEvent.done(SkillResult.ok(
      'Generated a personalized daily briefing.',
      data: {
        'briefing': briefing,
        'date': dateStr,
        'scheduleSnapshot': scheduleResult.output,
      },
      stepsCompleted: stepsCompleted.length,
      toolsUsed: toolsUsed,
    ));
  }
}
