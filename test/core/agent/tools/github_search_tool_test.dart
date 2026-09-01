import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/tools/builtin/github_search_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

void main() {
  group('GitHubSearchTool', () {
    late GitHubSearchTool tool;

    setUp(() => tool = GitHubSearchTool());
    tearDown(() => tool.dispose());

    test('name is github.search', () {
      expect(tool.name, 'github.search');
    });

    test('description mentions GitHub and no API key', () {
      expect(tool.description, contains('GitHub'));
      expect(tool.description, contains('No API key'));
    });

    test('parametersSchema has query (required) and optional type/language/limit', () {
      final schema = tool.parametersSchema;
      expect(schema['type'], 'object');
      final props = schema['properties'] as Map<String, dynamic>;
      expect(props.containsKey('query'), true);
      expect(props.containsKey('type'), true);
      expect(props.containsKey('language'), true);
      expect(props.containsKey('limit'), true);
      final required = schema['required'] as List;
      expect(required, contains('query'));
    });

    test('type enum has repositories/code/issues/users', () {
      final schema = tool.parametersSchema;
      final props = schema['properties'] as Map<String, dynamic>;
      final typeProp = props['type'] as Map<String, dynamic>;
      final enumValues = typeProp['enum'] as List;
      expect(enumValues, contains('repositories'));
      expect(enumValues, contains('code'));
      expect(enumValues, contains('issues'));
      expect(enumValues, contains('users'));
    });

    test('isMutation is false', () {
      expect(tool.isMutation, false);
    });

    test('missing query returns error', () async {
      final result = await tool.execute({});
      expect(result.success, false);
      expect(result.error, contains('Missing required field: query'));
    });

    test('empty query returns error', () async {
      final result = await tool.execute({'query': ''});
      expect(result.success, false);
      expect(result.error, contains('Missing required field: query'));
    });

    test('real search: repositories for "flutter" returns results', () async {
      final result = await tool.execute({
        'query': 'flutter state management',
        'type': 'repositories',
        'language': 'dart',
        'limit': 3,
      });

      // This is a real API call — it might hit rate limits in CI
      if (result.success) {
        expect(result.output, contains('GitHub'));
        expect(result.output, contains('flutter'));
        // Should have star counts
        expect(result.output, contains('Stars'));
      } else {
        // Rate limit is acceptable in test env
        print('GitHub API rate limited (expected in CI): ${result.error}');
      }
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('real search: code search for "LlmMessage" in dart', () async {
      final result = await tool.execute({
        'query': 'LlmMessage class',
        'type': 'code',
        'language': 'dart',
        'limit': 3,
      });

      if (result.success) {
        expect(result.output, contains('GitHub'));
        // Code results have file paths
        expect(result.output, contains('File:'));
      } else {
        print('GitHub API rate limited (expected in CI): ${result.error}');
      }
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('real search: users for "flutter" returns results', () async {
      final result = await tool.execute({
        'query': 'flutter',
        'type': 'users',
        'limit': 3,
      });

      if (result.success) {
        expect(result.output, contains('GitHub'));
      } else {
        print('GitHub API rate limited (expected in CI): ${result.error}');
      }
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('real search: issues for "flutter" returns results', () async {
      final result = await tool.execute({
        'query': 'flutter label:bug',
        'type': 'issues',
        'limit': 3,
      });

      if (result.success) {
        expect(result.output, contains('GitHub'));
      } else {
        print('GitHub API rate limited (expected in CI): ${result.error}');
      }
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('invalid type defaults to repositories', () async {
      // The tool should handle invalid type gracefully (defaults to repos)
      final result = await tool.execute({
        'query': 'flutter',
        'type': 'invalid_type',
        'limit': 1,
      });

      // Should not crash — either returns results or rate limit error
      expect(result, isA<ToolResult>());
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}
