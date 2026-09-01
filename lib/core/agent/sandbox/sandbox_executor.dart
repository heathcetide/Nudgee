import 'dart:async';

import 'package:nudgee/core/agent/sandbox/sandbox_models.dart';
import 'package:nudgee/core/agent/sandbox/sandbox_analyzer.dart';

/// Bridge API — functions that sandboxed code can call.
///
/// These are safe, controlled functions that the host app exposes
/// to the sandbox. They bypass the static analyzer's restrictions
/// because they are explicitly registered by the host.
class SandboxBridge {
  /// Registered functions, keyed by name.
  final Map<String, SandboxBridgeFunction> _functions = {};

  /// Registers a bridge function.
  void register(String name, SandboxBridgeFunction fn) {
    _functions[name] = fn;
  }

  /// Unregisters a bridge function.
  void unregister(String name) {
    _functions.remove(name);
  }

  /// Gets a registered bridge function by name.
  SandboxBridgeFunction? get(String name) => _functions[name];

  /// Gets all registered function names.
  List<String> get names => _functions.keys.toList();

  /// Clears all registered functions.
  void clear() => _functions.clear();

  /// Whether a function is registered.
  bool contains(String name) => _functions.containsKey(name);
}

/// A bridge function that can be called from the sandbox.
typedef SandboxBridgeFunction = Future<dynamic> Function(
  List<dynamic> args,
  Map<String, dynamic> kwargs,
);

/// Sandbox executor — runs Dart code in a restricted environment.
///
/// This implementation uses a pluggable [SandboxInterpreter] to
/// execute code. The default [SimpleSandboxInterpreter] provides
/// a safe subset of Dart evaluation for basic computations.
///
/// For full Dart execution, integrate the `d4rt` package:
/// ```yaml
/// dependencies:
///   d4rt: ^0.0.5
/// ```
/// and pass a [D4rtSandboxInterpreter] to the executor.
class SandboxExecutor {
  /// Static analyzer for pre-execution safety checks.
  final SandboxStaticAnalyzer analyzer;

  /// Bridge API for host-exposed functions.
  final SandboxBridge bridge;

  /// The interpreter that executes the code.
  final SandboxInterpreter interpreter;

  /// Whether to run static analysis before execution.
  final bool enableStaticAnalysis;

  /// Creates a [SandboxExecutor].
  SandboxExecutor({
    SandboxStaticAnalyzer? analyzer,
    SandboxBridge? bridge,
    SandboxInterpreter? interpreter,
    this.enableStaticAnalysis = true,
  })  : analyzer = analyzer ?? SandboxStaticAnalyzer(),
        bridge = bridge ?? SandboxBridge(),
        interpreter = interpreter ?? SimpleSandboxInterpreter();

