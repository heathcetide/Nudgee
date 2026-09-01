import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_registry.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

/// A test tool that echoes its input.
class EchoTool extends AgentTool {
  @override
  String get name => 'echo';

  @override
  String get description => 'Echoes the input message back.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'message': {'type': 'string', 'description': 'Message to echo'},
        },
        'required': ['message'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final msg = args['message'] as String?;
    return ToolResult.success('Echo: $msg');
  }
}

/// A test tool that always fails.
class FailingTool extends AgentTool {
  @override
  String get name => 'fail';

  @override
  String get description => 'Always fails.';

  @override
  Map<String, dynamic> get parametersSchema => {'type': 'object'};

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    return const ToolResult.error('Intentional failure');
  }
}

/// A test tool that requires confirmation.
class SensitiveTool extends AgentTool {
  @override
  String get name => 'delete';

  @override
  String get description => 'Deletes something.';

  @override
  Map<String, dynamic> get parametersSchema => {'type': 'object'};

  @override
  bool get requiresConfirmation => true;

  @override
  bool get isMutation => true;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    return const ToolResult.success('Deleted');
  }
}

/// A test tool that throws an exception.
class ThrowingTool extends AgentTool {
  @override
  String get name => 'throw';

  @override
  String get description => 'Throws an exception.';

  @override
  Map<String, dynamic> get parametersSchema => {'type': 'object'};

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    throw StateError('Unexpected error');
  }
}

void main() {
  group('ToolResult', () {
    test('success result', () {
      const result = ToolResult.success('hello');
      expect(result.success, true);
      expect(result.output, 'hello');
      expect(result.error, isNull);
    });

    test('error result', () {
      const result = ToolResult.error('Something failed');
      expect(result.success, false);
      expect(result.output, isNull);
      expect(result.error, 'Something failed');
    });

    test('toLlmContent for success', () {
      const result = ToolResult.success('data here');
      expect(result.toLlmContent(), 'data here');
    });

    test('toLlmContent for error', () {
      const result = ToolResult.error('broken');
      expect(result.toLlmContent(), 'Error: broken');
    });

    test('toLlmContent for null output', () {
      const result = ToolResult.success(null);
      expect(result.toLlmContent(), 'Success (no output)');
    });

    test('toLlmContent for non-string output', () {
      const result = ToolResult.success({'key': 'value'});
      expect(result.toLlmContent(), '{key: value}');
    });
  });

  group('ToolRegistry', () {
    late ToolRegistry registry;

    setUp(() {
      registry = ToolRegistry();
    });

    test('starts empty', () {
      expect(registry.length, 0);
      expect(registry.names, isEmpty);
      expect(registry.tools, isEmpty);
    });

    test('register adds a tool', () {
      registry.register(EchoTool());
      expect(registry.length, 1);
      expect(registry.contains('echo'), true);
      expect(registry.names, ['echo']);
    });

    test('registerAll adds multiple tools', () {
      registry.registerAll([EchoTool(), FailingTool(), SensitiveTool()]);
      expect(registry.length, 3);
      expect(registry.contains('echo'), true);
      expect(registry.contains('fail'), true);
      expect(registry.contains('delete'), true);
    });

    test('get returns the tool', () {
      registry.register(EchoTool());
      final tool = registry.get('echo');
      expect(tool, isNotNull);
      expect(tool!.name, 'echo');
    });

    test('get returns null for unknown tool', () {
      expect(registry.get('nonexistent'), isNull);
    });

    test('unregister removes a tool', () {
      registry.register(EchoTool());
      expect(registry.contains('echo'), true);
      registry.unregister('echo');
      expect(registry.contains('echo'), false);
      expect(registry.length, 0);
    });

    test('clear removes all tools', () {
      registry.registerAll([EchoTool(), FailingTool()]);
      registry.clear();
      expect(registry.length, 0);
    });

    test('definitionsFor returns all definitions when no names specified', () {
      registry.registerAll([EchoTool(), FailingTool()]);
      final defs = registry.definitionsFor();
      expect(defs, hasLength(2));
      expect(defs.map((d) => d.name).toSet(), {'echo', 'fail'});
    });

    test('definitionsFor returns only requested tools', () {
      registry.registerAll([EchoTool(), FailingTool(), SensitiveTool()]);
      final defs = registry.definitionsFor(['echo', 'delete']);
      expect(defs, hasLength(2));
      expect(defs.map((d) => d.name).toSet(), {'echo', 'delete'});
    });

    test('definitionsFor skips unknown names', () {
      registry.register(EchoTool());
      final defs = registry.definitionsFor(['echo', 'nonexistent']);
      expect(defs, hasLength(1));
      expect(defs[0].name, 'echo');
    });

    test('needsConfirmation returns true for sensitive tools', () {
      registry.register(SensitiveTool());
      expect(registry.needsConfirmation('delete'), true);
    });

    test('needsConfirmation returns false for normal tools', () {
      registry.register(EchoTool());
      expect(registry.needsConfirmation('echo'), false);
    });

    test('needsConfirmation returns false for unknown tools', () {
      expect(registry.needsConfirmation('nonexistent'), false);
    });

    test('isMutation returns true for mutation tools', () {
      registry.register(SensitiveTool());
      expect(registry.isMutation('delete'), true);
    });

    test('isMutation returns false for read-only tools', () {
      registry.register(EchoTool());
      expect(registry.isMutation('echo'), false);
    });

    test('execute returns success for valid tool', () async {
      registry.register(EchoTool());
      final result = await registry.execute('echo', {'message': 'hello'});
      expect(result.success, true);
      expect(result.output, 'Echo: hello');
    });

    test('execute returns error for unknown tool', () async {
      final result = await registry.execute('nonexistent', {});
      expect(result.success, false);
      expect(result.error, contains('not found'));
    });

    test('execute returns error for failing tool', () async {
      registry.register(FailingTool());
      final result = await registry.execute('fail', {});
      expect(result.success, false);
      expect(result.error, 'Intentional failure');
    });

    test('execute catches exceptions and returns error', () async {
      registry.register(ThrowingTool());
      final result = await registry.execute('throw', {});
      expect(result.success, false);
      expect(result.error, contains('Unexpected error'));
    });

    test('execute attaches duration', () async {
      registry.register(EchoTool());
      final result = await registry.execute('echo', {'message': 'test'});
      expect(result.duration, isNotNull);
      expect(result.duration!.inMicroseconds, greaterThanOrEqualTo(0));
    });
  });

  group('ToolDefinition', () {
    test('fromTool copies all fields', () {
      final tool = SensitiveTool();
      final def = ToolDefinition.fromTool(tool);

      expect(def.name, 'delete');
      expect(def.description, 'Deletes something.');
      expect(def.requiresConfirmation, true);
      expect(def.isMutation, true);
      expect(def.category, ToolCategory.builtin);
    });

    test('fromTool for non-sensitive tool', () {
      final tool = EchoTool();
      final def = ToolDefinition.fromTool(tool);

      expect(def.requiresConfirmation, false);
      expect(def.isMutation, false);
    });
  });
}
