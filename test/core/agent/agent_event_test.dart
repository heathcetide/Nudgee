import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent_event.dart';
import 'package:nudgee/core/agent/agent_stats.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

void main() {
  group('AgentEvent', () {
    test('ThinkingEvent holds delta', () {
      const event = AgentEvent.thinking('reasoning here');
      expect(event, isA<ThinkingEvent>());
      expect((event as ThinkingEvent).delta, 'reasoning here');
    });

    test('ContentEvent holds delta', () {
      const event = AgentEvent.content('reply text');
      expect(event, isA<ContentEvent>());
      expect((event as ContentEvent).delta, 'reply text');
    });

    test('ToolCallEvent holds ToolCall', () {
      const call = ToolCall(id: 'tc1', name: 'echo', arguments: {'msg': 'hi'});
      final event = AgentEvent.toolCall(call);
      expect(event, isA<ToolCallEvent>());
      expect((event as ToolCallEvent).call, same(call));
    });

    test('ToolResultEvent holds toolName and result', () {
      const result = ToolResult.success('done');
      final event = AgentEvent.toolResult('echo', result);
      expect(event, isA<ToolResultEvent>());
      expect((event as ToolResultEvent).toolName, 'echo');
      expect((event as ToolResultEvent).result, same(result));
    });

    test('PlanEvent holds steps', () {
      final steps = [
        const PlanStep(description: 'Step 1'),
        const PlanStep(description: 'Step 2', isActive: true),
        const PlanStep(description: 'Step 3', isCompleted: true),
      ];
      final event = AgentEvent.plan(steps);
      expect(event, isA<PlanEvent>());
      expect((event as PlanEvent).steps, hasLength(3));
      expect(event.steps[0].description, 'Step 1');
      expect(event.steps[0].isCompleted, false);
      expect(event.steps[0].isActive, false);
      expect(event.steps[1].isActive, true);
      expect(event.steps[2].isCompleted, true);
    });

    test('HumanConfirmationEvent holds call and reason', () {
      const call = ToolCall(id: 'tc1', name: 'delete', arguments: {});
      final event = AgentEvent.humanConfirmation(call, 'Dangerous operation');
      expect(event, isA<HumanConfirmationEvent>());
      expect((event as HumanConfirmationEvent).call, same(call));
      expect(event.reason, 'Dangerous operation');
    });

    test('LoopWarningEvent holds stepCount', () {
      const event = AgentEvent.loopWarning(5);
      expect(event, isA<LoopWarningEvent>());
      expect((event as LoopWarningEvent).stepCount, 5);
    });

    test('DoneEvent holds finalReply and stats', () {
      const stats = AgentRunStats(
        steps: 3,
        inputTokens: 100,
        outputTokens: 50,
        toolCalls: 1,
        skillUses: 0,
        duration: Duration(seconds: 2),
      );
      const event = AgentEvent.done('Final reply', stats);
      expect(event, isA<DoneEvent>());
      expect((event as DoneEvent).finalReply, 'Final reply');
      expect(event.stats.steps, 3);
    });

    test('ErrorEvent holds message and default severity', () {
      const event = AgentEvent.error('Something went wrong');
      expect(event, isA<ErrorEvent>());
      expect((event as ErrorEvent).message, 'Something went wrong');
      expect(event.severity, ErrorSeverity.error);
    });

    test('ErrorEvent with custom severity', () {
      const event = AgentEvent.error('Minor issue', severity: ErrorSeverity.info);
      expect((event as ErrorEvent).severity, ErrorSeverity.info);
    });
  });

  group('ToolCall', () {
    test('creates with all fields', () {
      const call = ToolCall(
        id: 'call_123',
        name: 'schedule.add',
        arguments: {'title': 'Meeting', 'date': '2026-09-01'},
      );
      expect(call.id, 'call_123');
      expect(call.name, 'schedule.add');
      expect(call.arguments['title'], 'Meeting');
      expect(call.arguments['date'], '2026-09-01');
    });

    test('toString contains name', () {
      const call = ToolCall(id: '1', name: 'echo', arguments: {});
      expect(call.toString(), contains('echo'));
    });
  });

  group('PlanStep', () {
    test('creates with default values', () {
      const step = PlanStep(description: 'Do something');
      expect(step.description, 'Do something');
      expect(step.isCompleted, false);
      expect(step.isActive, false);
    });

    test('copyWith updates fields', () {
      const step = PlanStep(description: 'Test');
      final active = step.copyWith(isActive: true);
      expect(active.isActive, true);
      expect(active.isCompleted, false);

      final done = step.copyWith(isCompleted: true);
      expect(done.isCompleted, true);
      expect(done.isActive, false);
    });

    test('toString shows status indicator', () {
      const pending = PlanStep(description: 'Pending');
      const active = PlanStep(description: 'Active', isActive: true);
      const done = PlanStep(description: 'Done', isCompleted: true);

      expect(pending.toString(), contains('[pending]'));
      expect(active.toString(), contains('[active]'));
      expect(done.toString(), contains('[done]'));
    });
  });

  group('ErrorSeverity', () {
    test('has all expected values', () {
      expect(ErrorSeverity.values, contains(ErrorSeverity.info));
      expect(ErrorSeverity.values, contains(ErrorSeverity.warning));
      expect(ErrorSeverity.values, contains(ErrorSeverity.error));
      expect(ErrorSeverity.values, contains(ErrorSeverity.critical));
    });
  });
}