  /// Executes [code] with the given [permissions].
  ///
  /// Returns a [SandboxResult] with the output, stdout, or error.
  Future<SandboxResult> execute(
    String code, {
    SandboxPermissions permissions = SandboxPermissions.safe,
    Map<String, dynamic> environment = const {},
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Static analysis
    if (enableStaticAnalysis) {
      final report = analyzer.analyze(code, permissions: permissions);
      if (!report.isSafe && report.riskLevel == SandboxRiskLevel.critical) {
        stopwatch.stop();
        return SandboxResult.failed(
          'Code rejected by static analysis: ${report.issues.map((i) => i.description).join("; ")}',
          errorType: 'StaticAnalysisError',
          duration: stopwatch.elapsed,
        );
      }
    }

    // 2. Execute with timeout
    try {
      final result = await interpreter
          .execute(
            code,
            bridge: bridge,
            permissions: permissions,
            environment: environment,
          )
          .timeout(permissions.timeout);

      stopwatch.stop();
      return SandboxResult(
        success: true,
        output: result.value,
        stdout: result.stdout,
        duration: stopwatch.elapsed,
      );
    } on TimeoutException {
      stopwatch.stop();
      return SandboxResult.failed(
        'Execution timed out after ${permissions.timeout.inSeconds}s',
        errorType: 'TimeoutException',
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return SandboxResult.failed(
        e.toString(),
        errorType: e.runtimeType.toString(),
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Analyzes code without executing it.
  SandboxSafetyReport analyze(
    String code, {
    SandboxPermissions permissions = SandboxPermissions.safe,
  }) {
    return analyzer.analyze(code, permissions: permissions);
  }

  /// Registers a bridge function.
  void registerBridgeFunction(
    String name,
    SandboxBridgeFunction fn,
  ) {
    bridge.register(name, fn);
  }
}

/// Result from an interpreter execution.
class SandboxExecutionOutput {
  /// The return value of the executed code.
  final dynamic value;

  /// Captured stdout (print output).
  final String? stdout;

  /// Creates a [SandboxExecutionOutput].
  const SandboxExecutionOutput({this.value, this.stdout});
}

/// Abstract interpreter interface for sandbox execution.
///
/// Implementations:
/// - [SimpleSandboxInterpreter] — basic math/logic evaluation (no deps)
/// - D4rtSandboxInterpreter — full Dart via d4rt (requires d4rt package)
abstract class SandboxInterpreter {
  /// Executes [code] and returns the result.
  Future<SandboxExecutionOutput> execute(
    String code, {
    required SandboxBridge bridge,
    required SandboxPermissions permissions,
    required Map<String, dynamic> environment,
  });
}

/// A simple interpreter that evaluates basic Dart expressions.
///
/// This is a minimal interpreter that supports:
/// - Arithmetic expressions: `1 + 2`, `3 * 4 - 5`
/// - String literals: `"hello"`, `'world'`
/// - Boolean expressions: `true && false`, `1 > 2`
/// - List literals: `[1, 2, 3]`
/// - Map literals: `{"key": "value"}`
/// - Function calls to bridge functions
/// - Variable bindings from environment
///
/// It does NOT support:
/// - Control flow (if/for/while)
/// - Function definitions
/// - Class definitions
/// - Imports
///
/// For full Dart execution, use a [D4rtSandboxInterpreter].
class SimpleSandboxInterpreter implements SandboxInterpreter {
  @override
  Future<SandboxExecutionOutput> execute(
    String code, {
    required SandboxBridge bridge,
    required SandboxPermissions permissions,
    required Map<String, dynamic> environment,
  }) async {
    final stdout = StringBuffer();

    // Strip comments
    final cleaned = _stripComments(code).trim();

    // Handle print statements
    final printPattern = RegExp(r'''print\s*\(\s*(.+?)\s*\)\s*;?''');
    final matches = printPattern.allMatches(cleaned).toList();

    for (final match in matches) {
      final expr = match.group(1)!;
      var value = _evalExpression(expr, environment, bridge);
      // Await if it's a Future (from bridge function)
      if (value is Future) value = await value;
      stdout.writeln(value);
    }

    // If the code is just a print statement, return stdout
    final withoutPrints = cleaned
        .replaceAll(printPattern, '')
        .trim();

    if (withoutPrints.isEmpty) {
      return SandboxExecutionOutput(stdout: stdout.toString().trim());
    }

    // Otherwise evaluate the remaining expression
    var value = _evalExpression(withoutPrints, environment, bridge);
    // Await if it's a Future (from bridge function)
    if (value is Future) value = await value;
    return SandboxExecutionOutput(
      value: value,
      stdout: stdout.isNotEmpty ? stdout.toString().trim() : null,
    );
  }

  /// Strips Dart comments from code.
  String _stripComments(String code) {
    // Remove single-line comments
    var result = code.replaceAll(RegExp(r'//.*'), '');
    // Remove multi-line comments
    result = result.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    return result;
  }

  /// Evaluates a simple expression.
  ///
  /// Supports: numbers, strings, booleans, lists, maps, arithmetic,
  /// string concatenation, comparison, and bridge function calls.
  dynamic _evalExpression(
    String expr,
    Map<String, dynamic> env,
    SandboxBridge bridge,
  ) {
    final trimmed = expr.trim();

    // Empty
    if (trimmed.isEmpty) return null;

    // Null literal
    if (trimmed == 'null') return null;

    // Boolean literals
    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;

    // Number literals
    final intMatch = RegExp(r'^-?\d+$').firstMatch(trimmed);
    if (intMatch != null) return int.parse(trimmed);

    final doubleMatch = RegExp(r'^-?\d+\.\d+$').firstMatch(trimmed);
    if (doubleMatch != null) return double.parse(trimmed);

    // String literals (double or single quoted) — must span the entire expr
    // and the closing quote must be the matching one (no unescaped same-quote inside)
    if (trimmed.length >= 2) {
      final first = trimmed[0];
      if ((first == '"' || first == "'") && trimmed.endsWith(first)) {
        // Check no unescaped same-quote in the middle
        final inner = trimmed.substring(1, trimmed.length - 1);
        if (!_containsUnescapedQuote(inner, first)) {
          return inner;
        }
      }
    }

    // List literal: [1, 2, 3]
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      final inner = trimmed.substring(1, trimmed.length - 1).trim();
      if (inner.isEmpty) return <dynamic>[];
      final items = _splitArgs(inner);
      return items.map((item) => _evalExpression(item, env, bridge)).toList();
    }

    // Map literal: {"key": value, ...}
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final inner = trimmed.substring(1, trimmed.length - 1).trim();
      if (inner.isEmpty) return <String, dynamic>{};
      final pairs = _splitArgs(inner);
      final map = <String, dynamic>{};
      for (final pair in pairs) {
        final colonIdx = _findTopLevelColon(pair);
        if (colonIdx > 0) {
          final key = _evalExpression(pair.substring(0, colonIdx), env, bridge);
          final value =
              _evalExpression(pair.substring(colonIdx + 1), env, bridge);
          map[key.toString()] = value;
        }
      }
      return map;
    }

    // Parenthesized expression: (expr)
    if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
      // Check that the outer parens match (not e.g. "(a) + (b)")
      if (_isMatchingParens(trimmed)) {
        return _evalExpression(
          trimmed.substring(1, trimmed.length - 1),
          env,
          bridge,
        );
      }
    }

    // Variable reference from environment
    if (env.containsKey(trimmed)) {
      return env[trimmed];
    }

    // Bridge function call: funcName(arg1, arg2, ...)
    final callMatch = RegExp(r'^(\w+)\s*\((.*)\)$').firstMatch(trimmed);
    if (callMatch != null) {
      final funcName = callMatch.group(1)!;
      final argsStr = callMatch.group(2)!;
      final fn = bridge.get(funcName);
      if (fn != null) {
        final args = argsStr.trim().isEmpty
            ? <dynamic>[]
            : _splitArgs(argsStr)
                .map((a) => _evalExpression(a, env, bridge))
                .toList();
        // Bridge functions are async — return the Future directly.
        // The caller (execute) will await it.
        return fn(args, {});
      }
    }

    // Arithmetic and string concatenation
    return _evalArithmetic(trimmed, env, bridge);
  }

  /// Checks if the outer parentheses of [str] are matching pair.
  bool _isMatchingParens(String str) {
    if (!str.startsWith('(') || !str.endsWith(')')) return false;
    var depth = 0;
    for (var i = 0; i < str.length; i++) {
      if (str[i] == '(') depth++;
      if (str[i] == ')') {
        depth--;
        if (depth == 0 && i < str.length - 1) return false;
      }
    }
    return true;
  }

  /// Checks if [str] contains an unescaped [quote] character.
  bool _containsUnescapedQuote(String str, String quote) {
    for (var i = 0; i < str.length; i++) {
      if (str[i] == '\\') {
        i++; // skip escaped char
        continue;
      }
      if (str[i] == quote) return true;
    }
    return false;
  }

  /// Evaluates arithmetic expressions and string concatenation.
  dynamic _evalArithmetic(
    String expr,
    Map<String, dynamic> env,
    SandboxBridge bridge,
  ) {
    // Split at top-level + operator (for string concat or numeric add)
    final plusParts = _splitTopLevel(expr, '+');
    if (plusParts.length > 1) {
      final values = plusParts
          .map((p) => _evalExpression(p.trim(), env, bridge))
          .toList();
      // If any part is a String, do string concatenation
      if (values.any((v) => v is String)) {
        return values.map((v) => '$v').join();
      }
      // Otherwise numeric addition
      if (values.every((v) => v is num)) {
        return values.fold<num>(0, (sum, v) => sum + (v as num));
      }
    }

    // Simple arithmetic: try to evaluate as a numeric expression
    try {
      return _evalNumericExpr(expr, env);
    } catch (_) {
      // Not a numeric expression
    }

    throw SandboxEvalException('Cannot evaluate: $expr');
  }

  /// Splits [expr] at top-level [separator] (not inside parens/brackets/quotes).
  List<String> _splitTopLevel(String expr, String separator) {
    final result = <String>[];
    var depth = 0;
    var start = 0;
    var inString = false;
    String? quoteChar;
    for (var i = 0; i < expr.length; i++) {
      final ch = expr[i];
      // Track string boundaries
      if (!inString && (ch == '"' || ch == "'")) {
        inString = true;
        quoteChar = ch;
      } else if (inString && ch == quoteChar) {
        inString = false;
        quoteChar = null;
      }
      // Only track depth outside strings
      if (!inString) {
        if (ch == '(' || ch == '[' || ch == '{') depth++;
        if (ch == ')' || ch == ']' || ch == '}') depth--;
        if (ch == separator && depth == 0) {
          result.add(expr.substring(start, i));
          start = i + 1;
        }
      }
    }
    result.add(expr.substring(start));
    return result;
  }

  /// Evaluates a numeric expression with +, -, *, /, %, and parentheses.
  dynamic _evalNumericExpr(String expr, Map<String, dynamic> env) {
    // Replace variable references with their values
    var processed = expr;
    for (final entry in env.entries) {
      if (entry.value is num) {
        processed = processed.replaceAll(
          RegExp(r'\b${entry.key}\b'),
          entry.value.toString(),
        );
      }
    }

    // Tokenize and evaluate with shunting-yard algorithm
    final tokens = _tokenize(processed);
    return _evalTokens(tokens);
  }

  /// Tokenizes a numeric expression.
  List<String> _tokenize(String expr) {
    final tokens = <String>[];
    final pattern = RegExp(r'(\d+\.?\d*|[-+*/%()])');
    for (final match in pattern.allMatches(expr)) {
      tokens.add(match.group(0)!);
    }
    return tokens;
  }

  /// Evaluates tokens using a simple recursive descent parser.
  num _evalTokens(List<String> tokens) {
    var pos = 0;

    late num Function() parseExpression;
    late num Function() parseTerm;
    late num Function() parseFactor;

    parseExpression = () {
      var left = parseTerm();
      while (pos < tokens.length &&
          (tokens[pos] == '+' || tokens[pos] == '-')) {
        final op = tokens[pos++];
        final right = parseTerm();
        left = op == '+' ? left + right : left - right;
      }
      return left;
    };

    parseTerm = () {
      var left = parseFactor();
      while (pos < tokens.length &&
          (tokens[pos] == '*' || tokens[pos] == '/' || tokens[pos] == '%')) {
        final op = tokens[pos++];
        final right = parseFactor();
        if (op == '*') {
          left = left * right;
        } else if (op == '/') {
          left = left / right;
        } else {
          left = left % right;
        }
      }
      return left;
    };

    parseFactor = () {
      if (pos >= tokens.length) throw FormatException('Unexpected end');
      final token = tokens[pos];
      if (token == '(') {
        pos++;
        final result = parseExpression();
        if (pos < tokens.length && tokens[pos] == ')') {
          pos++;
        }
        return result;
      }
      if (token == '-') {
        pos++;
        return -parseFactor();
      }
      pos++;
      return num.parse(token);
    };

    final result = parseExpression();
    if (pos < tokens.length) {
      throw FormatException('Unexpected token: ${tokens[pos]}');
    }
    return result;
  }

  /// Splits function arguments at top-level commas.
  List<String> _splitArgs(String args) {
    final result = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < args.length; i++) {
      final ch = args[i];
      if (ch == '(' || ch == '[' || ch == '{') depth++;
      if (ch == ')' || ch == ']' || ch == '}') depth--;
      if (ch == ',' && depth == 0) {
        result.add(args.substring(start, i).trim());
        start = i + 1;
      }
    }
    if (start < args.length) {
      result.add(args.substring(start).trim());
    }
    return result;
  }

  /// Finds the top-level colon in a map entry (not inside nested structures).
  int _findTopLevelColon(String str) {
    var depth = 0;
    for (var i = 0; i < str.length; i++) {
      final ch = str[i];
      if (ch == '(' || ch == '[' || ch == '{') depth++;
      if (ch == ')' || ch == ']' || ch == '}') depth--;
      if (ch == ':' && depth == 0) return i;
    }
    return -1;
  }
}

/// Exception thrown when sandbox evaluation fails.
class SandboxEvalException implements Exception {
  final String message;
  const SandboxEvalException(this.message);

  @override
  String toString() => 'SandboxEvalException: $message';
}
