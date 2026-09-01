import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent.dart';

void main() {
  group('AgentController', () {
    test('initial state is idle', () {
      final state = AgentRunState.idle;
      expect(state, AgentRunState.idle);
    });

    test('AgentRunState has all expected states', () {
      expect(AgentRunState.values.length, 6);
      expect(AgentRunState.values, contains(AgentRunState.idle));
      expect(AgentRunState.values, contains(AgentRunState.running));
      expect(AgentRunState.values, contains(AgentRunState.paused));
      expect(AgentRunState.values, contains(AgentRunState.done));
      expect(AgentRunState.values, contains(AgentRunState.error));
      expect(AgentRunState.values, contains(AgentRunState.cancelled));
    });
  });

  group('AgentTrace UI helpers', () {
    test('TraceEntryType has all expected types', () {
      expect(TraceEntryType.values.length, 17);
      expect(TraceEntryType.values, contains(TraceEntryType.runStart));
      expect(TraceEntryType.values, contains(TraceEntryType.runEnd));
      expect(TraceEntryType.values, contains(TraceEntryType.stepStart));
      expect(TraceEntryType.values, contains(TraceEntryType.stepEnd));
      expect(TraceEntryType.values, contains(TraceEntryType.llmRequest));
      expect(TraceEntryType.values, contains(TraceEntryType.llmResponse));
      expect(TraceEntryType.values, contains(TraceEntryType.toolCall));
      expect(TraceEntryType.values, contains(TraceEntryType.toolResult));
      expect(TraceEntryType.values, contains(TraceEntryType.error));
    });

    test('TraceEntryType has icon', () {
      expect(TraceEntryType.runStart.icon, '[START]');
      expect(TraceEntryType.runEnd.icon, '[END]');
      expect(TraceEntryType.toolCall.icon, '[TOOL]');
      expect(TraceEntryType.error.icon, '[ERROR]');
    });

    test('AgentTrace can record and serialize', () {
      final trace = AgentTrace();
      expect(trace.isEmpty, true);

      trace.recordRunStart(
        input: 'test input',
        agentId: 'test-agent',
        model: 'test-model',
      );
      expect(trace.isNotEmpty, true);
      expect(trace.length, 1);

      trace.recordStepStart(step: 1);
      trace.recordLlmRequest(
        messageCount: 2,
        toolCount: 3,
        model: 'test-model',
        streaming: true,
      );
      trace.recordLlmResponse(
        response: const LlmCompleteResponse(
          content: 'test reply',
          toolCalls: [],
          finishReason: 'stop',
        ),
      );
      trace.recordStepEnd(step: 1, tokenCount: 100);
      trace.recordRunEnd(
        stats: const AgentRunStats(
          steps: 1,
          inputTokens: 50,
          outputTokens: 50,
          toolCalls: 0,
          skillUses: 0,
          duration: Duration(milliseconds: 500),
        ),
        finalReply: 'test reply',
      );

      expect(trace.length, 6);

      // Serialize to JSON
      final json = trace.toJson();
      expect(json, isA<Map>());
      expect(json['entries'], isA<List>());
      final entries = json['entries'] as List;
      expect(entries.length, 6);
      expect(entries[0]['type'], 'runStart');
      expect(entries[5]['type'], 'runEnd');

      // Format as string
      final formatted = trace.format();
      expect(formatted, contains('runStart'));
      expect(formatted, contains('runEnd'));
    });
  });

  group('AgentEvent types', () {
    test('ThinkingEvent has delta', () {
      const event = ThinkingEvent('reasoning here');
      expect(event.delta, 'reasoning here');
    });

    test('ContentEvent has delta', () {
      const event = ContentEvent('reply text');
      expect(event.delta, 'reply text');
    });

    test('DoneEvent has finalReply and stats', () {
      const event = DoneEvent(
        'done',
        AgentRunStats(
          steps: 1,
          inputTokens: 10,
          outputTokens: 20,
          toolCalls: 0,
          skillUses: 0,
          duration: Duration(seconds: 1),
        ),
      );
      expect(event.finalReply, 'done');
      expect(event.stats.steps, 1);
      expect(event.stats.duration, const Duration(seconds: 1));
    });

    test('ErrorEvent has message', () {
      const event = ErrorEvent('failed');
      expect(event.message, 'failed');
    });

    test('LoopWarningEvent has stepCount', () {
      const event = LoopWarningEvent(8);
      expect(event.stepCount, 8);
    });

    test('ToolResultEvent has toolName and result', () {
      const event = ToolResultEvent(
        'web.search',
        ToolResult.success('search results'),
      );
      expect(event.toolName, 'web.search');
      expect(event.result.success, true);
      expect(event.result.output, 'search results');
    });

    test('ToolCallEvent has call', () {
      const event = ToolCallEvent(ToolCall(
        id: 'call_1',
        name: 'web.search',
        arguments: {'query': 'test'},
      ));
      expect(event.call.id, 'call_1');
      expect(event.call.name, 'web.search');
    });
  });
}
