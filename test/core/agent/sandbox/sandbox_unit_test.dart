import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/sandbox/sandbox.dart';

void main() {
  group('SandboxModels', () {
    test('SandboxPermissions.safe has minimum privileges', () {
      const perms = SandboxPermissions.safe;
      expect(perms.allowFilesystem, false);
      expect(perms.allowNetwork, false);
      expect(perms.allowProcess, false);
      expect(perms.allowIsolate, false);
      expect(perms.timeout, const Duration(seconds: 10));
    });

    test('SandboxPermissions.compute allows network', () {
      const perms = SandboxPermissions.compute;
      expect(perms.allowNetwork, true);
      expect(perms.allowFilesystem, false);
    });

    test('SandboxPermissions.dataProcessing allows filesystem', () {
      const perms = SandboxPermissions.dataProcessing;
      expect(perms.allowFilesystem, true);
      expect(perms.filesystemRoot, '/tmp/sandbox');
      expect(perms.allowNetwork, false);
    });

    test('SandboxPermissions.full allows everything', () {
      const perms = SandboxPermissions.full;
      expect(perms.allowFilesystem, true);
      expect(perms.allowNetwork, true);
      expect(perms.allowProcess, true);
      expect(perms.allowIsolate, true);
    });

    test('SandboxResult.ok creates successful result', () {
      final result = SandboxResult.ok(
        output: 42,
        stdout: 'hello',
        duration: const Duration(milliseconds: 100),
      );
      expect(result.success, true);
      expect(result.output, 42);
      expect(result.stdout, 'hello');
    });

    test('SandboxResult.failed creates error result', () {
      final result = SandboxResult.failed(
        'Timeout',
        errorType: 'TimeoutException',
        duration: const Duration(seconds: 10),
      );
      expect(result.success, false);
      expect(result.error, 'Timeout');
      expect(result.errorType, 'TimeoutException');
    });

    test('SandboxSafetyReport.safe has no issues', () {
      final report = SandboxSafetyReport.safe();
      expect(report.isSafe, true);
      expect(report.issues, isEmpty);
      expect(report.riskLevel, SandboxRiskLevel.low);
    });
  });

  group('SandboxStaticAnalyzer', () {
    late SandboxStaticAnalyzer analyzer;

    setUp(() {
      analyzer = SandboxStaticAnalyzer();
    });

    test('safe code passes analysis', () {
      const code = 'print(1 + 2);';
      final report = analyzer.analyze(code);
      expect(report.isSafe, true);
      expect(report.issues, isEmpty);
      expect(report.riskLevel, SandboxRiskLevel.low);
    });

    test('detects dangerous import dart:io', () {
      const code = "import 'dart:io';\nprint('hello');";
      final report = analyzer.analyze(code);
      expect(report.issues, isNotEmpty);
      expect(
        report.issues.any((i) =>
            i.type == SandboxSafetyIssueType.dangerousImport),
        true,
      );
      expect(report.riskLevel, SandboxRiskLevel.critical);
    });

    test('detects dangerous import dart:isolate', () {
      const code = "import 'dart:isolate';";
      final report = analyzer.analyze(code);
      expect(
        report.issues.any((i) =>
            i.type == SandboxSafetyIssueType.dangerousImport),
        true,
      );
    });

    test('detects filesystem access when not permitted', () {
      const code = "File('/etc/passwd').readAsString();";
      final report = analyzer.analyze(code);
      expect(
        report.issues.any((i) =>
            i.type == SandboxSafetyIssueType.filesystemAccess),
        true,
      );
    });

    test('filesystem access allowed when permitted', () {
      const code = "File('/tmp/test.txt').readAsString();";
      final report = analyzer.analyze(
        code,
        permissions: SandboxPermissions.dataProcessing,
      );
      expect(
        report.issues.where((i) =>
            i.type == SandboxSafetyIssueType.filesystemAccess),
        isEmpty,
      );
    });

    test('detects network access when not permitted', () {
      const code = 'HttpClient().getUrl(Uri.parse("https://evil.com"));';
      final report = analyzer.analyze(code);
      expect(
        report.issues.any((i) =>
            i.type == SandboxSafetyIssueType.networkAccess),
        true,
      );
    });

    test('detects process execution', () {
      const code = "Process.run('rm', ['-rf', '/']);";
      final report = analyzer.analyze(code);
      expect(
        report.issues.any((i) =>
            i.type == SandboxSafetyIssueType.processExecution),
        true,
      );
      expect(report.riskLevel, SandboxRiskLevel.critical);
    });

    test('detects infinite loop risk', () {
      const code = 'while (true) { print("loop"); }';
      final report = analyzer.analyze(code);
      expect(
        report.issues.any((i) =>
            i.type == SandboxSafetyIssueType.infiniteLoop),
        true,
      );
    });

    test('detects suspicious patterns', () {
      const code = 'eval("malicious code");';
      final report = analyzer.analyze(code);
      expect(
        report.issues.any((i) =>
            i.type == SandboxSafetyIssueType.suspiciousPattern),
        true,
      );
    });

    test('reports line numbers', () {
      const code = 'print("safe");\nimport \'dart:io\';\nprint("after");';
      final report = analyzer.analyze(code);
      final importIssue = report.issues.firstWhere(
        (i) => i.type == SandboxSafetyIssueType.dangerousImport,
      );
      expect(importIssue.line, 2);
    });
  });

  group('SandboxExecutor', () {
    late SandboxExecutor executor;

    setUp(() {
      executor = SandboxExecutor();
    });

    test('executes simple arithmetic', () async {
      final result = await executor.execute('1 + 2 * 3');
      expect(result.success, true);
      expect(result.output, 7);
    });

    test('executes print statement', () async {
      final result = await executor.execute('print("hello world");');
      expect(result.success, true);
      expect(result.stdout, 'hello world');
    });

    test('executes string concatenation', () async {
      final result = await executor.execute('"Hello" + " " + "World"');
      expect(result.success, true);
      expect(result.output, 'Hello World');
    });

    test('executes list literal', () async {
      final result = await executor.execute('[1, 2, 3]');
      expect(result.success, true);
      expect(result.output, [1, 2, 3]);
    });

    test('executes map literal', () async {
      final result = await executor.execute('{"name": "Alice", "age": 30}');
      expect(result.success, true);
      expect(result.output, {'name': 'Alice', 'age': 30});
    });

    test('executes boolean literal', () async {
      final result = await executor.execute('true');
      expect(result.success, true);
      expect(result.output, true);
    });

    test('executes null literal', () async {
      final result = await executor.execute('null');
      expect(result.success, true);
      expect(result.output, null);
    });

    test('executes integer literal', () async {
      final result = await executor.execute('42');
      expect(result.success, true);
      expect(result.output, 42);
    });

    test('executes double literal', () async {
      final result = await executor.execute('3.14');
      expect(result.success, true);
      expect(result.output, 3.14);
    });

    test('executes complex arithmetic with parentheses', () async {
      final result = await executor.execute('(2 + 3) * 4');
      expect(result.success, true);
      expect(result.output, 20);
    });

    test('executes modulo operation', () async {
      final result = await executor.execute('17 % 5');
      expect(result.success, true);
      expect(result.output, 2);
    });

    test('executes division', () async {
      final result = await executor.execute('10 / 4');
      expect(result.success, true);
      expect(result.output, 2.5);
    });

    test('executes negative numbers', () async {
      final result = await executor.execute('-5 + 3');
      expect(result.success, true);
      expect(result.output, -2);
    });

    test('uses environment variables', () async {
      final result = await executor.execute(
        'x + y',
        environment: {'x': 10, 'y': 20},
      );
      expect(result.success, true);
      expect(result.output, 30);
    });

    test('rejects critical code (dart:io import)', () async {
      const code = "import 'dart:io';\nprint('hello');";
      final result = await executor.execute(code);
      expect(result.success, false);
      expect(result.errorType, 'StaticAnalysisError');
      expect(result.error, contains('static analysis'));
    });

    test('rejects process execution', () async {
      const code = "Process.run('rm', ['-rf', '/']);";
      final result = await executor.execute(code);
      expect(result.success, false);
      expect(result.errorType, 'StaticAnalysisError');
    });

    test('times out on slow code', () async {
      // The simple interpreter doesn't support while loops,
      // but we can test timeout with a bridge function that sleeps
      executor.registerBridgeFunction('sleep', (args, kwargs) async {
        final seconds = (args[0] as num).toInt();
        await Future.delayed(Duration(seconds: seconds));
        return 'done';
      });

      final result = await executor.execute(
        'sleep(10)',
        permissions: const SandboxPermissions(timeout: Duration(seconds: 1)),
      );
      expect(result.success, false);
      expect(result.errorType, 'TimeoutException');
    });

    test('bridge functions can be called', () async {
      executor.registerBridgeFunction('greet', (args, kwargs) async {
        return 'Hello, ${args[0]}!';
      });

      final result = await executor.execute('greet("World")');
      expect(result.success, true);
      expect(result.output, 'Hello, World!');
    });

    test('bridge function with multiple args', () async {
      executor.registerBridgeFunction('add', (args, kwargs) async {
        return (args[0] as num) + (args[1] as num);
      });

      final result = await executor.execute('add(3, 5)');
      expect(result.success, true);
      expect(result.output, 8);
    });

    test('print and expression combined', () async {
      final result = await executor.execute(
        'print("computing...");\n1 + 2',
      );
      expect(result.success, true);
      expect(result.stdout, 'computing...');
      expect(result.output, 3);
    });

    test('comments are stripped', () async {
      final result = await executor.execute(
        '// this is a comment\n42 // inline comment',
      );
      expect(result.success, true);
      expect(result.output, 42);
    });

    test('empty code returns null', () async {
      final result = await executor.execute('');
      expect(result.success, true);
      expect(result.output, null);
    });

    test('analyze method returns report', () {
      const code = "import 'dart:io';";
      final report = executor.analyze(code);
      expect(report.riskLevel, SandboxRiskLevel.critical);
    });
  });

  group('SandboxBridge', () {
    test('register and get function', () {
      final bridge = SandboxBridge();
      bridge.register('test', (args, kwargs) async => 'ok');
      expect(bridge.contains('test'), true);
      expect(bridge.get('test'), isNotNull);
    });

    test('unregister function', () {
      final bridge = SandboxBridge();
      bridge.register('test', (args, kwargs) async => 'ok');
      bridge.unregister('test');
      expect(bridge.contains('test'), false);
    });

    test('clear all functions', () {
      final bridge = SandboxBridge();
      bridge.register('a', (args, kwargs) async => 1);
      bridge.register('b', (args, kwargs) async => 2);
      bridge.clear();
      expect(bridge.names, isEmpty);
    });

    test('names returns all registered names', () {
      final bridge = SandboxBridge();
      bridge.register('a', (args, kwargs) async => 1);
      bridge.register('b', (args, kwargs) async => 2);
      expect(bridge.names, containsAll(['a', 'b']));
    });
  });

  group('SandboxExecTool', () {
    late SandboxExecTool tool;

    setUp(() {
      tool = SandboxExecTool();
    });

    test('has correct name', () {
      expect(tool.name, 'sandbox.exec');
    });

    test('has required parameters in schema', () {
      final schema = tool.parametersSchema;
      expect(schema['properties'], hasLength(3));
      expect(schema['properties'], contains('code'));
      expect(schema['required'], ['code']);
    });

    test('executes simple code', () async {
      final result = await tool.execute({'code': '1 + 2'});
      expect(result.success, true);
      expect(result.output, contains('3'));
    });

    test('returns error for missing code', () async {
      final result = await tool.execute({});
      expect(result.success, false);
      expect(result.error, contains('Missing'));
    });

    test('returns error for empty code', () async {
      final result = await tool.execute({'code': ''});
      expect(result.success, false);
    });

    test('returns error for unsupported language', () async {
      final result = await tool.execute({
        'code': 'print("hello")',
        'language': 'python',
      });
      expect(result.success, false);
      expect(result.error, contains('Unsupported'));
    });

    test('rejects dangerous code', () async {
      final result = await tool.execute({
        'code': "import 'dart:io';",
      });
      expect(result.success, false);
      expect(result.error, contains('rejected'));
    });

    test('accepts permissions preset', () async {
      final result = await tool.execute({
        'code': '1 + 1',
        'permissions': 'compute',
      });
      expect(result.success, true);
    });

    test('includes duration in output', () async {
      final result = await tool.execute({'code': '42'});
      expect(result.success, true);
      expect(result.output, contains('duration'));
    });

    test('registers bridge functions', () async {
      tool.registerBridgeFunction('double', (args, kwargs) async {
        return (args[0] as num) * 2;
      });
      final result = await tool.execute({'code': 'double(21)'});
      expect(result.success, true);
      expect(result.output, contains('42'));
    });
  });
}
