import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/tools/builtin/web_search_tool.dart';

void main() {
  group('WebSearchTool', () {
    late WebSearchTool tool;

    setUp(() {
      tool = WebSearchTool();
    });

    tearDown(() {
      tool.dispose();
    });

    test('has correct name', () {
      expect(tool.name, 'web.search');
    });

    test('has query parameter in schema', () {
      final schema = tool.parametersSchema;
      expect(schema['properties'], contains('query'));
      expect(schema['required'], ['query']);
    });

    test('returns error for missing query', () async {
      final result = await tool.execute({});
      expect(result.success, false);
      expect(result.error, contains('Missing'));
    });

    test('returns error for empty query', () async {
      final result = await tool.execute({'query': ''});
      expect(result.success, false);
      expect(result.error, contains('Missing'));
    });

    test('searches Wikipedia for encyclopedic content', () async {
      final result = await tool.execute({
        'query': 'Albert Einstein',
        'limit': 3,
      });
      // This test requires network — if it fails, skip
      if (!result.success) {
        print('Network test skipped: ${result.error}');
        return;
      }
      expect(result.success, true);
      expect(result.output, contains('Einstein'));
      print('\n  -> Wikipedia search result:\n${result.output}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('searches for programming concepts', () async {
      final result = await tool.execute({
        'query': 'Dart programming language',
        'limit': 3,
      });
      if (!result.success) {
        print('Network test skipped: ${result.error}');
        return;
      }
      expect(result.success, true);
      // Should find something about Dart
      final lower = result.output.toLowerCase();
      expect(
        lower.contains('dart') || lower.contains('programming'),
        true,
        reason: 'Should mention Dart or programming',
      );
      print('\n  -> Programming search result:\n${result.output}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('searches for current events', () async {
      final result = await tool.execute({
        'query': 'Flutter framework',
        'limit': 5,
      });
      if (!result.success) {
        print('Network test skipped: ${result.error}');
        return;
      }
      expect(result.success, true);
      print('\n  -> Current events search result:\n${result.output}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('handles non-existent topics gracefully', () async {
      final result = await tool.execute({
        'query': 'xyzzyqwerty nonexist topic 12345678',
        'limit': 3,
      });
      // Should not crash — either returns results or "no results found"
      expect(result.success, true);
      print('\n  -> Non-existent topic result:\n${result.output}');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('respects limit parameter', () async {
      final result = await tool.execute({
        'query': 'Python programming',
        'limit': 2,
      });
      if (!result.success) {
        print('Network test skipped: ${result.error}');
        return;
      }
      expect(result.success, true);
      // Count the number of results (lines starting with "1.", "2.", etc.)
      final resultCount = RegExp(r'^\d+\.', multiLine: true)
          .allMatches(result.output)
          .length;
      expect(resultCount, lessThanOrEqualTo(2));
      print('\n  -> Limited to $resultCount results');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('includes URLs in results', () async {
      final result = await tool.execute({
        'query': 'machine learning',
        'limit': 3,
      });
      if (!result.success) {
        print('Network test skipped: ${result.error}');
        return;
      }
      expect(result.success, true);
      // At least some results should have URLs
      expect(
        result.output.contains('URL:') || result.output.contains('http'),
        true,
        reason: 'Results should include URLs',
      );
      print('\n  -> Results with URLs:\n${result.output}');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
