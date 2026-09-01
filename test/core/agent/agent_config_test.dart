import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/agent_config.dart';

void main() {
  group('AgentConfig', () {
    test('creates with required fields', () {
      const config = AgentConfig(
        id: 'test-agent',
        name: 'Test Agent',
        systemPrompt: 'You are a test agent.',
      );

      expect(config.id, 'test-agent');
      expect(config.name, 'Test Agent');
      expect(config.systemPrompt, 'You are a test agent.');
      expect(config.model, 'deepseek-chat');
      expect(config.toolNames, isEmpty);
      expect(config.temperature, 0.7);
      expect(config.maxSteps, 10);
      expect(config.maxTokens, 4096);
      expect(config.isBuiltin, false);
    });

    test('creates with all fields', () {
      const config = AgentConfig(
        id: 'full-agent',
        name: 'Full Agent',
        icon: '🤖',
        systemPrompt: 'You are full.',
        model: 'deepseek-reasoner',
        toolNames: ['schedule.query', 'post.create'],
        temperature: 0.3,
        maxSteps: 20,
        maxTokens: 8192,
        isBuiltin: true,
        description: 'A fully configured agent.',
      );

      expect(config.icon, '🤖');
      expect(config.model, 'deepseek-reasoner');
      expect(config.toolNames, ['schedule.query', 'post.create']);
      expect(config.temperature, 0.3);
      expect(config.maxSteps, 20);
      expect(config.maxTokens, 8192);
      expect(config.isBuiltin, true);
      expect(config.description, 'A fully configured agent.');
    });

    test('copyWith updates only specified fields', () {
      const original = AgentConfig(
        id: 'agent',
        name: 'Original',
        systemPrompt: 'Original prompt',
        temperature: 0.5,
      );

      final updated = original.copyWith(
        name: 'Updated',
        maxSteps: 15,
      );

      expect(updated.id, 'agent');  // unchanged
      expect(updated.name, 'Updated');  // changed
      expect(updated.systemPrompt, 'Original prompt');  // unchanged
      expect(updated.temperature, 0.5);  // unchanged
      expect(updated.maxSteps, 15);  // changed
    });

    test('toJson serializes all fields', () {
      const config = AgentConfig(
        id: 'json-agent',
        name: 'JSON Agent',
        icon: '⚡',
        systemPrompt: 'JSON test',
        model: 'deepseek-reasoner',
        toolNames: ['tool1', 'tool2'],
        temperature: 0.9,
        maxSteps: 5,
        maxTokens: 2048,
        isBuiltin: true,
        description: 'JSON desc',
      );

      final json = config.toJson();

      expect(json['id'], 'json-agent');
      expect(json['name'], 'JSON Agent');
      expect(json['icon'], '⚡');
      expect(json['system_prompt'], 'JSON test');
      expect(json['model'], 'deepseek-reasoner');
      expect(json['tool_names'], ['tool1', 'tool2']);
      expect(json['temperature'], 0.9);
      expect(json['max_steps'], 5);
      expect(json['max_tokens'], 2048);
      expect(json['is_builtin'], true);
      expect(json['description'], 'JSON desc');
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 'from-json',
        'name': 'From JSON',
        'icon': '🔥',
        'system_prompt': 'From JSON prompt',
        'model': 'deepseek-chat',
        'tool_names': ['a', 'b', 'c'],
        'temperature': 0.6,
        'max_steps': 12,
        'max_tokens': 6000,
        'is_builtin': false,
        'description': 'Parsed from JSON',
      };

      final config = AgentConfig.fromJson(json);

      expect(config.id, 'from-json');
      expect(config.name, 'From JSON');
      expect(config.icon, '🔥');
      expect(config.systemPrompt, 'From JSON prompt');
      expect(config.model, 'deepseek-chat');
      expect(config.toolNames, ['a', 'b', 'c']);
      expect(config.temperature, 0.6);
      expect(config.maxSteps, 12);
      expect(config.maxTokens, 6000);
      expect(config.isBuiltin, false);
      expect(config.description, 'Parsed from JSON');
    });

    test('fromJson uses defaults for missing fields', () {
      final json = {
        'id': 'minimal',
        'name': 'Minimal',
        'system_prompt': 'Minimal prompt',
      };

      final config = AgentConfig.fromJson(json);

      expect(config.model, 'deepseek-chat');
      expect(config.toolNames, isEmpty);
      expect(config.temperature, 0.7);
      expect(config.maxSteps, 10);
      expect(config.maxTokens, 4096);
      expect(config.isBuiltin, false);
    });

    test('toJson/fromJson round-trip preserves data', () {
      const original = AgentConfig(
        id: 'roundtrip',
        name: 'Round Trip',
        icon: 'round-trip',
        systemPrompt: 'Round trip test',
        model: 'deepseek-reasoner',
        toolNames: ['x', 'y'],
        temperature: 0.42,
        maxSteps: 7,
        maxTokens: 3333,
        isBuiltin: true,
        description: 'RT',
      );

      final json = original.toJson();
      final restored = AgentConfig.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.icon, original.icon);
      expect(restored.systemPrompt, original.systemPrompt);
      expect(restored.model, original.model);
      expect(restored.toolNames, original.toolNames);
      expect(restored.temperature, original.temperature);
      expect(restored.maxSteps, original.maxSteps);
      expect(restored.maxTokens, original.maxTokens);
      expect(restored.isBuiltin, original.isBuiltin);
      expect(restored.description, original.description);
    });

    test('toString contains id and name', () {
      const config = AgentConfig(
        id: 'string-agent',
        name: 'String Agent',
        systemPrompt: 'test',
      );
      final str = config.toString();
      expect(str, contains('string-agent'));
      expect(str, contains('String Agent'));
    });
  });
}
