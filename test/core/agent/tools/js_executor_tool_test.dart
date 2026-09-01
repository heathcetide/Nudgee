import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/tools/builtin/js_executor_tool.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JsExecutorTool', () {
    late JsExecutorTool tool;

    setUp(() => tool = JsExecutorTool());
    tearDown(() => tool.dispose());

    test('name is workspace.js.exec', () {
      expect(tool.name, 'workspace.js.exec');
    });

    test('description mentions JavaScript', () {
      expect(tool.description, contains('JavaScript'));
    });

    test('parametersSchema has code (required)', () {
      final schema = tool.parametersSchema;
      final props = schema['properties'] as Map<String, dynamic>;
      expect(props.containsKey('code'), true);
      expect(props.containsKey('timeoutMs'), true);
      final required = schema['required'] as List;
      expect(required, contains('code'));
    });

    test('isMutation is false', () {
      expect(tool.isMutation, false);
    });

    test('missing code returns error', () async {
      final result = await tool.execute({});
      expect(result.success, false);
      expect(result.error, contains('Missing required field: code'));
    });

    test('empty code returns error', () async {
      final result = await tool.execute({'code': ''});
      expect(result.success, false);
    });

    test('simple arithmetic: 1 + 2 = 3', () async {
      final result = await tool.execute({'code': 'console.log(1 + 2)'});
      expect(result.success, true);
      expect(result.output, contains('3'));
    });

    test('string concatenation', () async {
      final result = await tool.execute({
        'code': 'console.log("Hello" + " " + "World")',
      });
      expect(result.success, true);
      expect(result.output, contains('Hello World'));
    });

    test('array map', () async {
      final result = await tool.execute({
        'code': 'const arr = [1, 2, 3, 4, 5]; console.log(arr.map(n => n * 2));',
      });
      expect(result.success, true);
      expect(result.output, contains('2'));
    });

    test('JSON processing', () async {
      final result = await tool.execute({
        'code': '''
          const data = [{"name": "Alice", "age": 30}, {"name": "Bob", "age": 25}];
          const sorted = data.sort((a, b) => a.age - b.age);
          console.log(sorted.map(p => p.name).join(", "));
        ''',
      });
      expect(result.success, true);
      expect(result.output, contains('Bob'));
      expect(result.output, contains('Alice'));
    });

    test('fibonacci calculation', () async {
      final result = await tool.execute({
        'code': '''
          function fib(n) {
            if (n <= 1) return n;
            return fib(n-1) + fib(n-2);
          }
          console.log(fib(10));
        ''',
      });
      expect(result.success, true);
      expect(result.output, contains('55'));
    });

    test('print() alias works', () async {
      final result = await tool.execute({
        'code': 'print("test output")',
      });
      expect(result.success, true);
      expect(result.output, contains('test output'));
    });

    test('console.error outputs ERROR prefix', () async {
      final result = await tool.execute({
        'code': 'console.error("something went wrong")',
      });
      expect(result.success, true);
      expect(result.output, contains('ERROR'));
      expect(result.output, contains('something went wrong'));
    });

    test('syntax error is caught', () async {
      final result = await tool.execute({
        'code': 'console.log("hello";',
      });
      // Should return an error result, not crash
      expect(result.success, false);
    });

    test('runtime error is caught', () async {
      final result = await tool.execute({
        'code': 'const x = undefined.foo;',
      });
      // Should return an error result, not crash
      expect(result.success, false);
    });

    test('multiple console.log calls', () async {
      final result = await tool.execute({
        'code': '''
          console.log("line 1");
          console.log("line 2");
          console.log("line 3");
        ''',
      });
      expect(result.success, true);
      expect(result.output, contains('line 1'));
      expect(result.output, contains('line 2'));
      expect(result.output, contains('line 3'));
    });

    test('object destructuring (ES2020+)', () async {
      final result = await tool.execute({
        'code': '''
          const {a, b, c} = {a: 1, b: 2, c: 3};
          console.log(a + b + c);
        ''',
      });
      expect(result.success, true);
      expect(result.output, contains('6'));
    });

    test('async/await', () async {
      final result = await tool.execute({
        'code': '''
          async function delay() { return 42; }
          delay().then(v => console.log("result: " + v));
        ''',
      });
      expect(result.success, true);
      // Note: async results may or may not be captured depending on timing
    });

    test('string methods', () async {
      final result = await tool.execute({
        'code': '''
          const s = "Hello World";
          console.log(s.toUpperCase());
          console.log(s.split(" ").length);
          console.log(s.replace("World", "JS"));
        ''',
      });
      expect(result.success, true);
      expect(result.output, contains('HELLO WORLD'));
      expect(result.output, contains('2'));
      expect(result.output, contains('Hello JS'));
    });

    test('math operations', () async {
      final result = await tool.execute({
        'code': '''
          console.log(Math.max(1, 5, 3));
          console.log(Math.floor(3.7));
          console.log(Math.PI.toFixed(2));
        ''',
      });
      expect(result.success, true);
      expect(result.output, contains('5'));
      expect(result.output, contains('3'));
      expect(result.output, contains('3.14'));
    });
  });
}
