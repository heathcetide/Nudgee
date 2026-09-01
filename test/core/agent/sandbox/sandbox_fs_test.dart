import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/sandbox/sandbox.dart';

void main() {
  group('SandboxFsTool', () {
    late String tempDir;
    late SandboxFsTool tool;

    setUp(() {
      tempDir = Directory.systemTemp
          .createTempSync('sandbox_fs_test_')
          .path;
      tool = SandboxFsTool(
        sandboxRoot: tempDir,
        allowWrite: true,
        allowDelete: true,
      );
    });

    tearDown(() {
      final dir = Directory(tempDir);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    test('has correct name', () {
      expect(tool.name, 'sandbox.fs');
    });

    test('has operation and path in schema', () {
      final schema = tool.parametersSchema;
      expect(schema['properties'], contains('operation'));
      expect(schema['properties'], contains('path'));
      expect(schema['required'], ['operation', 'path']);
    });

    test('returns error for missing operation', () async {
      final result = await tool.execute({'path': 'test.txt'});
      expect(result.success, false);
      expect(result.error, contains('operation'));
    });

    test('returns error for missing path', () async {
      final result = await tool.execute({'operation': 'read', 'path': null});
      expect(result.success, false);
      expect(result.error, contains('path'));
    });

    // ── Write + Read ──────────────────────────────────────────────────

    test('write creates a file', () async {
      final result = await tool.execute({
        'operation': 'write',
        'path': 'test.txt',
        'content': 'Hello, sandbox!',
      });
      expect(result.success, true);
      expect(result.output, contains('Wrote'));
      expect(File('$tempDir/test.txt').existsSync(), true);
    });

    test('read returns file content', () async {
      await tool.execute({
        'operation': 'write',
        'path': 'test.txt',
        'content': 'Hello, sandbox!',
      });
      final result = await tool.execute({
        'operation': 'read',
        'path': 'test.txt',
      });
      expect(result.success, true);
      expect(result.output, 'Hello, sandbox!');
    });

    test('read returns error for non-existent file', () async {
      final result = await tool.execute({
        'operation': 'read',
        'path': 'nonexistent.txt',
      });
      expect(result.success, false);
      expect(result.error, contains('not found'));
    });

    test('write creates parent directories', () async {
      final result = await tool.execute({
        'operation': 'write',
        'path': 'sub/dir/file.txt',
        'content': 'nested',
      });
      expect(result.success, true);
      expect(File('$tempDir/sub/dir/file.txt').existsSync(), true);
    });

    test('write overwrites existing file', () async {
      await tool.execute({
        'operation': 'write',
        'path': 'test.txt',
        'content': 'original',
      });
      await tool.execute({
        'operation': 'write',
        'path': 'test.txt',
        'content': 'updated',
      });
      final result = await tool.execute({
        'operation': 'read',
        'path': 'test.txt',
      });
      expect(result.output, 'updated');
    });

    // ── List ──────────────────────────────────────────────────────────

    test('list returns directory contents', () async {
      await tool.execute({
        'operation': 'write',
        'path': 'a.txt',
        'content': 'a',
      });
      await tool.execute({
        'operation': 'write',
        'path': 'b.txt',
        'content': 'b',
      });
      final result = await tool.execute({
        'operation': 'list',
        'path': '',
      });
      expect(result.success, true);
      expect(result.output, contains('a.txt'));
      expect(result.output, contains('b.txt'));
    });

    test('list returns empty for empty directory', () async {
      final result = await tool.execute({
        'operation': 'list',
        'path': '',
      });
      expect(result.success, true);
      expect(result.output, contains('empty'));
    });

    test('list shows file sizes', () async {
      await tool.execute({
        'operation': 'write',
        'path': 'test.txt',
        'content': 'hello',
      });
      final result = await tool.execute({
        'operation': 'list',
        'path': '',
      });
      expect(result.success, true);
      expect(result.output, contains('5 bytes'));
    });

    // ── Mkdir ─────────────────────────────────────────────────────────

    test('mkdir creates a directory', () async {
      final result = await tool.execute({
        'operation': 'mkdir',
        'path': 'newdir',
      });
      expect(result.success, true);
      expect(Directory('$tempDir/newdir').existsSync(), true);
    });

    test('mkdir creates nested directories', () async {
      final result = await tool.execute({
        'operation': 'mkdir',
        'path': 'a/b/c',
      });
      expect(result.success, true);
      expect(Directory('$tempDir/a/b/c').existsSync(), true);
    });

    test('mkdir returns success for existing directory', () async {
      await tool.execute({'operation': 'mkdir', 'path': 'existing'});
      final result = await tool.execute({
        'operation': 'mkdir',
        'path': 'existing',
      });
      expect(result.success, true);
      expect(result.output, contains('already exists'));
    });

    // ── Delete ────────────────────────────────────────────────────────

    test('delete removes a file', () async {
      await tool.execute({
        'operation': 'write',
        'path': 'todelete.txt',
        'content': 'bye',
      });
      final result = await tool.execute({
        'operation': 'delete',
        'path': 'todelete.txt',
      });
      expect(result.success, true);
      expect(File('$tempDir/todelete.txt').existsSync(), false);
    });

    test('delete removes a directory recursively', () async {
      await tool.execute({'operation': 'mkdir', 'path': 'dir'});
      await tool.execute({
        'operation': 'write',
        'path': 'dir/file.txt',
        'content': 'content',
      });
      final result = await tool.execute({
        'operation': 'delete',
        'path': 'dir',
      });
      expect(result.success, true);
      expect(Directory('$tempDir/dir').existsSync(), false);
    });

    test('delete returns error for non-existent path', () async {
      final result = await tool.execute({
        'operation': 'delete',
        'path': 'nonexistent',
      });
      expect(result.success, false);
    });

    // ── Exists ────────────────────────────────────────────────────────

    test('exists returns true for existing file', () async {
      await tool.execute({
        'operation': 'write',
        'path': 'test.txt',
        'content': 'hi',
      });
      final result = await tool.execute({
        'operation': 'exists',
        'path': 'test.txt',
      });
      expect(result.success, true);
      expect(result.output, contains('exists'));
    });

    test('exists returns not found for non-existent', () async {
      final result = await tool.execute({
        'operation': 'exists',
        'path': 'nonexistent.txt',
      });
      expect(result.success, true);
      expect(result.output, contains('not found'));
    });

    test('exists distinguishes files and directories', () async {
      await tool.execute({
        'operation': 'write',
        'path': 'file.txt',
        'content': 'x',
      });
      await tool.execute({'operation': 'mkdir', 'path': 'mydir'});

      final fileResult = await tool.execute({
        'operation': 'exists',
        'path': 'file.txt',
      });
      expect(fileResult.output, contains('file'));

      final dirResult = await tool.execute({
        'operation': 'exists',
        'path': 'mydir',
      });
      expect(dirResult.output, contains('directory'));
    });

    // ── Info ──────────────────────────────────────────────────────────

    test('info returns file metadata', () async {
      await tool.execute({
        'operation': 'write',
        'path': 'test.txt',
        'content': 'hello world',
      });
      final result = await tool.execute({
        'operation': 'info',
        'path': 'test.txt',
      });
      expect(result.success, true);
      expect(result.output, contains('type: file'));
      expect(result.output, contains('size: 11 bytes'));
      expect(result.output, contains('modified:'));
    });

    test('info returns directory metadata', () async {
      await tool.execute({'operation': 'mkdir', 'path': 'mydir'});
      await tool.execute({
        'operation': 'write',
        'path': 'mydir/a.txt',
        'content': 'a',
      });
      final result = await tool.execute({
        'operation': 'info',
        'path': 'mydir',
      });
      expect(result.success, true);
      expect(result.output, contains('type: directory'));
      expect(result.output, contains('entries: 1'));
    });

    // ── Path traversal protection ─────────────────────────────────────

    test('rejects path traversal with ..', () async {
      final result = await tool.execute({
        'operation': 'read',
        'path': '../../../etc/passwd',
      });
      expect(result.success, false);
      expect(result.error, contains('escapes sandbox'));
    });

    test('rejects absolute paths', () async {
      final result = await tool.execute({
        'operation': 'read',
        'path': '/etc/passwd',
      });
      expect(result.success, false);
      expect(result.error, contains('escapes sandbox'));
    });

    // ── Permission checks ─────────────────────────────────────────────

    test('write blocked when allowWrite is false', () async {
      final readOnlyTool = SandboxFsTool(
        sandboxRoot: tempDir,
        allowWrite: false,
      );
      final result = await readOnlyTool.execute({
        'operation': 'write',
        'path': 'test.txt',
        'content': 'hello',
      });
      expect(result.success, false);
      expect(result.error, contains('not allowed'));
    });

    test('delete blocked when allowDelete is false', () async {
      final noDeleteTool = SandboxFsTool(
        sandboxRoot: tempDir,
        allowWrite: true,
        allowDelete: false,
      );
      await noDeleteTool.execute({
        'operation': 'write',
        'path': 'test.txt',
        'content': 'hello',
      });
      final result = await noDeleteTool.execute({
        'operation': 'delete',
        'path': 'test.txt',
      });
      expect(result.success, false);
      expect(result.error, contains('not allowed'));
    });

    test('unknown operation returns error', () async {
      final result = await tool.execute({
        'operation': 'invalid',
        'path': 'test.txt',
      });
      expect(result.success, false);
      expect(result.error, contains('Unknown operation'));
    });
  });

  group('registerFsBridgeFunctions', () {
    late String tempDir;
    late SandboxExecutor executor;

    setUp(() {
      tempDir = Directory.systemTemp
          .createTempSync('sandbox_bridge_test_')
          .path;
      executor = SandboxExecutor();
      registerFsBridgeFunctions(
        executor,
        sandboxRoot: tempDir,
        allowWrite: true,
        allowDelete: true,
      );
    });

    tearDown(() {
      final dir = Directory(tempDir);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    test('fs.write bridge function writes file', () async {
      final result = await executor.execute('fs.write("test.txt", "hello")');
      expect(result.success, true);
      expect(File('$tempDir/test.txt').readAsStringSync(), 'hello');
    });

    test('fs.read bridge function reads file', () async {
      File('$tempDir/test.txt').writeAsStringSync('content from file');
      final result = await executor.execute('fs.read("test.txt")');
      expect(result.success, true);
      expect(result.output, 'content from file');
    });

    test('fs.exists bridge function checks existence', () async {
      File('$tempDir/test.txt').writeAsStringSync('exists');
      final result = await executor.execute('fs.exists("test.txt")');
      expect(result.success, true);
      expect(result.output.toString(), contains('true'));
    });

    test('fs.exists returns false for non-existent', () async {
      final result = await executor.execute('fs.exists("nope.txt")');
      expect(result.success, true);
      expect(result.output.toString(), contains('false'));
    });

    test('fs.mkdir bridge function creates directory', () async {
      final result = await executor.execute('fs.mkdir("newdir")');
      expect(result.success, true);
      expect(Directory('$tempDir/newdir').existsSync(), true);
    });

    test('fs.list bridge function lists directory', () async {
      File('$tempDir/a.txt').writeAsStringSync('a');
      File('$tempDir/b.txt').writeAsStringSync('b');
      final result = await executor.execute('fs.list("")');
      expect(result.success, true);
      expect(result.output, contains('a.txt'));
      expect(result.output, contains('b.txt'));
    });

    test('fs.delete bridge function deletes file', () async {
      File('$tempDir/todelete.txt').writeAsStringSync('bye');
      final result = await executor.execute('fs.delete("todelete.txt")');
      expect(result.success, true);
      expect(File('$tempDir/todelete.txt').existsSync(), false);
    });
  });
}
