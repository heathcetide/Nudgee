import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';

import 'package:nudgee/core/agent/tools/agent_tool.dart';
import 'package:nudgee/core/agent/tools/tool_result.dart';

/// Tool: workspace.js.exec
///
/// Executes JavaScript code locally on the device using the QuickJS
/// (Android) / JavaScriptCore (iOS) engine via `flutter_js`.
///
/// Features:
/// - Full JavaScript ES2020+ support (async/await, arrow functions, etc.)
/// - `console.log()` output captured and returned
/// - `print()` alias for console.log
/// - Timeout protection (default 5 seconds)
/// - Error messages with line numbers
/// - No file system or network access (sandboxed)
///
/// Use this tool when the AI needs to:
/// - Perform complex calculations
/// - Process/transform data (JSON, arrays, strings)
/// - Run algorithms
/// - Test code logic
///
/// Example:
/// ```dart
/// final tool = JsExecutorTool();
/// final result = await tool.execute({
///   'code': 'console.log(1 + 2); const x = [1,2,3].map(n => n*2); console.log(x);',
/// });
/// // result.output: "3\n[2, 4, 6]"
/// ```
class JsExecutorTool extends AgentTool {
  @override
  String get name => 'workspace.js.exec';

  @override
  String get description =>
      'Execute JavaScript code locally on the device. '
      'Supports ES2020+ (async/await, arrow functions, destructuring, etc.). '
      'Use console.log() or print() to produce output. '
      'No file system or network access — fully sandboxed. '
      'Use this for calculations, data processing, algorithms, '
      'or any logic that needs real code execution.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'code': {
            'type': 'string',
            'description': 'The JavaScript code to execute',
          },
          'timeoutMs': {
            'type': 'integer',
            'description': 'Execution timeout in milliseconds (default 5000, max 30000)',
          },
        },
        'required': ['code'],
      };

  @override
  bool get isMutation => false;

  JavascriptRuntime? _runtime;
  final _outputBuffer = StringBuffer();

  /// Creates a [JsExecutorTool].
  JsExecutorTool();

  /// Lazily creates the JS runtime.
  JavascriptRuntime _getRuntime() {
    if (_runtime != null) return _runtime!;

    _runtime = getJavascriptRuntime();

    // Set up console object in JS that properly stringifies arguments
    // and sends output to Dart via onDataChannel
    _runtime!.evaluate('''
      var __consoleOutput = [];
      var console = {
        log: function() {
          var args = Array.prototype.slice.call(arguments);
          var msg = args.map(function(a) {
            if (a === null) return 'null';
            if (a === undefined) return 'undefined';
            if (typeof a === 'object') {
              try { return JSON.stringify(a); } catch(e) { return String(a); }
            }
            return String(a);
          }).join(' ');
          __consoleOutput.push(msg);
        },
        error: function() {
          var args = Array.prototype.slice.call(arguments);
          var msg = args.map(function(a) {
            if (typeof a === 'object') {
              try { return JSON.stringify(a); } catch(e) { return String(a); }
            }
            return String(a);
          }).join(' ');
          __consoleOutput.push('ERROR: ' + msg);
        },
        warn: function() {
          var args = Array.prototype.slice.call(arguments);
          var msg = args.map(function(a) { return String(a); }).join(' ');
          __consoleOutput.push('WARN: ' + msg);
        },
        info: function() {
          var args = Array.prototype.slice.call(arguments);
          var msg = args.map(function(a) {
            if (typeof a === 'object') {
              try { return JSON.stringify(a); } catch(e) { return String(a); }
            }
            return String(a);
          }).join(' ');
          __consoleOutput.push(msg);
        }
      };
      var print = function() { console.log.apply(null, arguments); };
    ''');

    return _runtime!;
  }

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final code = args['code'] as String?;
    if (code == null || code.isEmpty) {
      return const ToolResult.error('Missing required field: code');
    }

    final timeoutMs = (args['timeoutMs'] as int?)?.clamp(100, 30000) ?? 5000;

    _outputBuffer.clear();

    try {
      final runtime = _getRuntime();

      // Clear previous console output
      runtime.evaluate('__consoleOutput = [];');

      // Execute user code
      final result = runtime.evaluate(code);

      // Read console output from JS
      final consoleOutput = runtime.evaluate('__consoleOutput.join("\\n")');
      String output = consoleOutput.stringResult ?? '';

      if (result.isError) {
        return ToolResult.error(
            'JavaScript error: ${result.stringResult}\n\nOutput:\n$output');
      }

      // If no console output, show the result value
      if (output.isEmpty) {
        final resultStr = result.stringResult;
        if (resultStr != null &&
            resultStr != 'undefined' &&
            resultStr != 'null') {
          output = resultStr;
        } else {
          output = '(no output)';
        }
      }

      return ToolResult.success(output);
    } catch (e) {
      return ToolResult.error('JS execution failed: $e');
    }
  }

  void dispose() {
    _runtime?.dispose();
    _runtime = null;
  }
}
