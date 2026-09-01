import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent.dart';
import 'package:nudgee/core/agent/memory/memory.dart';
import 'package:nudgee/core/agent/skills/skills.dart';

import '../memory/mock_memory_storage.dart';

import '../test_env.dart';

// LLM config from environment — tests skip if NUDGEE_LLM_API_KEY not set.
final String qiniuApiKey = TestEnv.llmApiKey ?? '';
final String qiniuBaseUrl = TestEnv.llmBaseUrl;
final String qiniuModel = TestEnv.llmModel;

void main() {
  if (!TestEnv.hasLlmKey) return; // Skip: no NUDGEE_LLM_API_KEY
  group('Cross-Layer Integration — Phase 1+2+3+4 (Full Stack)', () {
    late DeepSeekClient client;
    late ToolRegistry toolRegistry;
    late SkillRegistry skillRegistry;
    late MockMemoryStorage storage;
    late MemoryManager memoryManager;

    setUpAll(() {
      // Skip setup if no API key — individual tests will also check.
      if (!TestEnv.hasLlmKey) return;
      client = DeepSeekClient(
        apiKey: qiniuApiKey,
        baseUrl: qiniuBaseUrl,
        defaultModel: qiniuModel,
      );
      toolRegistry = ToolRegistry();
      registerBuiltinTools(toolRegistry);
      skillRegistry = SkillRegistry();
      registerBuiltinSkills(skillRegistry);
    });

    tearDownAll(() {
      client.dispose();
    });

    setUp(() {
      storage = MockMemoryStorage();
      memoryManager = MemoryManager(
        storage: storage,
        llmClient: client,
        llmModel: qiniuModel,
      );
    });

    // ── L3+L4: Memory-informed skill execution ────────────────────────────

    test('L3+L4: Skill uses memory context for personalization', () async {
      // Pre-populate memory
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'fact.occupation',
        category: MemoryCategory.fact,
        value: 'The user is a software engineer',
        confidence: 0.9,
      ));
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'preference.focus',
        category: MemoryCategory.preference,
        value: 'The user values deep work and focused productivity',
        confidence: 0.85,
      ));

      final executor = SkillExecutor(
        toolRegistry: toolRegistry,
        llmClient: client,
        llmModel: qiniuModel,
      );

      final events = <SkillExecutionEvent>[];
      await for (final event in executor.executeSkill(
        skill: skillRegistry.getById('daily_briefing')!,
        userInput: 'Good morning, what do I have today?',
        memoryContext: () => memoryManager.buildMemoryContext(),
      )) {
        events.add(event);
      }

      final done =
          events.where((e) => e.type == SkillExecutionEventType.done).first;
      expect(done.result!.success, true);

      // The briefing should be influenced by memory
      final outputs =
          events.where((e) => e.type == SkillExecutionEventType.output);
      final allOutput = outputs.map((e) => e.output ?? '').join(' ');
      final lower = allOutput.toLowerCase();

      print('\n  -> briefing:\n$allOutput');

      // Should mention something related to the user's profile
      expect(
        lower.contains('engineer') ||
            lower.contains('deep work') ||
            lower.contains('focus') ||
            lower.contains('productivity'),
        true,
        reason: 'Briefing should be personalized using memory',
      );
    }, timeout: const Timeout(Duration(seconds: 60)));

    // ── L1+L4: AgentHarness with skill matching + memory ──────────────────

    test('L1+L3+L4: Harness matches skill, uses memory, generates response',
        () async {
      // Populate memory
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'fact.name',
        category: MemoryCategory.fact,
        value: 'The user\'s name is Eve',
        confidence: 0.95,
      ));
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'preference.reply_style',
        category: MemoryCategory.preference,
        value: 'The user prefers concise and friendly responses',
        confidence: 0.8,
      ));

      final harness = AgentHarness(
        llmClient: client,
        toolRegistry: toolRegistry,
        skillRegistry: skillRegistry,
        permissionContext:
            PermissionContext.fixed(PermissionMode.bypassPermissions),
        llmModel: qiniuModel,
      );

      harness.registerAgent(AgentConfig(
        id: 'full-stack-agent',
        name: 'Full Stack Agent',
        systemPrompt: 'You are a personal assistant. '
            'Use the user memory and skill output to personalize responses. '
            'Follow the user\'s name and reply style preferences.',
        model: qiniuModel,
        toolNames: const [],
        maxSteps: 1,
      ));

      // Match a skill
      final matchedSkill = await harness.matchSkill('Plan my week');
      expect(matchedSkill, isNotNull);
      expect(matchedSkill!.id, 'weekly_planner');

      // Execute the skill with memory context
      final skillEvents = <SkillExecutionEvent>[];
      await for (final event in harness.executeSkill(
        skillId: 'weekly_planner',
        userInput: 'Plan my week with focus on deep work',
        memoryContext: () => memoryManager.buildMemoryContext(),
      )) {
        skillEvents.add(event);
      }

      final skillDone = skillEvents
          .where((e) => e.type == SkillExecutionEventType.done)
          .first;
      expect(skillDone.result!.success, true);

      // Now run the agent with the skill output + memory as context
      final memoryCtx = memoryManager.buildMemoryContext();
      final agentEvents = <AgentEvent>[];
      await for (final event in harness.run(
        userInput: 'Plan my week with focus on deep work',
        extraSystemContext: '--- User Memory ---\n$memoryCtx\n\n'
            '--- Skill Output ---\n'
            '${skillEvents.where((e) => e.type == SkillExecutionEventType.output).map((e) => e.output).join('\n')}',
      )) {
        agentEvents.add(event);
      }

      final done = agentEvents.whereType<DoneEvent>().first;
      print('\n  -> agent reply: ${done.finalReply}');

      expect(done.finalReply, isNotEmpty);
      // Should use the user's name from memory
      expect(
        done.finalReply.toLowerCase().contains('eve'),
        true,
        reason: 'Agent should use name "Eve" from memory',
      );
    }, timeout: const Timeout(Duration(seconds: 120)));

    // ── L1+L2+L3+L4: Full stack with runWithSkills ────────────────────────

    test('L1+L2+L3+L4: runWithSkills — match + execute + memory + agent', () async {
      // Populate memory
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'fact.name',
        category: MemoryCategory.fact,
        value: 'The user\'s name is Frank',
        confidence: 0.95,
      ));
      await memoryManager.saveMemory(MemoryItem.now(
        key: 'preference.fitness_goal',
        category: MemoryCategory.preference,
        value: 'The user wants to lose 5kg in 2 months',
        confidence: 0.9,
      ));

      final harness = AgentHarness(
        llmClient: client,
        toolRegistry: toolRegistry,
        skillRegistry: skillRegistry,
        permissionContext:
            PermissionContext.fixed(PermissionMode.bypassPermissions),
        llmModel: qiniuModel,
      );

      harness.registerAgent(AgentConfig(
        id: 'full-stack-2',
        name: 'Full Stack 2',
        systemPrompt: 'You are a personal fitness and productivity assistant. '
            'Use the user memory and skill output to personalize. '
            'Address the user by name.',
        model: qiniuModel,
        toolNames: const [],
        maxSteps: 1,
      ));

      final events = <AgentEvent>[];
      await for (final event in harness.runWithSkills(
        userInput: 'I want to start working out to lose weight',
        memoryContext: () => memoryManager.buildMemoryContext(),
      )) {
        events.add(event);
      }

      final done = events.whereType<DoneEvent>().first;
      print('\n  -> final reply:\n${done.finalReply}');

      expect(done.finalReply, isNotEmpty);

      // Should use the user's name
      expect(
        done.finalReply.toLowerCase().contains('frank'),
        true,
        reason: 'Agent should address user as "Frank"',
      );

      // Should mention fitness/exercise (from skill)
      final lower = done.finalReply.toLowerCase();
      expect(
        lower.contains('workout') ||
            lower.contains('exercise') ||
            lower.contains('fitness') ||
            lower.contains('training'),
        true,
        reason: 'Response should include fitness content from skill',
      );
    }, timeout: const Timeout(Duration(seconds: 120)));

    // ── Skill lifecycle: extract memory from skill output ─────────────────

    test('L2+L3+L4: Extract memory from skill-executed conversation', () async {
      // Run a skill
      final executor = SkillExecutor(
        toolRegistry: toolRegistry,
        llmClient: client,
        llmModel: qiniuModel,
      );

      final skillOutputs = <String>[];
      await for (final event in executor.executeSkill(
        skill: skillRegistry.getById('fitness_plan')!,
        userInput: 'I\'m a beginner who wants to start running 3 times a week',
      )) {
        if (event.type == SkillExecutionEventType.output && event.output != null) {
          skillOutputs.add(event.output!);
        }
      }

      // Build conversation from skill output
      final conversationMessages = <LlmMessage>[
        LlmMessage.user(
            'I\'m a beginner who wants to start running 3 times a week'),
        LlmMessage.assistant(text: skillOutputs.join('\n')),
      ];

      // Summarize the episode
      final episode = await memoryManager.summarizeEpisode(
        messages: conversationMessages,
        sessionStart: DateTime.now(),
        stepCount: 4,
        toolsUsed: const ['schedule.query'],
      );

      print('\n  -> episode: ${episode.summary}');

      expect(episode.summary, isNotEmpty);
      expect(episode.toolsUsed, contains('schedule.query'));

      // Extract long-term memory
      final extracted = await memoryManager.extractLongTerm(
        messages: conversationMessages,
        episode: episode,
      );

      print('  -> extracted ${extracted.length} memory items:');
      for (final item in extracted) {
        print('      [${item.category.name}] ${item.key}: ${item.value}');
      }

      expect(extracted, isNotEmpty);

      // Should have extracted something about running/fitness
      final allValues = extracted.map((m) => m.value.toLowerCase()).join(' ');
      expect(
        allValues.contains('running') ||
            allValues.contains('runner') ||
            allValues.contains('fitness') ||
            allValues.contains('exercise') ||
            allValues.contains('beginner'),
        true,
        reason: 'Should extract fitness-related memory',
      );
    }, timeout: const Timeout(Duration(seconds: 90)));

    // ── Skill matching accuracy: ambiguous input ──────────────────────────

    test('L4: SkillMatcher handles ambiguous input correctly', () async {
      final matcher = SkillMatcher(
        llmClient: client,
        registry: skillRegistry,
        model: qiniuModel,
      );

      // "plan" could be weekly_planner or fitness_plan
      final skill1 = await matcher.match('Help me plan my workouts');
      expect(skill1, isNotNull);
      // Should match fitness_plan (workout-related)
      expect(skill1!.id, 'fitness_plan');

      final skill2 = await matcher.match('Help me organize my week');
      expect(skill2, isNotNull);
      expect(skill2!.id, 'weekly_planner');

      final skill3 = await matcher.match('What\'s my agenda today?');
      expect(skill3, isNotNull);
      expect(skill3!.id, 'daily_briefing');

      print('\n  -> "plan workouts" -> ${skill1.id}');
      print('  -> "organize week" -> ${skill2.id}');
      print('  -> "agenda today" -> ${skill3.id}');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
