import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent_stats.dart';

void main() {
  group('AgentRunStats', () {
    test('creates with required fields', () {
      const stats = AgentRunStats(
        steps: 5,
        inputTokens: 1000,
        outputTokens: 500,
        toolCalls: 3,
        skillUses: 1,
        duration: Duration(seconds: 10),
      );

      expect(stats.steps, 5);
      expect(stats.inputTokens, 1000);
      expect(stats.outputTokens, 500);
      expect(stats.thinkingTokens, 0);
      expect(stats.toolCalls, 3);
      expect(stats.skillUses, 1);
      expect(stats.duration, const Duration(seconds: 10));
      expect(stats.estimatedCost, 0.0);
    });

    test('totalTokens sums input + output + thinking', () {
      const stats = AgentRunStats(
        steps: 1,
        inputTokens: 100,
        outputTokens: 200,
        thinkingTokens: 50,
        toolCalls: 0,
        skillUses: 0,
        duration: Duration.zero,
      );
      expect(stats.totalTokens, 350);
    });

    test('totalTokens without thinking tokens', () {
      const stats = AgentRunStats(
        steps: 1,
        inputTokens: 100,
        outputTokens: 200,
        toolCalls: 0,
        skillUses: 0,
        duration: Duration.zero,
      );
      expect(stats.totalTokens, 300);
    });

    test('empty stats have all zeros', () {
      const stats = AgentRunStats.empty();
      expect(stats.steps, 0);
      expect(stats.inputTokens, 0);
      expect(stats.outputTokens, 0);
      expect(stats.thinkingTokens, 0);
      expect(stats.toolCalls, 0);
      expect(stats.skillUses, 0);
      expect(stats.duration, Duration.zero);
      expect(stats.estimatedCost, 0.0);
      expect(stats.totalTokens, 0);
    });

    test('copyWith updates only specified fields', () {
      const original = AgentRunStats(
        steps: 3,
        inputTokens: 100,
        outputTokens: 50,
        toolCalls: 1,
        skillUses: 0,
        duration: Duration(seconds: 5),
      );

      final updated = original.copyWith(
        steps: 10,
        toolCalls: 5,
      );

      expect(updated.steps, 10);
      expect(updated.inputTokens, 100);  // unchanged
      expect(updated.outputTokens, 50);  // unchanged
      expect(updated.toolCalls, 5);
      expect(updated.skillUses, 0);  // unchanged
      expect(updated.duration, const Duration(seconds: 5));  // unchanged
    });

    test('merge combines two stats', () {
      const a = AgentRunStats(
        steps: 3,
        inputTokens: 100,
        outputTokens: 50,
        thinkingTokens: 20,
        toolCalls: 2,
        skillUses: 1,
        duration: Duration(seconds: 5),
        estimatedCost: 0.01,
      );
      const b = AgentRunStats(
        steps: 2,
        inputTokens: 80,
        outputTokens: 40,
        thinkingTokens: 10,
        toolCalls: 1,
        skillUses: 0,
        duration: Duration(seconds: 3),
        estimatedCost: 0.005,
      );

      final merged = a.merge(b);

      expect(merged.steps, 5);
      expect(merged.inputTokens, 180);
      expect(merged.outputTokens, 90);
      expect(merged.thinkingTokens, 30);
      expect(merged.toolCalls, 3);
      expect(merged.skillUses, 1);
      expect(merged.duration, const Duration(seconds: 8));
      expect(merged.estimatedCost, 0.015);
    });

    test('toJson serializes correctly', () {
      const stats = AgentRunStats(
        steps: 5,
        inputTokens: 1000,
        outputTokens: 500,
        thinkingTokens: 200,
        toolCalls: 3,
        skillUses: 1,
        duration: Duration(seconds: 10),
        estimatedCost: 0.05,
      );

      final json = stats.toJson();

      expect(json['steps'], 5);
      expect(json['input_tokens'], 1000);
      expect(json['output_tokens'], 500);
      expect(json['thinking_tokens'], 200);
      expect(json['total_tokens'], 1700);
      expect(json['tool_calls'], 3);
      expect(json['skill_uses'], 1);
      expect(json['duration_ms'], 10000);
      expect(json['estimated_cost'], 0.05);
    });

    test('toString contains key info', () {
      const stats = AgentRunStats(
        steps: 5,
        inputTokens: 1000,
        outputTokens: 500,
        toolCalls: 3,
        skillUses: 1,
        duration: Duration(seconds: 10),
      );
      final str = stats.toString();
      expect(str, contains('steps=5'));
      expect(str, contains('tools=3'));
    });
  });
}
