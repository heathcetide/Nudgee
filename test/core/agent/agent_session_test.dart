import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent_session.dart';

void main() {
  group('AgentSession', () {
    test('creates with required fields', () {
      final session = AgentSession(
        id: 'sess-1',
        agentId: 'default',
        userId: 'user-1',
        conversationId: 'conv-1',
        status: AgentSessionStatus.running,
        input: 'Plan my week',
        startedAt: DateTime(2026, 9, 1, 10, 0),
      );

      expect(session.id, 'sess-1');
      expect(session.agentId, 'default');
      expect(session.userId, 'user-1');
      expect(session.conversationId, 'conv-1');
      expect(session.status, AgentSessionStatus.running);
      expect(session.input, 'Plan my week');
      expect(session.finalReply, isNull);
      expect(session.totalSteps, 0);
      expect(session.totalTokens, 0);
      expect(session.completedAt, isNull);
      expect(session.lastCheckpointId, isNull);
    });

    test('isRunning is true when status is running', () {
      final session = AgentSession(
        id: 's',
        agentId: 'a',
        userId: 'u',
        conversationId: 'c',
        status: AgentSessionStatus.running,
        input: 'test',
        startedAt: DateTime.now(),
      );
      expect(session.isRunning, true);
    });

    test('isRunning is false when status is completed', () {
      final session = AgentSession(
        id: 's',
        agentId: 'a',
        userId: 'u',
        conversationId: 'c',
        status: AgentSessionStatus.completed,
        input: 'test',
        startedAt: DateTime.now(),
      );
      expect(session.isRunning, false);
    });

    test('canResume is true for running, paused, crashed', () {
      for (final status in [
        AgentSessionStatus.running,
        AgentSessionStatus.paused,
        AgentSessionStatus.crashed,
      ]) {
        final session = AgentSession(
          id: 's',
          agentId: 'a',
          userId: 'u',
          conversationId: 'c',
          status: status,
          input: 'test',
          startedAt: DateTime.now(),
        );
        expect(session.canResume, true, reason: '$status should be resumable');
      }
    });

    test('canResume is false for completed, aborted', () {
      for (final status in [
        AgentSessionStatus.completed,
        AgentSessionStatus.aborted,
      ]) {
        final session = AgentSession(
          id: 's',
          agentId: 'a',
          userId: 'u',
          conversationId: 'c',
          status: status,
          input: 'test',
          startedAt: DateTime.now(),
        );
        expect(session.canResume, false, reason: '$status should not be resumable');
      }
    });

    test('copyWith updates only specified fields', () {
      final original = AgentSession(
        id: 's',
        agentId: 'a',
        userId: 'u',
        conversationId: 'c',
        status: AgentSessionStatus.running,
        input: 'test',
        startedAt: DateTime(2026, 9, 1),
      );

      final updated = original.copyWith(
        status: AgentSessionStatus.completed,
        finalReply: 'Done!',
        totalSteps: 5,
        completedAt: DateTime(2026, 9, 1, 10, 30),
      );

      expect(updated.id, 's');  // unchanged
      expect(updated.agentId, 'a');  // unchanged
      expect(updated.status, AgentSessionStatus.completed);  // changed
      expect(updated.finalReply, 'Done!');  // changed
      expect(updated.totalSteps, 5);  // changed
      expect(updated.completedAt, DateTime(2026, 9, 1, 10, 30));  // changed
      expect(updated.input, 'test');  // unchanged
    });

    test('toString contains id and status', () {
      final session = AgentSession(
        id: 'sess-42',
        agentId: 'agent-1',
        userId: 'u',
        conversationId: 'c',
        status: AgentSessionStatus.running,
        input: 'test',
        startedAt: DateTime.now(),
      );
      final str = session.toString();
      expect(str, contains('sess-42'));
      expect(str, contains('running'));
    });
  });

  group('AgentSessionStatus', () {
    test('has all expected values', () {
      expect(AgentSessionStatus.values, hasLength(5));
      expect(AgentSessionStatus.values, contains(AgentSessionStatus.running));
      expect(AgentSessionStatus.values, contains(AgentSessionStatus.paused));
      expect(AgentSessionStatus.values, contains(AgentSessionStatus.completed));
      expect(AgentSessionStatus.values, contains(AgentSessionStatus.aborted));
      expect(AgentSessionStatus.values, contains(AgentSessionStatus.crashed));
    });
  });
}
